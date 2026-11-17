// Checks the password vault: encryption, locking, matching, CSV import/export, health checks.
#include <QtTest>
#include <QTemporaryDir>
#include "PasswordVault.h"

class TestVault : public QObject
{
    Q_OBJECT
    QTemporaryDir dir;
    QString path() const { return dir.filePath("passwords.vault"); }

private slots:
    void setUpLockUnlock()
    {
        PasswordVault v(path(), "test-key");
        QCOMPARE(v.state(), QString("none"));
        QVERIFY(!v.setUp("short", false));                 // master password too short
        QVERIFY(v.setUp("correct horse battery", false));
        QCOMPARE(v.state(), QString("unlocked"));
        v.save(QUrl("https://example.com/login"), "ana", "S3cret!pass");
        v.lock();
        QCOMPARE(v.state(), QString("locked"));
        QVERIFY(v.entries().isEmpty());                    // nothing readable while locked
        QVERIFY(!v.unlock("wrong password"));
        QVERIFY(v.unlock("correct horse battery"));

        PasswordVault again(path(), "test-key");           // a fresh instance reads the file
        QCOMPARE(again.state(), QString("locked"));
        QVERIFY(again.unlock("correct horse battery"));
        QCOMPARE(again.entries().size(), 1);
    }

    void fileIsEncryptedAndTamperProof()
    {
        QFile f(path());
        QVERIFY(f.open(QIODevice::ReadOnly));
        QByteArray raw = f.readAll();
        f.close();
        QVERIFY(!raw.contains("S3cret!pass"));            // the password isn't stored in plain text
        QVERIFY(!raw.contains("ana"));

        // Flip one character of the encrypted data: unlocking must fail, not return garbage.
        const int at = int(raw.indexOf("\"data\": \"")) + 20;
        raw[at] = raw[at] == 'A' ? 'B' : 'A';
        QVERIFY(f.open(QIODevice::WriteOnly));
        f.write(raw);
        f.close();
        PasswordVault v(path(), "test-key");
        QVERIFY(!v.unlock("correct horse battery"));
        QFile::remove(path());
    }

    void matching()
    {
        PasswordVault v(path(), "test-key");
        QVERIFY(v.setUp("correct horse battery", false));
        const QString id = v.save(QUrl("https://www.shop.test/account"), "bo", "pw-one-1234A");
        QCOMPARE(v.loginsFor(QUrl("https://shop.test/login")).size(), 1);   // www or not: same site
        QCOMPARE(v.loginsFor(QUrl("http://shop.test/login")).size(), 0);    // never to an insecure page
        QCOMPARE(v.loginsFor(QUrl("https://evil-shop.test/")).size(), 0);
        QCOMPARE(v.saveKind(QUrl("https://shop.test/x"), "bo", "pw-one-1234A"), QString("same"));
        QCOMPARE(v.saveKind(QUrl("https://shop.test/x"), "bo", "pw-two-5678B"), QString("update"));
        QCOMPARE(v.saveKind(QUrl("https://shop.test/x"), "cy", "pw-two-5678B"), QString("new"));
        v.save(QUrl("https://shop.test/x"), "bo", "pw-two-5678B");          // update, not a second entry
        QCOMPARE(v.entries().size(), 1);
        QCOMPARE(v.password(id), QString("pw-two-5678B"));
        QVERIFY(v.recentlyVerified());                                      // just unlocked
        QCOMPARE(v.reveal(id), QString("pw-two-5678B"));
        v.remove(id);
        QVERIFY(v.entries().isEmpty());
        v.forgetVault();
        QCOMPARE(v.state(), QString("none"));
    }

    void csv()
    {
        const auto rows = PasswordVault::parseCsv("name,url,username,password,note\r\n"
                                                  "a,https://a.test,\"x, y\",\"p\"\"q\",\"two\nlines\"\n");
        QCOMPARE(rows.size(), 2);
        QCOMPARE(rows[1][2], QString("x, y"));        // comma inside quotes
        QCOMPARE(rows[1][3], QString("p\"q"));        // doubled quote
        QCOMPARE(rows[1][4], QString("two\nlines"));  // line break inside quotes

        PasswordVault v(path(), "test-key");
        QVERIFY(v.setUp("correct horse battery", false));
        const QString in = dir.filePath("google.csv");
        QFile f(in);
        QVERIFY(f.open(QIODevice::WriteOnly));
        f.write("\xEF\xBB\xBFname,url,username,password,note\n"   // Google's export starts with a BOM
                "Mail,https://mail.test/,me@mail.test,\"Hunter2,really\",\n"
                "Bank,https://bank.test/login,me,Tr0ub4dor&3xx,\n"
                "Empty,https://empty.test/,me,,\n");
        f.close();
        QCOMPARE(v.importCsv(QUrl::fromLocalFile(in)), 2);   // the row without a password is skipped
        QCOMPARE(v.importCsv(QUrl::fromLocalFile(in)), 0);   // importing twice adds nothing

        const QString out = dir.filePath("export.csv");
        QVERIFY(v.exportCsv(QUrl::fromLocalFile(out)));
        PasswordVault w(dir.filePath("other.vault"), "test-key-2");
        QVERIFY(w.setUp("another long master", false));
        QCOMPARE(w.importCsv(QUrl::fromLocalFile(out)), 2);  // export -> import round trip
        const QString mail = w.loginsFor(QUrl("https://mail.test/")).first().toMap()["id"].toString();
        QCOMPARE(w.password(mail), QString("Hunter2,really"));
        v.forgetVault();
        w.forgetVault();
    }

    void health()
    {
        QVERIFY(PasswordVault::isWeak("password"));
        QVERIFY(PasswordVault::isWeak("abc12"));          // too short
        QVERIFY(PasswordVault::isWeak("lowercase1"));     // under 12 characters with only 2 kinds
        QVERIFY(!PasswordVault::isWeak("Correct-Horse-9"));
        PasswordVault v(path(), "test-key");
        QVERIFY(v.setUp("correct horse battery", false));
        v.save(QUrl("https://a.test"), "x", "Same-Password-1");
        v.save(QUrl("https://b.test"), "x", "Same-Password-1");
        v.save(QUrl("https://c.test"), "x", "123456");
        const QVariantMap h = v.health();
        QCOMPARE(h["reused"].toInt(), 2);
        QCOMPARE(h["weak"].toInt(), 1);
        v.forgetVault();
    }

    void generator()
    {
        const QString a = PasswordVault::generate(20), b = PasswordVault::generate(20);
        QCOMPARE(a.size(), 20);
        QVERIFY(a != b);
        QVERIFY(!PasswordVault::isWeak(a));
        QCOMPARE(PasswordVault::generate(4).size(), 12);  // never shorter than 12
    }
};

QTEST_GUILESS_MAIN(TestVault)
#include "tst_vault.moc"
