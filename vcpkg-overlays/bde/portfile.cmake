vcpkg_from_github(
    OUT_SOURCE_PATH SOURCE_PATH
    REPO bloomberg/rmqcpp
    REF b1a4c6c4a73dbcf4848973022c398afe924b58b5
    SHA512 685664f07dbc17ba4c2ced2ae3286b60a992d36c6a2d0a749616bd2c4df19adf6d55183eace48fd489c0d0641ee35aee34f45449b54105909d35534436f10f56
    HEAD_REF main
    PATCHES
      "disable-tests-and-examples.patch"
      new-boost.patch # From https://github.com/bloomberg/rmqcpp/pull/59
)

vcpkg_cmake_configure(
  SOURCE_PATH "${SOURCE_PATH}"
  OPTIONS
    -DBDE_BUILD_TARGET_CPP17=ON
    -DCMAKE_CXX_STANDARD=17
    -DCMAKE_CXX_STANDARD_REQUIRED=ON
    -DBDE_BUILD_TARGET_SAFE=ON
    -DCMAKE_INSTALL_LIBDIR=lib64
)

vcpkg_cmake_build()

vcpkg_cmake_install()

vcpkg_install_copyright(FILE_LIST "${SOURCE_PATH}/LICENSE")
configure_file("${CMAKE_CURRENT_LIST_DIR}/usage" "${CURRENT_PACKAGES_DIR}/share/${PORT}/usage" COPYONLY)

vcpkg_cmake_config_fixup()

file(REMOVE_RECURSE "${CURRENT_PACKAGES_DIR}/debug/include")
file(REMOVE_RECURSE "${CURRENT_PACKAGES_DIR}/debug/share")
