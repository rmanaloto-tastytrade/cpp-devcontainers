vcpkg_from_github(
    OUT_SOURCE_PATH SOURCE_PATH
    REPO intel/cpp-std-extensions
    REF 954a2fafa0ad81d06274197a5130126711110344
    SHA512 70db5311c743250d051dcc06904d202350a5356c3365dc05f6d66854b026cca901c85d0f5ac1970b3b6e6d265d4cb05927c90fa3a9713fc4ccef665db1e23cf2
    HEAD_REF main
)

# Header-only library - just install the include directory
file(INSTALL "${SOURCE_PATH}/include/" DESTINATION "${CURRENT_PACKAGES_DIR}/include")

file(INSTALL "${SOURCE_PATH}/LICENSE" DESTINATION "${CURRENT_PACKAGES_DIR}/share/${PORT}" RENAME copyright)
vcpkg_install_copyright(FILE_LIST "${SOURCE_PATH}/LICENSE")
