#pragma once

#include <QByteArray>
#include <QString>

// Stores a small secret in the operating system's keychain:
// Windows Credential Manager, or the macOS Keychain. Only this user account can read it.
namespace Keychain {

bool store(const QString &name, const QByteArray &secret);
bool load(const QString &name, QByteArray *secret);
void remove(const QString &name);

} // namespace Keychain
