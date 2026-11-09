#pragma once
#include <QCache>
#include <QHash>
#include <QImage>
#include <QJsonArray>
#include <QJsonObject>
#include <QMutex>
#include <QObject>
#include <QPainter>
#include <QPainterPath>
#include <QRawFont>
#include <QStringList>
#include <QVariantMap>
#include <QThread>
#include <memory>
class Glyphs : public QObject {
    Q_OBJECT
  public:
    explicit Glyphs(const QString &root);
    ~Glyphs() override = default;
    struct Glyph {
        double advance = 1;
        QPainterPath path;
    };
    Q_INVOKABLE double width(QString text, double size, QString weight = "regular", double tracking = 0);
    Q_INVOKABLE double measureText(QString text, QString family, int size, int weight, bool italic = false);
    Q_INVOKABLE QVariantMap bounds(QString text, double size, QString weight = "regular");
    Q_INVOKABLE double inset(QString text, double size, QString weight = "regular");
    Q_INVOKABLE QStringList wrap(QString text, double width, double size, QString weight = "regular");
    void text(QPainter &ctx, QString text, double x, double y, double size, QString weight, double tracking,
              QColor color);
    QPainterPath path(const QString &svg);
    void commands(QPainter &ctx, const QJsonArray &commands, std::function<QImage(QString)> image);
    void prepareCommands(const QJsonArray &commands);
    void setFamily(QString family);
    QString family() const { return m_family; }

  private:
    QRecursiveMutex mutex;
    QHash<QString, Glyph> glyphs;
    QHash<QString, QRawFont> fonts;
    QHash<QString, std::shared_ptr<QRawFont>> m_bundledFaces;
    QThread *const m_fontThread;
    QString m_root;
    QJsonObject m_glyphDefinitions;
    QString m_family;
    QCache<QString, QPainterPath> paths{1024};
    QCache<QString, double> widths{1024};
    QCache<QString, QStringList> wrapped{128 * 1024};
    Glyph glyph(QString ch, QString weight);
    QRawFont bundledFont(const QString &weight);
};

void saveImageNative(const QImage &image, const QString &path);
