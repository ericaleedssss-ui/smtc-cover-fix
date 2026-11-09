#pragma once
#include <QFile>
#include <QSet>
#include <QStringList>
#include <QtEndian>

// Read only the OpenType name table. Registering every bundled font with
// Windows duplicates tens of MB per face even when the user never selects it.
inline QStringList fontFileFamilies(const QString &path) {
    QFile file(path);
    if (!file.open(QIODevice::ReadOnly)) return {};
    const auto first = file.read(12);
    if (first.size() != 12) return {};
    const auto u16 = [](const char *p) { return qFromBigEndian<quint16>(p); };
    const auto u32 = [](const char *p) { return qFromBigEndian<quint32>(p); };
    QList<quint32> offsets{0};
    if (first.first(4) == "ttcf") {
        const auto count = u32(first.constData() + 8);
        if (!count || count > 256) return {};
        const auto bytes = file.read(count * 4);
        if (bytes.size() != count * 4) return {};
        offsets.clear();
        for (quint32 i = 0; i < count; ++i) offsets.append(u32(bytes.constData() + i * 4));
    }
    QSet<QString> families;
    for (const auto offset : offsets) {
        if (!file.seek(offset)) continue;
        const auto header = file.read(12);
        if (header.size() != 12) continue;
        const auto count = u16(header.constData() + 4);
        if (count > 512) continue;
        const auto directory = file.read(count * 16);
        if (directory.size() != count * 16) continue;
        for (int i = 0; i < count; ++i) {
            const auto record = directory.constData() + i * 16;
            if (QByteArrayView(record, 4) != "name") continue;
            const auto nameOffset = u32(record + 8), length = u32(record + 12);
            if (length < 6 || length > 4 * 1024 * 1024 || !file.seek(nameOffset)) break;
            const auto names = file.read(length);
            if (names.size() != length) break;
            const auto nameCount = u16(names.constData() + 2), strings = u16(names.constData() + 4);
            if (6 + quint32(nameCount) * 12 > length) break;
            QSet<QString> legacy, typographic;
            for (int n = 0; n < nameCount; ++n) {
                const auto entry = names.constData() + 6 + n * 12;
                const auto platform = u16(entry), id = u16(entry + 6);
                if (id != 1 && id != 16) continue;
                const auto size = u16(entry + 8);
                const quint32 begin = quint32(strings) + u16(entry + 10);
                if (begin + size > length) continue;
                QString family;
                if (platform == 0 || platform == 3) {
                    if (size % 2) continue;
                    family.resize(size / 2);
                    for (int c = 0; c < size / 2; ++c)
                        family[c] = QChar(u16(names.constData() + begin + c * 2));
                } else if (platform == 1) {
                    family = QString::fromLatin1(names.constData() + begin, size);
                }
                if (!family.isEmpty()) (id == 16 ? typographic : legacy).insert(family);
            }
            families.unite(typographic.isEmpty() ? legacy : typographic);
            break;
        }
    }
    return families.values();
}
