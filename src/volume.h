/*
 * This file was generated by qdbusxml2cpp version 0.7
 * Command line was: qdbusxml2cpp -c Volume -p volume.h:volume.cpp /home/mwylde/Desktop/introspect.xml
 *
 * qdbusxml2cpp is Copyright (C) 2009 Nokia Corporation and/or its subsidiary(-ies).
 *
 * This is an auto-generated file.
 * Do not edit! All changes made to it will be lost.
 */

#ifndef VOLUME_H_1256160757
#define VOLUME_H_1256160757

#include <QtCore/QObject>
#include <QtCore/QByteArray>
#include <QtCore/QList>
#include <QtCore/QMap>
#include <QtCore/QString>
#include <QtCore/QStringList>
#include <QtCore/QVariant>
#include <QtDBus/QtDBus>

/*
 * Proxy class for interface edu.wesleyan.WesControl.volume
 */
class Volume: public QDBusAbstractInterface
{
    Q_OBJECT
public:
    static inline const char *staticInterfaceName()
    { return "edu.wesleyan.WesControl.volume"; }

public:
    Volume(const QString &service, const QString &path, const QDBusConnection &connection, QObject *parent = 0);

    ~Volume();

public Q_SLOTS: // METHODS
    inline QDBusPendingReply<bool> mute()
    {
        QList<QVariant> argumentList;
        return asyncCallWithArgumentList(QLatin1String("mute"), argumentList);
    }

    inline QDBusPendingReply<QString> set_mute(bool on)
    {
        QList<QVariant> argumentList;
        argumentList << qVariantFromValue(on);
        return asyncCallWithArgumentList(QLatin1String("set_mute"), argumentList);
    }

    inline QDBusPendingReply<QString> set_volume(double volume)
    {
        QList<QVariant> argumentList;
        argumentList << qVariantFromValue(volume);
        return asyncCallWithArgumentList(QLatin1String("set_volume"), argumentList);
    }

    inline QDBusPendingReply<double> volume()
    {
        QList<QVariant> argumentList;
        return asyncCallWithArgumentList(QLatin1String("volume"), argumentList);
    }

Q_SIGNALS: // SIGNALS
    void mute_changed(bool on);
    void volume_changed(double volume);
};

namespace edu {
  namespace wesleyan {
    namespace WesControl {
      typedef ::Volume volume;
    }
  }
}
#endif
