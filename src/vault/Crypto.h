#pragma once

#include <QByteArray>

// The few crypto operations the password vault needs, done with Mbed TLS.
namespace Crypto {

// Cryptographically secure random bytes (from the operating system).
QByteArray randomBytes(int count);

// AES-256-GCM. `key` must be 32 bytes. The result is nonce (12) + ciphertext + tag (16).
// `context` is authenticated but not encrypted (binds the data to its purpose).
QByteArray seal(const QByteArray &key, const QByteArray &plaintext, const QByteArray &context);
// Reverses seal(). Returns false if the key is wrong or anything was changed.
bool open(const QByteArray &key, const QByteArray &sealed, const QByteArray &context, QByteArray *plaintext);

// PBKDF2-HMAC-SHA256: turns a master password into a 32-byte key. Slow on purpose.
QByteArray deriveKey(const QByteArray &password, const QByteArray &salt, int iterations);

// Overwrite secret bytes before freeing them.
void wipe(QByteArray &secret);

} // namespace Crypto
