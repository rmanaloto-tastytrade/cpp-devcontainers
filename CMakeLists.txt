cmake_minimum_required(VERSION 3.28)

project(
    SlotMap
    VERSION 0.1.0
    LANGUAGES CXX
)

set(CMAKE_EXPORT_COMPILE_COMMANDS ON)

option(SLOTMAP_BUILD_TESTS "Build SlotMap unit tests" ON)
option(SLOTMAP_BUILD_DOCS "Enable documentation targets" ON)
option(SLOTMAP_ENABLE_WARNINGS_AS_ERRORS "Treat warnings as errors" ON)

set(CMAKE_C_STANDARD 23)
set(CMAKE_C_STANDARD_REQUIRED ON)
set(CMAKE_C_EXTENSIONS OFF)

set(CMAKE_CXX_STANDARD 26)
set(CMAKE_CXX_STANDARD_REQUIRED ON)
set(CMAKE_CXX_EXTENSIONS OFF)

add_library(slotmap INTERFACE)
target_include_directories(
    slotmap
    INTERFACE
        $<BUILD_INTERFACE:${CMAKE_CURRENT_SOURCE_DIR}/include>
        $<INSTALL_INTERFACE:include>
)
target_compile_features(slotmap INTERFACE cxx_std_23)

set(common_warnings
    -Wall
    -Wextra
    -Wshadow
    -Wconversion
    -Wpedantic
    -Wnon-virtual-dtor
    -Wold-style-cast
    -Woverloaded-virtual
    -Wnull-dereference
    -Wdouble-promotion
    -Wformat=2
)

if(CMAKE_CXX_COMPILER_ID STREQUAL "Clang" OR CMAKE_CXX_COMPILER_ID STREQUAL "GNU")
    target_compile_options(slotmap INTERFACE ${common_warnings})
    if(SLOTMAP_ENABLE_WARNINGS_AS_ERRORS)
        target_compile_options(slotmap INTERFACE -Werror)
    endif()
elseif(MSVC)
    target_compile_options(slotmap INTERFACE /W4)
    if(SLOTMAP_ENABLE_WARNINGS_AS_ERRORS)
        target_compile_options(slotmap INTERFACE /WX)
    endif()
endif()

target_compile_definitions(
    slotmap
    INTERFACE
        $<$<CONFIG:Debug>:SLOTMAP_DEBUG=1>
)

if(SLOTMAP_BUILD_TESTS)
    enable_testing()
    add_subdirectory(tests)
endif()

if(SLOTMAP_BUILD_DOCS)
    find_program(MRDOCS_EXECUTABLE NAMES mrdocs REQUIRED)
    find_program(DOXYGEN_EXECUTABLE NAMES doxygen REQUIRED)

    add_custom_target(
        docs
        COMMAND ${CMAKE_CURRENT_SOURCE_DIR}/scripts/generate_docs.sh
            --source ${CMAKE_CURRENT_SOURCE_DIR}
            --build ${CMAKE_BINARY_DIR}/docs
            --mrdocs ${MRDOCS_EXECUTABLE}
            --doxygen ${DOXYGEN_EXECUTABLE}
        WORKING_DIRECTORY ${CMAKE_CURRENT_SOURCE_DIR}
        COMMENT "Generating SlotMap reference documentation"
        VERBATIM
    )
endif()
