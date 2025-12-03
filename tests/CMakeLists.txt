find_package(boost-ut CONFIG REQUIRED)

add_executable(slotmap_tests test_slotmap.cpp)
target_link_libraries(slotmap_tests PRIVATE slotmap boost::ut)
target_compile_features(slotmap_tests PRIVATE cxx_std_23)

add_test(NAME slotmap_tests COMMAND slotmap_tests)
