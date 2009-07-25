#include <QDBusMessage>
#include <QDBusError>
#include <QDBusConnection>
#include <QDBusInterface>
#include <QtDeclarative/qmlcontext.h>
#include <QtDeclarative/qmlengine.h>
#include "qml.h"

#ifndef VOLUME_H
#define VOLUME_H

#include <QObject>

class Volume : public QObject
{
    Q_OBJECT
public:
    Volume();

    Q_PROPERTY(double volume READ volume WRITE setVolume NOTIFY volumeChanged);
    Q_PROPERTY(bool mute READ mute WRITE setMute NOTIFY muteChanged);

    //the volume is in the range [0,1]
    double volume() const;
    void setVolume(double volume);

    bool mute() const;
    void setMute(bool mute);

signals:
    void volumeChanged(double volume);
    void muteChanged(bool mute);

private slots:
    void volume_changed(double volume);
    void mute_changed(bool mute);
    void responseFromSwitcher(QDBusMessage message);
    void errorFromSwitcher(QDBusError error);

private:
    double m_volume;
    bool m_mute;
};
QML_DECLARE_TYPE(Volume);

#endif // VOLUME_H
