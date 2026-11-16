# Third-party software in f1int

f1int's own code is under the MIT licence (see `LICENSE`). The installers also
contain the following libraries, each under its own licence.

## Qt 6 (The Qt Company)

f1int uses Qt under the **GNU Lesser General Public License v3 (LGPL-3.0)**.
The full LGPL-3.0 and GPL-3.0 texts are in `licenses/Qt-LGPL-3.0-and-GPL-3.0.txt`.

- Qt is linked dynamically: the Qt libraries are separate files (`Qt6*.dll` on Windows,
  `Qt*.framework` on Mac), so you can replace them with your own build of Qt.
- Qt source code: https://code.qt.io and https://download.qt.io/official_releases/qt/
- f1int's source code, including the build files used to make these installers:
  https://github.com/FRENCHIIIFRIES/f1int

## Qt WebEngine and Chromium

Qt WebEngine (LGPL-3.0) is built on the Chromium project, which includes many
components under BSD-style and other open-source licences. The full list is in the
Qt WebEngine documentation: https://doc.qt.io/qt-6/qtwebengine-licensing.html

## Microsoft Visual C++ runtime (Windows only)

The `msvcp140.dll` / `vcruntime140*.dll` files are redistributed under the
Microsoft Visual Studio redistributable licence terms.
