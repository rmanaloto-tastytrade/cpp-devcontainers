set(SOURCE_PATH ${CURRENT_PORT_DIR}/files)

file(INSTALL
    ${SOURCE_PATH}/include
    DESTINATION ${CURRENT_PACKAGES_DIR}
)

file(MAKE_DIRECTORY ${CURRENT_PACKAGES_DIR}/share/${PORT})
configure_file(
    ${CURRENT_PORT_DIR}/usage
    ${CURRENT_PACKAGES_DIR}/share/${PORT}/usage
    @ONLY
)
