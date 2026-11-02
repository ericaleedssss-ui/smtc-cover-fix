#include "MusicData.h"
#include <QDateTime>
#include <QRegularExpression>
#include <QSet>
#include <algorithm>

namespace {
QString identifier(const QJsonValue &value) {
    if (value.isString()) {
        return value.toString();
    }
    if (value.isDouble()) {
        return QString::number(value.toInteger());
    }
    return {};
}
}

namespace MusicData {
QJsonObject item(QString kind, QString id, QString title, QString artist, QString provider) {
    return {{"kind", kind},
            {"id", id},
            {"title", title},
            {"artist", artist},
            {"artists", QJsonArray{}},
            {"creatorID", ""},
            {"albumID", ""},
            {"album", ""},
            {"cover", ""},
            {"description", ""},
            {"wiki", ""},
            {"date", ""},
            {"duration", 0},
            {"trackCount", 0},
            {"provider", provider},
            {"key", provider + ":" + kind + ":" + id}};
}

QJsonObject parse(const QJsonObject &raw, const QString &kind) {
    const auto id = identifier(raw["id"]);
    static const QRegularExpression pattern(QStringLiteral("^[0-9]{1,20}$"));
    if (!pattern.match(id).hasMatch() || !raw["name"].isString()) {
        return {};
    }
    auto artists = raw["ar"].toArray();
    if (raw["ar"].isNull() || raw["ar"].isUndefined()) {
        artists = raw["artists"].toArray();
        if ((raw["artists"].isNull() || raw["artists"].isUndefined()) && raw["artist"].isObject()) {
            artists = QJsonArray{raw["artist"]};
        }
    }
    const auto creator = raw["creator"].toObject();
    const auto album = raw["al"].isObject() ? raw["al"].toObject() : raw["album"].toObject();
    QStringList names;
    QJsonArray entries;
    for (const auto &value : artists) {
        const auto artist = value.toObject();
        if (artist["name"].isString()) {
            names.append(artist["name"].toString());
            entries.append(QJsonObject{{"id", identifier(artist["id"])}, {"name", artist["name"]}});
        }
    }
    auto value = item(kind, id, raw["name"].toString(),
                      kind == "playlist" ? creator["nickname"].toString() : names.join(" / "));
    value["artists"] = entries;
    value["creatorID"] = identifier(creator["userId"]);
    value["creatorAvatar"] = creator["avatarUrl"];
    value["tags"] = raw["tags"].toArray();
    if(raw["subscribed"].isBool())value["subscribed"]=raw["subscribed"];
    for (const auto &field : {"subscribedCount", "commentCount", "playCount"}) if(raw.contains(field)) value[field]=raw[field];
    if(raw["createTime"].toDouble()>0) value["createdDate"]=QDateTime::fromMSecsSinceEpoch(raw["createTime"].toInteger()).date().toString("yyyy-MM-dd");
    const auto privilege=raw["privilege"].toObject();
    value["unavailable"]=privilege["st"].toInt() < 0;
    value["albumID"] = identifier(album["id"]);
    value["album"] = album["name"].toString();
    value["cover"] = raw["picUrl"].toString(raw["coverImgUrl"].toString(album["picUrl"].toString()));
    if (value["cover"].toString().isEmpty()) { value["cover"] = raw["img1v1Url"].toString(); }
    value["duration"] = raw["dt"].toDouble(raw["duration"].toDouble());
    value["trackCount"] = raw["trackCount"].toDouble(raw["size"].toDouble());
    value["description"] = raw["description"].toString(raw["briefDesc"].toString());
    if (raw["publishTime"].toDouble() > 0) {
        value["date"] =
            QDateTime::fromMSecsSinceEpoch(raw["publishTime"].toInteger()).date().toString("yyyy-MM-dd");
    }
    return value;
}

QJsonArray unique(const QJsonArray &existing, const QJsonArray &values) {
    QSet<QString> keys;
    for (const auto &value : existing) {
        keys.insert(value.toObject()["key"].toString());
    }
    auto result = existing;
    for (const auto &value : values) {
        const auto key = value.toObject()["key"].toString();
        if (!keys.contains(key)) {
            keys.insert(key);
            result.append(value);
        }
    }
    return result;
}

QJsonArray ordered(const QJsonArray &ids, const QJsonArray &songs) {
    QHash<QString, QJsonObject> entries;
    for (const auto &value : songs) {
        const auto song = value.toObject();
        const auto id = song["id"].toString();
        if (!entries.contains(id)) {
            entries.insert(id, song);
        }
    }
    QJsonArray result;
    for (const auto &id : ids) {
        if (entries.contains(id.toString())) {
            result.append(entries[id.toString()]);
        }
    }
    return result;
}

QJsonArray slice(const QJsonArray &values, qsizetype start, qsizetype count) {
    QJsonArray result;
    const auto end = std::min(values.size(), start + count);
    for (auto i = std::max(qsizetype(0), start); i < end; ++i) {
        result.append(values.at(i));
    }
    return result;
}

int indexOf(const QJsonArray &values, const QJsonValue &value) {
    for (qsizetype i = 0; i < values.size(); ++i) {
        if (values.at(i) == value) {
            return int(i);
        }
    }
    return -1;
}

int indexOfId(const QJsonArray &values, const QString &id) {
    for (qsizetype i = 0; i < values.size(); ++i) {
        if (values.at(i).toObject()["id"].toString() == id) {
            return int(i);
        }
    }
    return -1;
}

int cursor(const QJsonArray &songs, const QJsonArray &ids) {
    const auto index = songs.isEmpty() ? -1 : indexOf(ids, songs.last().toObject()["id"]);
    return index < 0 ? int(songs.size()) : index + 1;
}

QString pad(int value, int width) {
    return QString::number(value).rightJustified(width, QLatin1Char('0'));
}

QString time(const QJsonObject &track) {
    const auto duration = track["duration"].toDouble();
    if (duration <= 0) {
        return QStringLiteral("暂无");
    }
    return pad(int(duration / 60000)) + ":" + pad(int(duration / 1000) % 60);
}
QJsonObject queueSource(const QJsonObject &item) {
    const auto provider = item.value("provider").toString();
    const auto id = item.value("id").toString();
    const auto title = item.value("title").toString();
    if (provider.isEmpty() || id.isEmpty() || title.isEmpty()) { return {}; }
    auto route = item.value("route").toString();
    auto type = item.value("type").toString(item.value("originType").toString(item.value("kind").toString()));
    if (route.isEmpty()) {
        if (item.value("virtual").toBool() && id == "daily") { route = "discover"; type = "daily"; }
        else if (QStringList{"playlist", "album", "artist", "radio"}.contains(item.value("kind").toString())) { route = "directory"; }
        else { return {}; }
    }
    if (!QStringList{"directory", "discover", "search", "likes", "profile"}.contains(route)) { return {}; }
    const auto kind = item.value("kind").toString();
    if (route == "directory" && !QStringList{"playlist", "album", "artist", "radio"}.contains(kind)) { return {}; }
    // Whitelist route parameters. Never persist whole directory objects or infer an album.
    QJsonObject result{{"version", 1}, {"route", route}, {"type", type},
        {"kind", kind}, {"id", id}, {"title", title}, {"provider", provider}};
    for (const auto &field : {"tab", "query", "searchKind", "category", "area", "section", "filter"}) {
        if (item.value(field).isString()) { result[field] = item.value(field); }
    }
    if (route == "discover" && !result.contains("tab")) { result["tab"] = id; }
    return result;
}
QJsonObject withQueueSource(QJsonObject song, const QJsonObject &origin) {
    const auto source = queueSource(origin);
    if (song.value("kind") == "song" && !source.isEmpty()) { song["queueSource"] = source; }
    return song;
}
QJsonArray withQueueSource(QJsonArray songs, const QJsonObject &origin) {
    if (queueSource(origin).isEmpty()) { return songs; }
    for (int i = 0; i < songs.size(); ++i) { songs.replace(i, withQueueSource(songs.at(i).toObject(), origin)); }
    return songs;
}

}
