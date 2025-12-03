set(SOURCE_PATH ${CURRENT_PORT_DIR}/../../include)

file(INSTALL
    ${SOURCE_PATH}/slotmap
    DESTINATION ${CURRENT_PACKAGES_DIR}/include
)

file(MAKE_DIRECTORY ${CURRENT_PACKAGES_DIR}/share/${PORT})
configure_file(
    ${CURRENT_PORT_DIR}/usage
    ${CURRENT_PACKAGES_DIR}/share/${PORT}/usage
    COPYONLY
)

vcpkg_install_copyright(
    FILE_LIST ${CURRENT_PORT_DIR}/../../LICENSE
)
