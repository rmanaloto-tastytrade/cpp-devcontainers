vcpkg_from_github(
    OUT_SOURCE_PATH SOURCE_PATH
    REPO boost-ext/ut
    REF v2.3.1
    SHA512 f95bdc9ba483f309bdcbe57d2fef92a0b4301bdb1c83700e711ac152c72a76b1d502a16462cca48074db024c0eb97920ffca7b3236f04c3bb40080c672c80f50
    HEAD_REF master
)

vcpkg_cmake_configure(
    SOURCE_PATH "${SOURCE_PATH}"
    OPTIONS
        -DBOOST_UT_BUILD_BENCHMARKS=OFF
        -DBOOST_UT_BUILD_EXAMPLES=OFF
        -DBOOST_UT_BUILD_TESTS=OFF
        -DBOOST_UT_ENABLE_INSTALL=ON
        -DBOOST_UT_DISABLE_MODULE=ON
)

vcpkg_cmake_install()

vcpkg_cmake_config_fixup(
    PACKAGE_NAME ut
    CONFIG_PATH lib/cmake/ut
)

file(REMOVE_RECURSE "${CURRENT_PACKAGES_DIR}/debug")

vcpkg_install_copyright(
    FILE_LIST "${SOURCE_PATH}/LICENSE"
)
