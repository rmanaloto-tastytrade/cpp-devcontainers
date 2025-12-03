# boost-decimal: Header-only C++14 IEEE 754 Decimal Floating Point library from C++ Alliance
# https://github.com/cppalliance/decimal

vcpkg_check_linkage(ONLY_HEADER_LIBRARY)

# Clone from GitHub
vcpkg_from_github(
    OUT_SOURCE_PATH SOURCE_PATH
    REPO cppalliance/decimal
    REF v5.2.0
    SHA512 631d438c906cb567c30629aad3daf97a336c0b532a16908249b09383e868ad51e8cca538680893a03d2a5c4fbcd153e52585dc5c1293e2db71579afb4cc94525
    HEAD_REF master
)

# Install the header files
file(INSTALL "${SOURCE_PATH}/include/"
    DESTINATION "${CURRENT_PACKAGES_DIR}/include"
    FILES_MATCHING PATTERN "*.hpp"
)

# Install license
file(INSTALL "${SOURCE_PATH}/LICENSE"
    DESTINATION "${CURRENT_PACKAGES_DIR}/share/${PORT}"
    RENAME copyright
)
