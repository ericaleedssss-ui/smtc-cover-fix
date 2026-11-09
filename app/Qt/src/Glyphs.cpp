#include "Glyphs.h"
#include "StartupMemory.h"
#include <QFile>
#include <QFont>
#include <QFontMetricsF>
#include <QJsonDocument>
#include <QJsonObject>
#include <QRadialGradient>
#include <QRegularExpression>
#include <cmath>
static QJsonObject load(const QString &name) {
    QFile f(name);
    if (!f.open(QIODevice::ReadOnly)) {
        qFatal("Missing glyph resource: %s", qPrintable(name));
    }
    return QJsonDocument::fromJson(f.readAll()).object();
}
static QColor color(const QJsonValue &value) {
    const auto a = value.toArray();
    // 普通 RGBA 只有四项；色彩空间标记是可选的第五项，不能通过可写代理越界读取。
    const bool calibrated = a.size() > 4 && a.at(4).toString().startsWith("calibrated");
    auto channel = [&](int i) {
        double value = a.at(i).toDouble();
        // 原 calibrated 颜色使用 Gamma 1.8；显式转到 sRGB，避免平台默认色彩空间差异。
        if (calibrated) {
            auto linear = std::pow(value, 1.8);
            value = linear <= .0031308 ? 12.92 * linear : 1.055 * std::pow(linear, 1 / 2.4) - .055;
        }
        return value;
    };
    return QColor::fromRgbF(channel(0), channel(1), channel(2), a.size() > 3 ? a[3].toDouble() : 1);
}
double Glyphs::measureText(QString text, QString family, int size, int weight, bool italic) {
    QFont font(family);font.setPixelSize(size);font.setWeight(static_cast<QFont::Weight>(weight));font.setItalic(italic);
    font.setVariableAxis(QFont::Tag("wght"),weight);
    return QFontMetricsF(font).horizontalAdvance(text);
}
Glyphs::Glyphs(const QString &root) : m_fontThread(QThread::currentThread()), m_root(root) {
    startupMemory("glyphs-fonts-begin");
    // Font faces are expensive on Windows. JSON outlines already cover the
    // archive lettering; open a full font only for an actual fallback glyph.
    startupMemory("glyphs-fonts-ready");
    // The immutable JSON storage is implicitly shared by all three renderers.
    // Build paths only for glyphs that are measured or drawn.
    static QMutex definitionsMutex;
    static QHash<QString, QJsonObject> definitions;
    {
        QMutexLocker lock(&definitionsMutex);
        auto found = definitions.constFind(root);
        if (found == definitions.cend())
            found = definitions.insert(root, load(root + "/misans-glyphs.json"));
        m_glyphDefinitions = found.value();
    }

}
QRawFont Glyphs::bundledFont(const QString &requested) {
    const auto weight = requested == "symbols" || requested == "light" || requested == "demibold" ||
                        requested == "bold" ? requested : QString("regular");
    const auto file = weight == "symbols" ? "/NotoSansSymbols2-Regular.ttf"
                                          : "/RhineMiSans-" + weight + ".otf";
    const auto path = m_root + file;
    // The HUD measures on the GUI thread and paints on the render thread.
    // Geometry may cross that boundary, but a QRawFont face may not.
    if(QThread::currentThread()!=m_fontThread)
        return QRawFont(path,1000,QFont::PreferNoHinting);
    if (!m_bundledFaces.contains(weight)) {
        // QRawFont is bound to its creating thread. Both scene renderers use
        // one render thread; share there, while keeping GUI-thread faces separate.
        static thread_local QHash<QString, std::weak_ptr<QRawFont>> sharedFaces;
        auto face = sharedFaces.value(path).lock();
        if (!face) {
            face = std::make_shared<QRawFont>(path, 1000, QFont::PreferNoHinting);
            sharedFaces.insert(path, face);
        }
        m_bundledFaces.insert(weight, face);
    }
    return *m_bundledFaces.value(weight);
}
QPainterPath Glyphs::path(const QString &svg) {
    QMutexLocker lock(&mutex);
    if (paths.contains(svg)) {
        return *paths.object(svg);
    }
    static const QRegularExpression re(
        "[a-zA-Z]|[-+]?(?:[0-9]*\\.[0-9]+|[0-9]+\\.?[0-9]*)(?:[eE][-+]?[0-9]+)?");
    QStringList tokens;
    auto matches = re.globalMatch(svg);
    while (matches.hasNext()) {
        tokens << matches.next().captured();
    }
    QPainterPath path;
    path.setFillRule(Qt::WindingFill);
    int i = 0;
    QChar command = 'M';
    QPointF point{}, start{};
    auto number = [&]() { return i < tokens.size() ? tokens[i++].toDouble() : 0.; };
    while (i < tokens.size()) {
        if (tokens[i][0].isLetter()) {
            command = tokens[i++][0];
            if (command.toUpper() == 'Z') {
                path.closeSubpath();
                point = start;
                continue;
            }
        }
        const bool relative = command.isLower();
        const auto origin = relative ? point : QPointF{};
        auto pair = [&]() {
            double x = number() + origin.x();
            double y = number() + origin.y();
            return QPointF(x, y);
        };
        switch (command.toUpper().unicode()) {
        case 'M':
            point = pair();
            path.moveTo(point);
            start = point;
            command = relative ? 'l' : 'L';
            break;
        case 'L':
            point = pair();
            path.lineTo(point);
            break;
        case 'H':
            point.setX(number() + (relative ? point.x() : 0));
            path.lineTo(point);
            break;
        case 'V':
            point.setY(number() + (relative ? point.y() : 0));
            path.lineTo(point);
            break;
        case 'C': {
            auto a = pair();
            auto b = pair();
            auto p = pair();
            path.cubicTo(a, b, p);
            point = p;
            break;
        }
        case 'Q': {
            auto a = pair();
            auto p = pair();
            path.quadTo(a, p);
            point = p;
            break;
        }
        default:
            i = tokens.size();
            break;
        }
    }
    paths.insert(svg, new QPainterPath(path));
    return path;
}
Glyphs::Glyph Glyphs::glyph(QString ch, QString weight) {
    QMutexLocker lock(&mutex);
    const auto key = weight + ":" + ch;
    if (m_family.isEmpty() && glyphs.contains(key)) {
        return glyphs[key];
    }
    if(!m_family.isEmpty()&&glyphs.contains("custom:"+key))return glyphs["custom:"+key];
    if (m_family.isEmpty()) {
        const auto definition = m_glyphDefinitions.value(weight).toObject()
                                    .value("glyphs").toObject().value(ch).toObject();
        if (!definition.isEmpty())
            return glyphs[key] = {definition["advance"].toDouble(), path(definition["path"].toString())};
    }
    QRawFont font;
    if (!m_family.isEmpty()) {
        const auto customKey="custom:"+weight;
        const bool ownThread=QThread::currentThread()==m_fontThread;
        if(!ownThread||!fonts.contains(customKey)) {
            QFont custom(m_family);custom.setPixelSize(1000);
            custom.setWeight(weight=="bold"?QFont::Bold:weight=="demibold"?QFont::DemiBold:weight=="light"?QFont::Light:QFont::Normal);
            custom.setVariableAxis(QFont::Tag("wght"),custom.weight());
            font=QRawFont::fromFont(custom);
            if(ownThread)fonts[customKey]=font;
        } else font=fonts[customKey];
    } else font = bundledFont(weight);
    auto ids = font.glyphIndexesForString(ch);
    if (!m_family.isEmpty() && (ids.isEmpty() || !ids.first())) {
        font = bundledFont(weight);
        ids = font.glyphIndexesForString(ch);
    }
    if (ids.isEmpty() || !ids.first()) {
        font = bundledFont("symbols");
        ids = font.glyphIndexesForString(ch);
    }
    if (ids.isEmpty() || !ids.first()) {
        return {};
    }
    auto advances = font.advancesForGlyphIndexes(ids);
    // Qt 字形坐标朝下；资源轮廓保持原始字体朝上的坐标。
    auto outline = QTransform::fromScale(1, -1).map(font.pathForGlyph(ids.first()));
    return glyphs[m_family.isEmpty()?key:"custom:"+key] = {advances.first().x() / 1000, outline};
}
void Glyphs::setFamily(QString family) {
    QMutexLocker lock(&mutex);
    m_family=family;
    for(auto it=glyphs.begin();it!=glyphs.end();)if(it.key().startsWith("custom:"))it=glyphs.erase(it);else ++it;
    for(auto it=fonts.begin();it!=fonts.end();)if(it.key().startsWith("custom:"))it=fonts.erase(it);else ++it;
    widths.clear();wrapped.clear();
}
double Glyphs::width(QString text, double size, QString weight, double tracking) {
    QMutexLocker lock(&mutex);
    const auto key = QString::fromUtf8(
        QJsonDocument(QJsonArray{text, size, weight, tracking}).toJson(QJsonDocument::Compact));
    if (const auto cached = widths.object(key)) {
        return *cached;
    }
    double result = 0;
    for (auto ch : text) {
        auto g = glyph(QString(ch), weight);
        result += g.advance * size + tracking;
    }
    result = qMax(0., result - tracking);
    if (text.size() <= 4096) {
        widths.insert(key, new double(result));
    }
    return result;
}
QVariantMap Glyphs::bounds(QString value, double size, QString weight) {
    QMutexLocker lock(&mutex);
    QRectF bounds;
    bool visible = false;
    double x = 0;
    // 使用和实际绘制完全相同的轮廓变换，避免中英文字体基线造成视觉错位。
    for (auto ch : value) {
        const auto g = glyph(QString(ch), weight);
        if (!g.path.isEmpty()) {
            QTransform transform;
            transform.translate(x, size * 1.044);
            transform.scale(size / 1000, -size / 1000);
            const auto rect = transform.map(g.path).boundingRect();
            bounds = visible ? bounds.united(rect) : rect;
            visible = true;
        }
        x += g.advance * size;
    }
    return {{"x", bounds.x()}, {"y", bounds.y()}, {"width", bounds.width()}, {"height", bounds.height()}};
}
double Glyphs::inset(QString text, double size, QString weight) {
    QMutexLocker lock(&mutex);
    if (text.isEmpty()) {
        return 0;
    }
    auto g = glyph(text.first(1), weight);
    return !g.path.isEmpty() ? g.path.boundingRect().x() * size / 1000 : 0;
}
QStringList Glyphs::wrap(QString value, double limit, double size, QString weight) {
    QMutexLocker lock(&mutex);
    const auto key = QString::fromUtf8(
        QJsonDocument(QJsonArray{value, limit, size, weight}).toJson(QJsonDocument::Compact));
    if (const auto cached = wrapped.object(key)) {
        return *cached;
    }
    QStringList lines;
    QString line;
    double length = 0;
    for (auto ch : value) {
        if (ch == '\n') {
            lines << line;
            line.clear();
            length = 0;
            continue;
        }
        double advance = width(QString(ch), size, weight);
        if (!line.isEmpty() && length + advance > limit) {
            lines << line;
            line.clear();
            length = 0;
        }
        line += ch;
        length += advance;
    }
    lines << line;
    // 有界缓存包含完整布局参数；窗口缩放和内容变化使用不同 key。
    wrapped.insert(key, new QStringList(lines), qMax(1, value.size()));
    return lines;
}
void Glyphs::text(QPainter &c, QString value, double x, double y, double size, QString weight,
                  double tracking, QColor ink) {
    QMutexLocker lock(&mutex);
    for (auto ch : value) {
        auto g = glyph(QString(ch), weight);
        c.save();
        c.translate(x, y + size * 1.044);
        c.scale(size / 1000, -size / 1000);
        c.fillPath(g.path, ink);
        c.restore();
        x += g.advance * size + tracking;
    }
}
void Glyphs::prepareCommands(const QJsonArray &commands) {
    QMutexLocker lock(&mutex);
    // Resolve only the text actually submitted for drawing, on the GUI thread.
    // paint() then consumes immutable outlines without opening another font face.
    for (const auto &value : commands) {
        const auto command = value.toArray();
        if (command.size() < 6 || command.at(0).toString() != "text") continue;
        const auto weight = command.at(5).toString();
        for (const auto ch : command.at(1).toString()) glyph(QString(ch), weight);
    }
}
void Glyphs::commands(QPainter &c, const QJsonArray &commands, std::function<QImage(QString)> image) {
    QMutexLocker lock(&mutex);
    c.setRenderHints(QPainter::Antialiasing | QPainter::SmoothPixmapTransform);
    for (auto v : commands) {
        const auto a = v.toArray();
        auto op = a[0].toString();
        auto n = [&](int i) { return a[i].toDouble(); };
        if (op == "save") {
            c.save();
        } else if (op == "restore") {
            c.restore();
        } else if (op == "alpha") {
            c.setOpacity(c.opacity() * n(1));
        } else if (op == "translate") {
            c.translate(n(1), n(2));
        } else if (op == "scale") {
            c.scale(n(1), n(2));
        } else if (op == "rotate") {
            c.rotate(n(1) * 180 / 3.14159265358979323846);
        } else if (op == "clip") {
            c.setClipRect(QRectF(n(1), n(2), n(3), n(4)), Qt::IntersectClip);
        } else if (op == "fill") {
            c.fillRect(QRectF(n(2), n(3), n(4), n(5)), color(a[1]));
        } else if (op == "rounded-fill") {
            c.setPen(Qt::NoPen);c.setBrush(color(a[1]));
            c.drawRoundedRect(QRectF(n(2),n(3),n(4),n(5)),n(6),n(6));
        } else if (op == "ellipse") {
            c.setPen(Qt::NoPen);
            c.setBrush(color(a[1]));
            c.drawEllipse(QRectF(n(2), n(3), n(4), n(5)));
        } else if (op == "text") {
            text(c, a[1].toString(), n(2), n(3), n(4), a[5].toString(), n(6), color(a[7]));
        } else if (op == "fill-path") {
            // 实心几何图标不受字体字形边距影响。
            c.fillPath(path(a[1].toString()), color(a[2]));
        } else if (op == "path") {
            QPen pen(color(a[3]), n(2), Qt::SolidLine, Qt::FlatCap, Qt::MiterJoin);
            auto dash = a[4].toArray();
            QList<qreal> d;
            for (auto x : dash) {
                d << x.toDouble() / qMax(n(2), .0001);
            }
            if (!d.isEmpty()) {
                pen.setDashPattern(d);
                pen.setDashOffset(n(5) / qMax(n(2), .0001));
            }
            c.setPen(pen);
            c.setBrush(Qt::NoBrush);
            c.drawPath(path(a[1].toString()));
        } else if (op == "arc") {
            QPainterPath p;
            QRectF r(n(1) - n(3), n(2) - n(3), n(3) * 2, n(3) * 2);
            p.arcMoveTo(r, -n(4) * 180 / 3.14159265358979323846);
            p.arcTo(r, -n(4) * 180 / 3.14159265358979323846, -n(5) * 180 / 3.14159265358979323846);
            c.setPen(QPen(color(a[7]), n(6), Qt::SolidLine, Qt::RoundCap));
            c.setBrush(Qt::NoBrush);
            c.drawPath(p);
        } else if (op == "gradient") {
            QRadialGradient gradient(QPointF(979.2, 518.4), 1100);
            gradient.setColorAt(0, QColor(231, 231, 225));
            gradient.setColorAt(.76, QColor(227, 225, 220));
            gradient.setColorAt(1, QColor(228, 223, 219));
            c.fillRect(QRectF(-4096, -4096, 8192, 8192), gradient);
        } else if (op == "image") {
            auto img = image(a[1].toString());
            if (!img.isNull()) {
                c.drawImage(QRectF(n(2), n(3), n(4), n(5)), img);
            }
        }
    }
}
void saveImageNative(const QImage &image, const QString &path) {
    image.save(path);
}
