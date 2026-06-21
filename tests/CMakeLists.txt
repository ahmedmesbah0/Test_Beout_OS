enable_testing()

find_package(GTest REQUIRED)
include_directories(${GTEST_INCLUDE_DIRS})

add_executable(runTests example_test.cpp)

target_link_libraries(runTests GTest::GTest GTest::Main)

add_test(NAME placeholder_test COMMAND runTests)
