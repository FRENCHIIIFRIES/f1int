#pragma once

#include <QLockFile>
#include <QObject>
#include <QUrl>
#include <QVariantList>
#include <QtQml/qqmlregistration.h>
#include <memory>

// Local browser profiles. Each profile is f1int running under its own name ("f1int" for
// the first one, "f1int-p-<id>" for others), so Qt keeps its settings, bookmarks, history,
// passwords, themes and website logins in separate folders: nothing is shared.
// Opening another profile starts another f1int process with --profile=<id>.
class Profiles : public QObject
{
    Q_OBJECT
    QML_ELEMENT
    QML_UNCREATABLE("Use Browser.profiles")
    Q_PROPERTY(QString current READ current CONSTANT)          // "" = the first profile
    Q_PROPERTY(QVariantList list READ list NOTIFY changed)      // [{ id, name, picture, current }]
    Q_PROPERTY(QString currentName READ currentName NOTIFY changed)
    Q_PROPERTY(QUrl currentPicture READ currentPicture NOTIFY changed)

public:
    explicit Profiles(const QString &current, QObject *parent = nullptr);

    // "f1int", or the test name in UI test runs: tests get a separate set of profiles.
    static QString family;
    // The application name for a profile id ("" = the first profile). Ids are checked first.
    static QString appNameFor(const QString &id);
    static bool validId(const QString &id);

    QString current() const { return m_current; }
    QVariantList list() const;
    QString currentName() const;
    QUrl currentPicture() const;

    Q_INVOKABLE QString add(const QString &name);                    // returns the new id
    Q_INVOKABLE void rename(const QString &id, const QString &name);
    Q_INVOKABLE bool setPicture(const QString &id, const QUrl &image);  // any image file; stored as a 256 px square
    Q_INVOKABLE void clearPicture(const QString &id);
    Q_INVOKABLE bool open(const QString &id);                        // a window of that profile
    // Deletes a profile and everything it stored. Not the first one, not this one, not one
    // that's open. Returns "" or a reason for the user.
    Q_INVOKABLE QString remove(const QString &id);

signals:
    void changed();

private:
    QString pictureFile(const QString &id) const;
    QVariantList stored() const;
    void store(const QVariantList &list);

    QString m_current;
    std::unique_ptr<QLockFile> m_lock;   // held while this profile runs (others can see it's open)
    int m_revision = 0;
};
