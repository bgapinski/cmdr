#include <QtDeclarative/qmlcontext.h>
#include <QtDeclarative/qmlengine.h>
#include "qml.h"
#include <QPoint>
#include <QRegion>
#include <QFxMouseRegion>

#ifndef MaskedMouseRegion_H
#define MaskedMouseRegion_H

class MaskedMouseRegion : public QFxMouseRegion
{
    Q_OBJECT
public:
    MaskedMouseRegion();

    //Q_PROPERTY(int testX READ testX WRITE setTestX);
    //Q_PROPERTY(int testY READ testY WRITE setTestY);
    //Q_PROPERTY(bool inPolygon READ inPolygon NOTIFY inPolygonChanged(bool));
    Q_PROPERTY(QString maskPath READ maskPath WRITE setMaskPath);

    QString maskPath() const;
    void setMaskPath(QString);
protected:
    void mousePressEvent(QGraphicsSceneMouseEvent *event);
private:
    QRegion *region;
    QString m_maskPath;
};
QML_DECLARE_TYPE(MaskedMouseRegion);
#endif // MaskedMouseRegion_H
