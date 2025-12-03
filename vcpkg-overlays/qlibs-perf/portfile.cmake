# qlibs-perf: Header-only C++2x performance library
# Install from local source directory

vcpkg_check_linkage(ONLY_HEADER_LIBRARY)

# Source location relative to project root
set(SOURCE_PATH "${CMAKE_CURRENT_LIST_DIR}/../../external/qlibs-perf-src")

# Verify source exists
if(NOT EXISTS "${SOURCE_PATH}/perf")
    message(FATAL_ERROR "qlibs-perf source not found at ${SOURCE_PATH}")
endif()

# Install the header file
file(INSTALL "${SOURCE_PATH}/perf"
    DESTINATION "${CURRENT_PACKAGES_DIR}/include"
)

# Install the C++20 module file if needed
if(EXISTS "${SOURCE_PATH}/perf.cppm")
    file(INSTALL "${SOURCE_PATH}/perf.cppm"
        DESTINATION "${CURRENT_PACKAGES_DIR}/include"
    )
endif()

# Install license/copyright
# qlibs uses header-embedded license, create a basic copyright file
file(WRITE "${CURRENT_PACKAGES_DIR}/share/${PORT}/copyright"
    "qlibs/perf - C++2x performance library\n"
    "Licensed under MIT License\n"
    "Copyright (c) qlibs contributors\n"
    "https://github.com/qlibs/perf\n"
)

# Mark as header-only
set(VCPKG_POLICY_EMPTY_PACKAGE enabled)
