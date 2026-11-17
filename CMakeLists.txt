# CMake is the build recipe: it tells the compiler which files make up f1int
# and which Qt libraries to link against.
cmake_minimum_required(VERSION 3.21)
project(f1int VERSION 0.1.0 LANGUAGES CXX)

set(CMAKE_CXX_STANDARD 17)
set(CMAKE_CXX_STANDARD_REQUIRED ON)

# Qt WebEngine is Chromium. "Test" is only used by the unit tests in tests/.
find_package(Qt6 6.8 REQUIRED COMPONENTS Quick QuickControls2 Svg Sql Network WebEngineQuick Test)
qt_standard_project_setup(REQUIRES 6.8)   # turns on Qt's code generators (moc etc.)

# Mbed TLS (Arm, Apache-2.0): the password vault's AES-256-GCM and PBKDF2.
# Downloaded once at configure time; the checksum makes sure it's the official release.
include(FetchContent)
set(ENABLE_PROGRAMS OFF CACHE BOOL "" FORCE)      # only the library, not its tools...
set(ENABLE_TESTING OFF CACHE BOOL "" FORCE)       # ...or its test suite
set(GEN_FILES OFF CACHE BOOL "" FORCE)            # release archives already contain generated files
set(MBEDTLS_FATAL_WARNINGS OFF CACHE BOOL "" FORCE)
FetchContent_Declare(mbedtls
    URL https://github.com/Mbed-TLS/mbedtls/releases/download/mbedtls-3.6.8/mbedtls-3.6.8.tar.bz2
    URL_HASH SHA256=bc54b818e87f49c0b3281dd85d24adaede0e63b4e822e3fbd49c005a38b9595b
    DOWNLOAD_EXTRACT_TIMESTAMP TRUE)
FetchContent_MakeAvailable(mbedtls)

# The password vault as a small library, shared by the app and its unit test.
add_library(vault STATIC
    src/vault/Crypto.h src/vault/Crypto.cpp
    src/vault/Keychain.h src/vault/Keychain.cpp
    src/vault/PasswordVault.h src/vault/PasswordVault.cpp
)
target_include_directories(vault PUBLIC src/vault)
target_link_libraries(vault PUBLIC Qt6::Gui Qt6::Qml PRIVATE mbedcrypto)
if(WIN32)
    target_link_libraries(vault PRIVATE advapi32)   # Windows Credential Manager
elseif(APPLE)
    target_link_libraries(vault PRIVATE "-framework Security" "-framework CoreFoundation")
endif()

# WIN32 = no black console window on Windows. MACOSX_BUNDLE = build an .app on Mac.
qt_add_executable(f1int WIN32 MACOSX_BUNDLE
    src/main.cpp
    src/Browser.h src/Browser.cpp
    src/UrlInput.h src/UrlInput.cpp
    src/TabModel.h src/TabModel.cpp
    src/Library.h src/Library.cpp
    src/AdBlocker.h src/AdBlocker.cpp
    src/MemoryStats.h src/MemoryStats.cpp
)
target_compile_definitions(f1int PRIVATE F1INT_VERSION="${PROJECT_VERSION}")
# Windows Hello / Touch ID for unlocking passwords.
target_sources(f1int PRIVATE src/DeviceAuth.h src/DeviceAuth.cpp)
if(WIN32)
    target_sources(f1int PRIVATE resources/f1int.rc)   # the .exe icon
    target_link_libraries(f1int PRIVATE windowsapp dwmapi)   # Windows Hello; frosted-glass window
    # Microsoft's C++/WinRT headers need C++20 (coroutines); only this one file uses them.
    set_source_files_properties(src/DeviceAuth.cpp PROPERTIES COMPILE_OPTIONS "/std:c++20")
elseif(APPLE)
    target_sources(f1int PRIVATE src/DeviceAuth_mac.mm)
    set_source_files_properties(src/DeviceAuth_mac.mm PROPERTIES COMPILE_FLAGS "-fobjc-arc")
    target_link_libraries(f1int PRIVATE "-framework LocalAuthentication")
endif()

# Qt's generated QML registration code includes our headers by bare name ("Browser.h").
target_include_directories(f1int PRIVATE src)

# Theme.qml is a singleton: one shared object holding colours and sizes.
set_source_files_properties(qml/Theme.qml PROPERTIES QT_QML_SINGLETON_TYPE TRUE)

# Bundles the QML UI files into the program itself (no loose files to ship).
qt_add_qml_module(f1int
    URI f1int
    QML_FILES
        qml/Main.qml
        qml/Theme.qml
        qml/Toolbar.qml
        qml/IconButton.qml
        qml/Icon.qml
        qml/DotLoader.qml
        qml/DotGrid.qml
        qml/F1Menu.qml
        qml/WebView.qml
        qml/TabSidebar.qml
        qml/TabRow.qml
        qml/PinnedTile.qml
        qml/GroupHeader.qml
        qml/Ui.qml
        qml/FindBar.qml
        qml/LibraryPanel.qml
        qml/SettingsPanel.qml
        qml/MemoryPanel.qml
        qml/ColorWheel.qml
        qml/NewTabPage.qml
        qml/PasswordsPanel.qml
        qml/Welcome.qml
)

