#pragma once

#include <QString>
#include <QUrl>

// Turns what the user typed in the address bar into a URL to open:
// a web address if it looks like one, otherwise a search.
// searchTemplate is a search URL where "%s" stands for the query,
// e.g. "https://duckduckgo.com/?q=%s". Returns an empty QUrl for empty input.
QUrl urlFromInput(const QString &input, const QString &searchTemplate);
