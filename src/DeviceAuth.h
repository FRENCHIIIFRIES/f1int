#pragma once

#include <QString>
#include <functional>

class QWindow;

// "Is it really you?" using the device login: Windows Hello (face, fingerprint or PIN)
// or Touch ID / the Mac password. The answer arrives later on the UI thread.
namespace DeviceAuth {

using Callback = std::function<void(bool ok, const QString &error)>;
void request(QWindow *window, const QString &reason, Callback done);

} // namespace DeviceAuth
