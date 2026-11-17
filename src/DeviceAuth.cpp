#include "DeviceAuth.h"

#include <QCoreApplication>
#include <QMetaObject>
#include <QWindow>

#if defined(Q_OS_WIN)
// Windows Hello through the Windows Runtime (C++/WinRT headers come with the Windows SDK).
#define NOMINMAX
#include <windows.h>
#include <UserConsentVerifierInterop.h>
#include <winrt/Windows.Foundation.h>
#include <winrt/Windows.Security.Credentials.UI.h>

using winrt::Windows::Security::Credentials::UI::UserConsentVerifier;
using winrt::Windows::Security::Credentials::UI::UserConsentVerificationResult;
using winrt::Windows::Foundation::IAsyncOperation;
using WinRtStatus = winrt::Windows::Foundation::AsyncStatus;   // (a different AsyncStatus also exists)

namespace DeviceAuth {

static QString describe(UserConsentVerificationResult r)
{
    switch (r) {
    case UserConsentVerificationResult::DeviceNotPresent:
    case UserConsentVerificationResult::NotConfiguredForUser:
        return QCoreApplication::translate("DeviceAuth", "Windows Hello isn't set up on this PC. Use your master password.");
    case UserConsentVerificationResult::DisabledByPolicy:
        return QCoreApplication::translate("DeviceAuth", "Windows Hello is turned off by your organisation.");
    case UserConsentVerificationResult::Canceled:
        return QCoreApplication::translate("DeviceAuth", "Cancelled.");
    default:
        return QCoreApplication::translate("DeviceAuth", "Windows Hello couldn't confirm it's you.");
    }
}

void request(QWindow *window, const QString &reason, Callback done)
{
    const auto finish = [done](bool ok, const QString &error) {   // always answer on the UI thread
        QMetaObject::invokeMethod(qApp, [done, ok, error] { done(ok, error); }, Qt::QueuedConnection);
    };
    try {
        auto interop = winrt::get_activation_factory<UserConsentVerifier, IUserConsentVerifierInterop>();
        const winrt::hstring message(reason.toStdWString());
        IAsyncOperation<UserConsentVerificationResult> operation{ nullptr };
        // "ForWindow" puts the Hello prompt in front of our window instead of somewhere random.
        winrt::check_hresult(interop->RequestVerificationForWindowAsync(
            HWND(window ? window->winId() : 0), static_cast<HSTRING>(winrt::get_abi(message)),
            winrt::guid_of<IAsyncOperation<UserConsentVerificationResult>>(), winrt::put_abi(operation)));
        operation.Completed([finish](const IAsyncOperation<UserConsentVerificationResult> &op, WinRtStatus status) {
            if (status != WinRtStatus::Completed)
                return finish(false, QCoreApplication::translate("DeviceAuth", "Cancelled."));
            const auto result = op.GetResults();
            finish(result == UserConsentVerificationResult::Verified, describe(result));
        });
    } catch (const winrt::hresult_error &e) {
        finish(false, QString::fromWCharArray(e.message().c_str()));
    }
}

} // namespace DeviceAuth

#elif !defined(Q_OS_MACOS)
namespace DeviceAuth {   // other systems: no device check, use the master password
void request(QWindow *, const QString &, Callback done)
{
    QMetaObject::invokeMethod(qApp, [done] { done(false, QCoreApplication::translate("DeviceAuth", "Not available on this system.")); },
                              Qt::QueuedConnection);
}
} // namespace DeviceAuth
#endif
// macOS: see DeviceAuth_mac.mm (Touch ID / Mac login password).
