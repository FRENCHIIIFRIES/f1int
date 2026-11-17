// Touch ID (or the Mac's login password) through Apple's LocalAuthentication framework.
// Compiled with ARC (automatic memory management), see CMakeLists.txt.
#include "DeviceAuth.h"

#include <QCoreApplication>
#include <QMetaObject>
#import <LocalAuthentication/LocalAuthentication.h>

namespace DeviceAuth {

void request(QWindow *, const QString &reason, Callback done)
{
    LAContext *context = [[LAContext alloc] init];
    NSError *error = nil;
    // "DeviceOwnerAuthentication" = Touch ID, falling back to the login password.
    if (![context canEvaluatePolicy:LAPolicyDeviceOwnerAuthentication error:&error]) {
        const QString message = QString::fromNSString(error.localizedDescription);
        QMetaObject::invokeMethod(qApp, [done, message] { done(false, message); }, Qt::QueuedConnection);
        return;
    }
    [context evaluatePolicy:LAPolicyDeviceOwnerAuthentication
            localizedReason:reason.toNSString()
                      reply:^(BOOL success, NSError *e) {
                          const QString message = e ? QString::fromNSString(e.localizedDescription) : QString();
                          const bool ok = success;
                          QMetaObject::invokeMethod(qApp, [done, ok, message] { done(ok, message); }, Qt::QueuedConnection);
                      }];
}

} // namespace DeviceAuth
