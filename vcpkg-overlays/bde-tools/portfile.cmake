vcpkg_from_github(
    OUT_SOURCE_PATH SOURCE_PATH
    REPO bloomberg/bde-tools
    REF 350fe73f6364744c50a3b87ef4d008972239587d
    SHA512 24e85457b5618b4df2d584dee6dbb6340f8d707f8ebc1eb6c5bc19609501ef7e0c874b68b30aa9e585bf5cfb93ccb677b7d959118b615773a001e9505e424c15
    HEAD_REF main
)

vcpkg_cmake_configure(
    SOURCE_PATH "${SOURCE_PATH}"
)

vcpkg_cmake_install()

vcpkg_cmake_config_fixup(CONFIG_PATH lib/cmake/${PORT})

file(REMOVE_RECURSE "${CURRENT_PACKAGES_DIR}/debug/include")

vcpkg_install_copyright(FILE_LIST "${SOURCE_PATH}/LICENSE")
