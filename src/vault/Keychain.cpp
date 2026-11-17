#include "Keychain.h"

#if defined(Q_OS_WIN)
#define NOMINMAX
#include <windows.h>
#include <wincred.h>

// Windows Credential Manager: "generic" credentials, protected with the user's Windows login.
namespace Keychain {

static std::wstring target(const QString &name) { return (QStringLiteral("f1int/") + name).toStdWString(); }

bool store(const QString &name, const QByteArray &secret)
{
    const std::wstring t = target(name);
    CREDENTIALW cred{};
    cred.Type = CRED_TYPE_GENERIC;
    cred.TargetName = const_cast<wchar_t *>(t.c_str());
    cred.CredentialBlobSize = DWORD(secret.size());
    cred.CredentialBlob = reinterpret_cast<LPBYTE>(const_cast<char *>(secret.constData()));
    cred.Persist = CRED_PERSIST_LOCAL_MACHINE;   // this PC only, never roamed to other machines
    cred.UserName = const_cast<wchar_t *>(L"f1int");
    return CredWriteW(&cred, 0);
}

bool load(const QString &name, QByteArray *secret)
{
    PCREDENTIALW cred = nullptr;
    if (!CredReadW(target(name).c_str(), CRED_TYPE_GENERIC, 0, &cred))
        return false;
    *secret = QByteArray(reinterpret_cast<const char *>(cred->CredentialBlob), int(cred->CredentialBlobSize));
    SecureZeroMemory(cred->CredentialBlob, cred->CredentialBlobSize);
    CredFree(cred);
    return true;
}

void remove(const QString &name)
{
    CredDeleteW(target(name).c_str(), CRED_TYPE_GENERIC, 0);
}

} // namespace Keychain

#elif defined(Q_OS_MACOS)
#include <Security/Security.h>

// macOS Keychain: a "generic password" item for service "f1int".
namespace Keychain {

static CFMutableDictionaryRef query(const QString &name)
{
    CFMutableDictionaryRef q = CFDictionaryCreateMutable(nullptr, 0, &kCFTypeDictionaryKeyCallBacks, &kCFTypeDictionaryValueCallBacks);
    CFStringRef account = name.toCFString();
    CFDictionarySetValue(q, kSecClass, kSecClassGenericPassword);
    CFDictionarySetValue(q, kSecAttrService, CFSTR("f1int"));
    CFDictionarySetValue(q, kSecAttrAccount, account);
    CFRelease(account);
    return q;
}

bool store(const QString &name, const QByteArray &secret)
{
    remove(name);
    CFMutableDictionaryRef q = query(name);
    CFDataRef data = secret.toCFData();
    CFDictionarySetValue(q, kSecValueData, data);
    CFDictionarySetValue(q, kSecAttrAccessible, kSecAttrAccessibleWhenUnlockedThisDeviceOnly);
    const OSStatus status = SecItemAdd(q, nullptr);
    CFRelease(data);
    CFRelease(q);
    return status == errSecSuccess;
}

bool load(const QString &name, QByteArray *secret)
{
    CFMutableDictionaryRef q = query(name);
    CFDictionarySetValue(q, kSecReturnData, kCFBooleanTrue);
    CFTypeRef result = nullptr;
    const OSStatus status = SecItemCopyMatching(q, &result);
    CFRelease(q);
    if (status != errSecSuccess || !result)
        return false;
    *secret = QByteArray::fromCFData(static_cast<CFDataRef>(result));
    CFRelease(result);
    return true;
}

void remove(const QString &name)
{
    CFMutableDictionaryRef q = query(name);
    SecItemDelete(q);
    CFRelease(q);
}

} // namespace Keychain

#else
namespace Keychain {   // other systems: no keychain, so device unlock is unavailable
bool store(const QString &, const QByteArray &) { return false; }
bool load(const QString &, QByteArray *) { return false; }
void remove(const QString &) {}
} // namespace Keychain
#endif
