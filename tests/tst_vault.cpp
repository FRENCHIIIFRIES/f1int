// Checks the password vault: encryption, locking, matching, CSV import/export, health checks.
#include <QtTest>
#include <QTemporaryDir>
#include "PasswordVault.h"

class TestVault : public QObject
{
    Q_OBJECT
    QTemporaryDir dir;
    QString path() const { return dir.filePath("passwords.vault"); }
    QString write(const QString &name, const QByteArray &data) const
    {
        QFile f(dir.filePath(name));
        if (!f.open(QIODevice::WriteOnly) || f.write(data) != data.size())
            qFatal("can't write %s", qPrintable(f.fileName()));
        return f.fileName();
    }

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
                                                  "a,https://a.test,\"x, y\",\"p\"\"q\",\"two\nlines\"\n"
                                                  "b,https://b.test,me,ab\"c,\n");
        QCOMPARE(rows.size(), 3);
        QCOMPARE(rows[1][2], QString("x, y"));        // comma inside quotes
        QCOMPARE(rows[1][3], QString("p\"q"));        // doubled quote
        QCOMPARE(rows[1][4], QString("two\nlines"));  // line break inside quotes
        QCOMPARE(rows[2][3], QString("ab\"c"));       // a stray quote mid-field is just a character
        QCOMPARE(rows[2].size(), 5);

        // UTF-16 with a byte-order mark (Notepad's "Unicode"): read as such, mark dropped.
        QStringEncoder utf16(QStringConverter::Utf16LE, QStringEncoder::Flag::WriteBom);
        const QByteArray wide = utf16(QStringLiteral("url,password\nhttps://u.test,Pässwort\n"));
        const auto wideRows = PasswordVault::parseCsv(wide);
        QCOMPARE(wideRows[0][0], QString("url"));
        QCOMPARE(wideRows[1][1], QString("Pässwort"));

        PasswordVault v(path(), "test-key");
        QVERIFY(v.setUp("correct horse battery", false));
        const QString in = write("google.csv", "\xEF\xBB\xBFname,url,username,password,note\n"   // Google's export starts with a BOM
                                               "Mail,https://mail.test/,me@mail.test,\"Hunter2,really\",\n"
                                               "Bank,https://bank.test/login,me,Tr0ub4dor&3xx,\n"
                                               "Empty,https://empty.test/,me,,\n");
        QVariantMap r = v.importCsv(QUrl::fromLocalFile(in));
        QCOMPARE(r["error"].toString(), QString());
        QCOMPARE(r["imported"].toInt(), 2);
        QCOMPARE(r["skipped"].toInt(), 1);                     // the row without a password
        r = v.importCsv(QUrl::fromLocalFile(in));
        QCOMPARE(r["imported"].toInt(), 0);                    // importing twice adds nothing ...
        QCOMPARE(r["duplicates"].toInt(), 2);                  // ... and says so
        QCOMPARE(v.entries().size(), 2);

        // A newer password for the same login replaces the saved one (no second entry).
        r = v.importCsv(QUrl::fromLocalFile(write("newer.csv", "url,username,password\nhttps://bank.test/,me,Newer-Pass-77\n")));
        QCOMPARE(r["imported"].toInt(), 1);
        QCOMPARE(v.entries().size(), 2);
        QCOMPARE(v.password(v.loginsFor(QUrl("https://bank.test/")).first().toMap()["id"].toString()), QString("Newer-Pass-77"));

        const QString out = dir.filePath("export.csv");
        QVERIFY(v.exportCsv(QUrl::fromLocalFile(out)));
        PasswordVault w(dir.filePath("other.vault"), "test-key-2");
        QVERIFY(w.setUp("another long master", false));
        QCOMPARE(w.importCsv(QUrl::fromLocalFile(out))["imported"].toInt(), 2);  // export -> import round trip
        const QString mail = w.loginsFor(QUrl("https://mail.test/")).first().toMap()["id"].toString();
        QCOMPARE(w.password(mail), QString("Hunter2,really"));
        v.forgetVault();
        w.forgetVault();
    }

    // Real export formats, each as LF, CRLF and CRLF with a UTF-8 byte-order mark.
    void formats_data()
    {
        QTest::addColumn<QString>("file");
        QTest::addColumn<int>("imported");
        QTest::addColumn<int>("skipped");
        QTest::addColumn<int>("duplicates");
        QTest::addColumn<QString>("page");       // one login to check
        QTest::addColumn<QString>("username");
        QTest::addColumn<QString>("password");
        QTest::newRow("Google / Chrome") << "chrome.csv" << 4 << 1 << 1 << "https://accounts.example.test/x" << "ana@example.test" << "pa,ss\"word";
        QTest::newRow("Edge") << "edge.csv" << 3 << 0 << 0 << "https://café.test/" << "zoë" << "Pässwörd-ß-€-42";
        QTest::newRow("Firefox") << "firefox.csv" << 2 << 0 << 0 << "https://forum.test/login" << "bo" << "fire\"fox,pass";
        QTest::newRow("Safari") << "safari.csv" << 2 << 1 << 0 << "https://bank.test/" << "ana" << "Safari, with comma";
        QTest::newRow("Bitwarden") << "bitwarden.csv" << 2 << 1 << 0 << "https://git.test/" << "dev" << "Bitwarden-Pass-1";
        QTest::newRow("1Password") << "1password.csv" << 2 << 1 << 0 << "https://social.test/" << "ana@example.test" << "1P-Pass-2";
        QTest::newRow("LastPass") << "lastpass.csv" << 2 << 1 << 0 << "https://news.test/" << "ana" << "LastPass-Pass-1";
    }
    void formats()
    {
        QFETCH(QString, file);
        QFETCH(int, imported);
        QFETCH(int, skipped);
        QFETCH(int, duplicates);
        QFETCH(QString, page);
        QFETCH(QString, username);
        QFETCH(QString, password);
        QFile sample(QFINDTESTDATA("data/passwords/" + file));
        QVERIFY2(sample.open(QIODevice::ReadOnly), qPrintable(file));
        const QByteArray lf = sample.readAll().replace("\r\n", "\n");   // git may have checked it out with CRLF
        QByteArray crlf = lf;
        crlf.replace("\n", "\r\n");
        for (const QByteArray &data : { lf, crlf, "\xEF\xBB\xBF" + crlf }) {
            PasswordVault v(path(), "test-key");
            QVERIFY(v.setUp("correct horse battery", false));
            const QUrl url = QUrl::fromLocalFile(write(file, data));
            QVariantMap r = v.importCsv(url);
            QCOMPARE(r["error"].toString(), QString());
            QCOMPARE(r["imported"].toInt(), imported);
            QCOMPARE(r["skipped"].toInt(), skipped);
            QCOMPARE(r["duplicates"].toInt(), duplicates);
            const QVariantList found = v.loginsFor(QUrl(page));
            QCOMPARE(found.size(), 1);
            QCOMPARE(found[0].toMap()["username"].toString(), username);
            QCOMPARE(v.password(found[0].toMap()["id"].toString()), password);
            if (file == "chrome.csv") {   // an Android app's login keeps the app's name
                QCOMPARE(v.loginsFor(QUrl("android://com.example.notes")).size(), 1);
                QCOMPARE(v.entries("com.example.notes").first().toMap()["origin"].toString(), QString("android://com.example.notes"));
            }
            r = v.importCsv(url);                                // the same file again: nothing new
            QCOMPARE(r["imported"].toInt(), 0);
            QCOMPARE(r["duplicates"].toInt(), imported + duplicates);
            QCOMPARE(v.entries().size(), imported);
            v.forgetVault();
        }
    }

    void bigFile()
    {
        QByteArray csv = "name,url,username,password,note\n";
        for (int i = 0; i < 20000; ++i)   // every 10th site was "never save" in the browser: no password
            csv += QStringLiteral("site%1.test,https://site%1.test/login,user%1,%2,\n").arg(i).arg(i % 10 ? QStringLiteral("Pass-%1-x").arg(i) : QString()).toUtf8();
        PasswordVault v(path(), "test-key");
        QVERIFY(v.setUp("correct horse battery", false));
        const QUrl url = QUrl::fromLocalFile(write("big.csv", csv));
        QElapsedTimer t;
        t.start();
        QVariantMap r = v.importCsv(url);
        QCOMPARE(r["imported"].toInt(), 18000);
        QCOMPARE(r["skipped"].toInt(), 2000);
        r = v.importCsv(url);
        QCOMPARE(r["duplicates"].toInt(), 18000);
        QVERIFY2(t.elapsed() < 10000, qPrintable(QString("two imports of 20 000 rows took %1 ms").arg(t.elapsed())));
        QCOMPARE(v.password(v.loginsFor(QUrl("https://site19999.test/")).first().toMap()["id"].toString()), QString("Pass-19999-x"));
        v.forgetVault();
    }

    // File paths as they come from the file picker or a drop: spaces, accents, other
    // scripts, "#" and "%", a OneDrive folder; also after QML turned the url into text.
    void paths()
    {
        PasswordVault v(path(), "test-key");
        QVERIFY(v.setUp("correct horse battery", false));
        QVERIFY(QDir(dir.path()).mkpath("OneDrive - Contoso/Pässwörter 日本 #1"));
        const QString file = write("OneDrive - Contoso/Pässwörter 日本 #1/Chrome Passwords 100%.csv",
                                   "name,url,username,password,note\nx,https://x.test/,me,X-Pass-1,\n");
        const QUrl url = QUrl::fromLocalFile(file);
        for (const QUrl &u : { url, QUrl(url.toString()), QUrl::fromEncoded(url.toEncoded()), QUrl(url.toString(QUrl::FullyEncoded)) }) {
            const QVariantMap r = v.importCsv(u);
            QVERIFY2(r["error"].toString().isEmpty(), qPrintable(u.toString() + ": " + r["error"].toString()));
            QCOMPARE(r["imported"].toInt() + r["duplicates"].toInt(), 1);
        }
        v.forgetVault();
    }

    // Never silently nothing: a missing vault, a locked one, a missing or wrong file all say why.
    void problems()
    {
        const QString in = write("ok.csv", "url,username,password\nhttps://a.test/,me,A-Pass-1\n");
        PasswordVault v(path(), "test-key");
        QVariantMap r = v.importCsv(QUrl::fromLocalFile(in));
        QVERIFY(r["error"].toString().contains("Create"));    // no vault yet
        QVERIFY(v.setUp("correct horse battery", false));
        v.lock();
        r = v.importCsv(QUrl::fromLocalFile(in));
        QVERIFY(r["error"].toString().contains("Unlock"));    // locked
        QCOMPARE(r["imported"].toInt(), 0);
        QVERIFY(v.unlock("correct horse battery"));
        QVERIFY(!v.importCsv(QUrl::fromLocalFile(dir.filePath("missing.csv")))["error"].toString().isEmpty());
        QVERIFY(!v.importCsv(QUrl::fromLocalFile(write("other.csv", "a,b\n1,2\n")))["error"].toString().isEmpty());
        QVERIFY(!v.importCsv(QUrl::fromLocalFile(write("empty.csv", "")))["error"].toString().isEmpty());
        QVERIFY(!v.deleteImportedFile());                      // nothing was imported: nothing to delete
        QVERIFY(QFile::exists(dir.filePath("other.csv")));
        v.forgetVault();
    }

    void deleteImportedFile()
    {
        const QString in = write("export.csv", "url,username,password\nhttps://a.test/,me,A-Pass-1\n");
        const QString other = write("keep.csv", "url,username,password\n");
        PasswordVault v(path(), "test-key");
        QVERIFY(v.setUp("correct horse battery", false));
        QVERIFY(!v.deleteImportedFile());                      // nothing imported yet
        QCOMPARE(v.importCsv(QUrl::fromLocalFile(in))["imported"].toInt(), 1);
        QVERIFY(QFile::exists(in));                            // importing alone never deletes
        QVERIFY(v.deleteImportedFile());
        QVERIFY(!QFile::exists(in));
        QVERIFY(QFile::exists(other));                         // only that one file
        QVERIFY(!v.deleteImportedFile());                      // and only once
        QCOMPARE(v.entries().size(), 1);                       // the passwords stay in the vault
        v.forgetVault();
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
