cmake_minimum_required(VERSION 3.20)
project(HORUS_demo LANGUAGES CXX)

# Set C++20 standard
set(CMAKE_CXX_STANDARD 20)
set(CMAKE_CXX_STANDARD_REQUIRED ON)
set(CMAKE_CXX_EXTENSIONS OFF)

# Global include directories
include_directories(${PROJECT_SOURCE_DIR}/include)

# Add subdirectories for each component (they may be empty placeholders for now)
add_subdirectory(cli)
add_subdirectory(api)
add_subdirectory(dashboard)
add_subdirectory(database)
add_subdirectory(licensing)
add_subdirectory(provisioning)
add_subdirectory(security)
add_subdirectory(systemd)
add_subdirectory(tools)

# Enable testing
enable_testing()
add_subdirectory(tests)
