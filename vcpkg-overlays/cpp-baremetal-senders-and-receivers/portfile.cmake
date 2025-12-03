vcpkg_from_github(
    OUT_SOURCE_PATH SOURCE_PATH
    REPO intel/cpp-baremetal-senders-and-receivers
    REF b5c24aa5b69f4400969e699219d99900a2534e67
    SHA512 c4a7a0395255a03ad49353e72a6d1128e739ea0e279acf95c34707962a71cee88e858d8a4e91d41492e231996325a5cac8cb2e0858b78af18702f71391c3b2e8
    HEAD_REF main
)

# Header-only library - just install the include directory
file(INSTALL "${SOURCE_PATH}/include/" DESTINATION "${CURRENT_PACKAGES_DIR}/include")

file(INSTALL "${SOURCE_PATH}/LICENSE" DESTINATION "${CURRENT_PACKAGES_DIR}/share/${PORT}" RENAME copyright)
vcpkg_install_copyright(FILE_LIST "${SOURCE_PATH}/LICENSE")
