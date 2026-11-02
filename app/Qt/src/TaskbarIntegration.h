#pragma once
#include <QObject>
#include <QImage>
#include <QPointer>
#include <QVariantMap>
#include <QWindow>
#include <functional>
#include <memory>

struct TaskbarPlayback {
    QString identity, title, artist;
    QImage artwork;
    bool playing = false;
    bool playable = false;
    bool previous = false;
    bool next = false;
    bool canLike = false;
    bool liked = false;
};

// One adapter belongs to the main window, never to the desktop lyric window.
class TaskbarIntegration : public QObject {
  public:
    TaskbarIntegration(QWindow *window, std::function<void(QString)> command);
    ~TaskbarIntegration() override;
    void update(const TaskbarPlayback &playback);
    QImage thumbnail(QSize bounds) const;
    QString windowTitle() const;
    bool trigger(int button);
    QVariantMap diagnostics() const;
  protected:
    bool eventFilter(QObject *watched, QEvent *event) override;
  private:
    struct Native;
    std::unique_ptr<Native> m_native;
    QPointer<QWindow> m_window;
    TaskbarPlayback m_playback;
    std::function<void(QString)> m_command;
    QString m_originalTitle;
    int m_artworkRevision = 0;
    int m_buttonRevision = 0;
};
