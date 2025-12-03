# boost-int128: Header-only C++ 128-bit integer library from C++ Alliance
# https://github.com/cppalliance/int128

vcpkg_check_linkage(ONLY_HEADER_LIBRARY)

# Clone from GitHub
vcpkg_from_github(
    OUT_SOURCE_PATH SOURCE_PATH
    REPO cppalliance/int128
    REF v1.3.0
    SHA512 ec08607f4782e16a8a5d7ea7ff8884418756d00f05209bd66451bea655139b34e4342953d555feded5302e8e425872ca1e15f9e3a266f39892e88ab820e70a03
    HEAD_REF master
)

# Install the header file
file(INSTALL "${SOURCE_PATH}/include/"
    DESTINATION "${CURRENT_PACKAGES_DIR}/include"
    FILES_MATCHING PATTERN "*.hpp"
)

# Install license
file(INSTALL "${SOURCE_PATH}/LICENSE"
    DESTINATION "${CURRENT_PACKAGES_DIR}/share/${PORT}"
    RENAME copyright
)
