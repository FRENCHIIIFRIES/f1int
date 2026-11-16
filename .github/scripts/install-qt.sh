#!/usr/bin/env bash
# Installs Qt on a GitHub build machine with Qt's official online installer
# (the same one you use on your PC). It needs a free Qt account, given as the
# repository secrets QT_EMAIL and QT_PW.
# Usage: install-qt.sh <install folder> <package id>...
set -euo pipefail
dir=$1; shift
base=https://download.qt.io/official_releases/online_installers

case "$(uname -s)" in
  MINGW*|MSYS*|CYGWIN*)   # Windows
    curl -fsSL -o qt-installer.exe "$base/qt-online-installer-windows-x64-online.exe"
    installer=./qt-installer.exe ;;
  Darwin)                 # macOS: the installer is an app inside a disk image
    curl -fsSL -o qt-installer.dmg "$base/qt-online-installer-macOS-universal.dmg"
    hdiutil attach -quiet -nobrowse -mountpoint /Volumes/qt-installer qt-installer.dmg
    installer=$(find /Volumes/qt-installer -path '*.app/Contents/MacOS/*' -type f -print -quit) ;;
  *) echo "unsupported OS" >&2; exit 1 ;;
esac

"$installer" --root "$dir" --email "$QT_EMAIL" --pw "$QT_PW" \
  --accept-licenses --accept-obligations --default-answer --confirm-command \
  install "$@"
