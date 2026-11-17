#include "Crypto.h"

#include <QRandomGenerator>
#include <mbedtls/gcm.h>
#include <mbedtls/md.h>
#include <mbedtls/pkcs5.h>
#include <mbedtls/platform_util.h>

namespace Crypto {

static constexpr int NonceSize = 12;
static constexpr int TagSize = 16;

QByteArray randomBytes(int count)
{
    QByteArray out(count, Qt::Uninitialized);
    // QRandomGenerator::system() reads the operating system's secure random source.
    QRandomGenerator::system()->generate(reinterpret_cast<quint32 *>(out.data()),
                                         reinterpret_cast<quint32 *>(out.data()) + count / 4);
    for (int i = count - count % 4; i < count; ++i)
        out[i] = char(QRandomGenerator::system()->generate());
    return out;
}

QByteArray seal(const QByteArray &key, const QByteArray &plaintext, const QByteArray &context)
{
    Q_ASSERT(key.size() == 32);
    const QByteArray nonce = randomBytes(NonceSize);   // fresh every time: never reuse a nonce with a key
    QByteArray cipher(plaintext.size(), Qt::Uninitialized);
    unsigned char tag[TagSize];

    mbedtls_gcm_context gcm;
    mbedtls_gcm_init(&gcm);
    int rc = mbedtls_gcm_setkey(&gcm, MBEDTLS_CIPHER_ID_AES, reinterpret_cast<const unsigned char *>(key.constData()), 256);
    if (rc == 0)
        rc = mbedtls_gcm_crypt_and_tag(&gcm, MBEDTLS_GCM_ENCRYPT, size_t(plaintext.size()),
                                       reinterpret_cast<const unsigned char *>(nonce.constData()), NonceSize,
                                       reinterpret_cast<const unsigned char *>(context.constData()), size_t(context.size()),
                                       reinterpret_cast<const unsigned char *>(plaintext.constData()),
                                       reinterpret_cast<unsigned char *>(cipher.data()), TagSize, tag);
    mbedtls_gcm_free(&gcm);
    if (rc != 0)
        return {};
    return nonce + cipher + QByteArray(reinterpret_cast<const char *>(tag), TagSize);
}

bool open(const QByteArray &key, const QByteArray &sealed, const QByteArray &context, QByteArray *plaintext)
{
    if (key.size() != 32 || sealed.size() < NonceSize + TagSize)
        return false;
    const int length = int(sealed.size()) - NonceSize - TagSize;
    QByteArray out(length, Qt::Uninitialized);

    mbedtls_gcm_context gcm;
    mbedtls_gcm_init(&gcm);
    int rc = mbedtls_gcm_setkey(&gcm, MBEDTLS_CIPHER_ID_AES, reinterpret_cast<const unsigned char *>(key.constData()), 256);
    if (rc == 0)
        rc = mbedtls_gcm_auth_decrypt(&gcm, size_t(length),
                                      reinterpret_cast<const unsigned char *>(sealed.constData()), NonceSize,
                                      reinterpret_cast<const unsigned char *>(context.constData()), size_t(context.size()),
                                      reinterpret_cast<const unsigned char *>(sealed.constData() + NonceSize + length), TagSize,
                                      reinterpret_cast<const unsigned char *>(sealed.constData() + NonceSize),
                                      reinterpret_cast<unsigned char *>(out.data()));
    mbedtls_gcm_free(&gcm);
    if (rc != 0) {   // wrong key, or the file was changed: refuse
        wipe(out);
        return false;
    }
    *plaintext = out;
    return true;
}

QByteArray deriveKey(const QByteArray &password, const QByteArray &salt, int iterations)
{
    QByteArray key(32, Qt::Uninitialized);
    const int rc = mbedtls_pkcs5_pbkdf2_hmac_ext(MBEDTLS_MD_SHA256,
                                                 reinterpret_cast<const unsigned char *>(password.constData()), size_t(password.size()),
                                                 reinterpret_cast<const unsigned char *>(salt.constData()), size_t(salt.size()),
                                                 unsigned(iterations), 32, reinterpret_cast<unsigned char *>(key.data()));
    return rc == 0 ? key : QByteArray();
}

void wipe(QByteArray &secret)
{
    if (!secret.isEmpty())
        mbedtls_platform_zeroize(secret.data(), size_t(secret.size()));   // can't be optimised away
    secret.clear();
}

} // namespace Crypto
