// SPDX-License-Identifier: AGPL-3.0-only
// Cloudy ui_effects.go / auto_effects.go, Qt controller adaptation.
#pragma once
#include "MusicLibrary.h"
#include <QTimer>
#include <QElapsedTimer>
class SoundEffects : public QObject {
    Q_OBJECT
    Q_PROPERTY(QVariantMap info READ info NOTIFY changed)
    Q_PROPERTY(QVariantList presets READ presets CONSTANT)
    Q_PROPERTY(QVariantList rooms READ rooms CONSTANT)
    Q_PROPERTY(bool opened READ opened NOTIFY openedChanged)
  public:
    SoundEffects(MusicLibrary *music,QObject *parent=nullptr);
    QVariantMap info()const;
    QVariantList presets()const;
    QVariantList rooms()const;
    bool opened()const{return m_open;}
    Q_INVOKABLE void open(){if(!m_open){m_open=true;emit openedChanged();}}
    Q_INVOKABLE void close(){if(m_open){m_open=false;emit openedChanged();}save();}
    Q_INVOKABLE void setValue(QString key,QVariant value);
    Q_INVOKABLE void setBand(int index,double value);
    Q_INVOKABLE void usePreset(QString id);
    Q_INVOKABLE void toggleSpatial(QString id);
    Q_INVOKABLE void resetEnhance();
    void follow();
  signals:
    void changed();
    void openedChanged();
  private:
    MusicLibrary *m_music;
    CloudyEffects::Settings m_settings,m_auto;
    QString m_preset="flat",m_note,m_song;
    QHash<QString,QJsonObject> m_tagCache;
    bool m_open=false,m_autoReady=false;
    QTimer m_save,m_listen;
    QElapsedTimer m_hearing;
    std::array<double,24> m_heard{};
    void apply(bool glide=false);
    void save();
    void choose(QJsonObject tags);
    void listen();
    void autoApply(CloudyEffects::Settings settings,QString note);
    bool automatic()const{return m_settings.on&&(m_preset=="smart"||m_preset=="mood");}
};
