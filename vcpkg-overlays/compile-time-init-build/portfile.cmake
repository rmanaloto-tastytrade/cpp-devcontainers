vcpkg_from_github(
    OUT_SOURCE_PATH SOURCE_PATH
    REPO intel/compile-time-init-build
    REF 6617b0c316a3a966d887dcb5c9d5ebff7c6f5b7f
    SHA512 0b2c6a4ec5f9af33b949b83a5a1f67b66b80278927499b874a33c1f68cbc73b42be0bc41d0157e9be0eef993c4864e693d40640fc598829583a9c33b1dd7d184
    HEAD_REF main
)

# Header-only library - install the include directory
file(INSTALL "${SOURCE_PATH}/include/" DESTINATION "${CURRENT_PACKAGES_DIR}/include")

# Install Python tools for string catalog generation
file(INSTALL "${SOURCE_PATH}/tools/gen_str_catalog.py"
     DESTINATION "${CURRENT_PACKAGES_DIR}/tools"
     FILE_PERMISSIONS OWNER_READ OWNER_WRITE OWNER_EXECUTE GROUP_READ GROUP_EXECUTE WORLD_READ WORLD_EXECUTE)

file(INSTALL "${SOURCE_PATH}/tools/gen_str_catalog_test.py"
     DESTINATION "${CURRENT_PACKAGES_DIR}/tools")

file(INSTALL "${SOURCE_PATH}/tools/requirements.txt"
     DESTINATION "${CURRENT_PACKAGES_DIR}/tools")

# Install CMake modules for string catalog integration
file(INSTALL "${SOURCE_PATH}/cmake/string_catalog.cmake"
     DESTINATION "${CURRENT_PACKAGES_DIR}/share/${PORT}/cmake")

file(INSTALL "${SOURCE_PATH}/cmake/debug_flow.cmake"
     DESTINATION "${CURRENT_PACKAGES_DIR}/share/${PORT}/cmake")

# Create a CMake config file that consumers can use
file(WRITE "${CURRENT_PACKAGES_DIR}/share/${PORT}/compile-time-init-build-config.cmake" "
# compile-time-init-build CMake configuration
include(\${CMAKE_CURRENT_LIST_DIR}/cmake/string_catalog.cmake)
include(\${CMAKE_CURRENT_LIST_DIR}/cmake/debug_flow.cmake)

# Set path to Python tools
set(GEN_STR_CATALOG \${CMAKE_CURRENT_LIST_DIR}/../../tools/gen_str_catalog.py CACHE FILEPATH \"Location of string catalog generator\")
")

file(INSTALL "${SOURCE_PATH}/LICENSE" DESTINATION "${CURRENT_PACKAGES_DIR}/share/${PORT}" RENAME copyright)
vcpkg_install_copyright(FILE_LIST "${SOURCE_PATH}/LICENSE")
