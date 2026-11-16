# CMake is the build recipe: it tells the compiler which files make up f1int
# and which Qt libraries to link against.
cmake_minimum_required(VERSION 3.21)
project(f1int VERSION 0.1.0 LANGUAGES CXX)

set(CMAKE_CXX_STANDARD 17)
set(CMAKE_CXX_STANDARD_REQUIRED ON)

# Qt WebEngine is Chromium. "Test" is only used by the unit tests in tests/.
find_package(Qt6 6.8 REQUIRED COMPONENTS Quick WebEngineQuick Test)
qt_standard_project_setup(REQUIRES 6.8)   # turns on Qt's code generators (moc etc.)

# WIN32 = no black console window on Windows. MACOSX_BUNDLE = build an .app on Mac.
qt_add_executable(f1int WIN32 MACOSX_BUNDLE
    src/main.cpp
    src/Browser.h src/Browser.cpp
    src/UrlInput.h src/UrlInput.cpp
)

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
)

# Dynamic linking (the default) keeps us within Qt's LGPL licence.
target_link_libraries(f1int PRIVATE Qt6::Quick Qt6::WebEngineQuick)

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