# Icons, logo, dot-matrix font and the starter ad-block list, built into the program
# (":/icons/back.svg", ":/logo/f1int.svg", ":/fonts/Doto.ttf", ":/filters/builtin.txt").
file(GLOB icon_files CONFIGURE_DEPENDS resources/icons/*.svg)
qt_add_resources(f1int assets
    PREFIX /
    BASE resources
    FILES ${icon_files} resources/logo/f1int.svg resources/fonts/Doto.ttf resources/filters/builtin.txt
          resources/scripts/passwords.js
)

# Dynamic linking (the default) keeps us within Qt's LGPL licence.
# Svg: draws our icons. Sql: bookmarks/history. Network: filter list updates.
target_link_libraries(f1int PRIVATE Qt6::Quick Qt6::QuickControls2 Qt6::Svg Qt6::Sql Qt6::Network Qt6::WebEngineQuick vault)

# Mac .app details (shown in Finder / "About").
set_target_properties(f1int PROPERTIES
    MACOSX_BUNDLE_GUI_IDENTIFIER io.github.frenchiiifries.f1int
    MACOSX_BUNDLE_BUNDLE_NAME f1int
    MACOSX_BUNDLE_BUNDLE_VERSION ${PROJECT_VERSION}
    MACOSX_BUNDLE_SHORT_VERSION_STRING ${PROJECT_VERSION}
)

# ---- Installing and packaging: cmake --install / cpack ----
# Copies f1int plus every Qt and Chromium file it needs into one folder,
# using Qt's own deploy tool (windeployqt on Windows, macdeployqt on Mac).
include(GNUInstallDirs)
install(TARGETS f1int
    BUNDLE DESTINATION .                          # Mac: f1int.app
    RUNTIME DESTINATION ${CMAKE_INSTALL_BINDIR})  # Windows: bin\f1int.exe
qt_generate_deploy_qml_app_script(TARGET f1int OUTPUT_SCRIPT deploy_script)
install(SCRIPT ${deploy_script})

if(APPLE)
    # The deploy tool edits the app's files, which breaks their signature, and Apple Silicon
    # Macs refuse to run unsigned code. "Ad-hoc" signing (no Apple account) fixes that.
    install(CODE [[
        execute_process(COMMAND codesign --force --deep --sign - "$ENV{DESTDIR}${CMAKE_INSTALL_PREFIX}/f1int.app"
                        COMMAND_ERROR_IS_FATAL ANY)
    ]])
endif()

# Microsoft's C++ runtime DLLs, so f1int runs on PCs that don't have them.
set(CMAKE_INSTALL_SYSTEM_RUNTIME_DESTINATION ${CMAKE_INSTALL_BINDIR})
include(InstallRequiredSystemLibraries)

# Our licence and Qt's (LGPL requires shipping them with the app).
install(FILES LICENSE THIRD_PARTY_NOTICES.md DESTINATION .)
install(DIRECTORY licenses/ DESTINATION licenses)

# CPack turns the installed folder into an installer:
# a setup .exe (NSIS) on Windows, a drag-to-Applications .dmg on Mac.
set(CPACK_PACKAGE_NAME f1int)
set(CPACK_PACKAGE_VENDOR f1int)
set(CPACK_PACKAGE_DESCRIPTION_SUMMARY "A low-RAM Chromium-based browser")
set(CPACK_PACKAGE_INSTALL_DIRECTORY f1int)
set(CPACK_RESOURCE_FILE_LICENSE ${CMAKE_SOURCE_DIR}/LICENSE)
if(WIN32)
    set(CPACK_GENERATOR NSIS)
    set(CPACK_PACKAGE_EXECUTABLES f1int f1int)        # Start menu shortcut
    set(CPACK_CREATE_DESKTOP_LINKS f1int)             # desktop shortcut
    set(CPACK_NSIS_INSTALLED_ICON_NAME bin\\f1int.exe)
    set(CPACK_NSIS_MUI_FINISHPAGE_RUN f1int.exe)      # "Run f1int" box on the last page
    set(CPACK_NSIS_ENABLE_UNINSTALL_BEFORE_INSTALL ON)
    set(CPACK_SYSTEM_NAME windows-x64)
elseif(APPLE)
    set(CPACK_GENERATOR DragNDrop)
    set(CPACK_SYSTEM_NAME macos-${CMAKE_OSX_ARCHITECTURES})   # macos-arm64 / macos-x86_64
endif()
include(CPack)

# ---- Unit tests: run with  .\build.ps1 -Test ----
enable_testing()
qt_add_executable(tst_urlinput tests/tst_urlinput.cpp src/UrlInput.cpp)
target_include_directories(tst_urlinput PRIVATE src)
target_link_libraries(tst_urlinput PRIVATE Qt6::Test)
add_test(NAME urlinput COMMAND tst_urlinput)

qt_add_executable(tst_tabmodel tests/tst_tabmodel.cpp src/TabModel.cpp src/TabModel.h)
target_include_directories(tst_tabmodel PRIVATE src)
target_link_libraries(tst_tabmodel PRIVATE Qt6::Test Qt6::Gui Qt6::Qml)   # Gui: QColor, Qml: registration macros
add_test(NAME tabmodel COMMAND tst_tabmodel)

qt_add_executable(tst_library tests/tst_library.cpp src/Library.cpp src/Library.h)
target_include_directories(tst_library PRIVATE src)
target_link_libraries(tst_library PRIVATE Qt6::Test Qt6::Sql Qt6::Qml)
add_test(NAME library COMMAND tst_library)

qt_add_executable(tst_vault tests/tst_vault.cpp)
target_link_libraries(tst_vault PRIVATE Qt6::Test vault)
add_test(NAME vault COMMAND tst_vault)

qt_add_executable(tst_adblocker tests/tst_adblocker.cpp src/AdBlocker.cpp src/AdBlocker.h)
target_include_directories(tst_adblocker PRIVATE src)
target_link_libraries(tst_adblocker PRIVATE Qt6::Test Qt6::WebEngineCore)
add_test(NAME adblocker COMMAND tst_adblocker)
