#pragma once
#include <QDateTime>
#include <QElapsedTimer>
#include <QFile>
#include <QJsonArray>
#include <QJsonDocument>
#include <QJsonObject>
#include <QMutex>
#include <QThread>
#include <atomic>

// Opt-in bounded numeric trace. No IDs, URLs, parameters, credentials or titles.
// File I/O is deferred until the isolated probe ends; rendering never writes files.
namespace PipelineDiagnostics {
inline bool enabled() { static const bool on=qEnvironmentVariableIsSet("RHINE_QA_PIPELINE");return on; }
inline QMutex mutex;
inline QJsonArray events;
inline QHash<QString,QJsonObject> totals;
inline std::atomic<int> serial{0},pendingFrame{0};
inline QElapsedTimer clock=[] {QElapsedTimer t;t.start();return t;}();
inline void mark(QString stage,QJsonObject row={}) {
    if(!enabled())return;
    row["stage"]=stage;row["utc_ms"]=QDateTime::currentMSecsSinceEpoch();row["trace_ms"]=clock.nsecsElapsed()/1e6;
    QMutexLocker lock(&mutex);if(events.size()<20000)events.append(row);
}
inline void duration(QString stage,double ms,QJsonObject row={}) {
    if(!enabled())return;
    {QMutexLocker lock(&mutex);auto &t=totals[stage];t["count"]=t["count"].toInt()+1;t["total_ms"]=t["total_ms"].toDouble()+ms;t["max_ms"]=qMax(ms,t["max_ms"].toDouble());}
    if(ms>=1){row["duration_ms"]=ms;mark(stage,row);}
}
struct Scope {
    QString stage;QElapsedTimer timer;
    explicit Scope(QString s):stage(std::move(s)){if(enabled())timer.start();}
    ~Scope(){if(timer.isValid())duration(stage,timer.nsecsElapsed()/1e6);}
};
inline void qml(QString stage) {
    if(!enabled())return;const int id=++serial;mark(stage,{{"marker",id}});pendingFrame=id;
}
inline void save(QString out) {
    QJsonObject stats;{QMutexLocker lock(&mutex);for(auto it=totals.cbegin();it!=totals.cend();++it)stats[it.key()]=it.value();
        QFile f(out+"/pipeline.json");if(f.open(QIODevice::WriteOnly))f.write(QJsonDocument(QJsonObject{{"events",events},{"scopes",stats}}).toJson());}
}
}
