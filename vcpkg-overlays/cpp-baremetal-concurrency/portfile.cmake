vcpkg_from_github(
    OUT_SOURCE_PATH SOURCE_PATH
    REPO intel/cpp-baremetal-concurrency
    REF 9fd9625e9aca6a84f2cd1159e717ddc0eca66346
    SHA512 9a6d68f18fe4cda7a29aa54a842b5db98b534b5803b299693772cdad67240f03fcc60cf2ff559b620bccfecb20c493baab5e1981c9eae4b17c74039d97fe4f26
    HEAD_REF main
)

# Header-only library - just install the include directory
file(INSTALL "${SOURCE_PATH}/include/" DESTINATION "${CURRENT_PACKAGES_DIR}/include")

file(INSTALL "${SOURCE_PATH}/LICENSE" DESTINATION "${CURRENT_PACKAGES_DIR}/share/${PORT}" RENAME copyright)
vcpkg_install_copyright(FILE_LIST "${SOURCE_PATH}/LICENSE")
