cmake_minimum_required(VERSION 3.20)

project(horus
    VERSION 1.0.0
    DESCRIPTION "BeoutOS - Network Security Daemon Suite"
    LANGUAGES CXX
)

set(CMAKE_CXX_STANDARD 20)
set(CMAKE_CXX_STANDARD_REQUIRED ON)
set(CMAKE_CXX_EXTENSIONS OFF)

set(BEOUTOS_VERSION_MAJOR ${PROJECT_VERSION_MAJOR})
set(BEOUTOS_VERSION_MINOR ${PROJECT_VERSION_MINOR})
set(BEOUTOS_VERSION_PATCH ${PROJECT_VERSION_PATCH})
set(BEOUTOS_VERSION "${PROJECT_VERSION}")

string(TIMESTAMP BEOUTOS_BUILD_DATE "%Y-%m-%d %H:%M:%S")

set(CMAKE_ARCHIVE_OUTPUT_DIRECTORY ${CMAKE_BINARY_DIR}/lib)
set(CMAKE_LIBRARY_OUTPUT_DIRECTORY ${CMAKE_BINARY_DIR}/lib)
set(CMAKE_RUNTIME_OUTPUT_DIRECTORY ${CMAKE_BINARY_DIR}/bin)

set(BEOUTOS_INSTALL_DIR "${PROJECT_SOURCE_DIR}/../live-build/config-includes.chroot/usr/bin")

set(CMAKE_INSTALL_RPATH "/usr/lib/horus")
set(CMAKE_INSTALL_RPATH_USE_LINK_PATH TRUE)
set(CMAKE_BUILD_WITH_INSTALL_RPATH FALSE)

set(CMAKE_CXX_FLAGS "-Wall -Wextra -Werror -march=native")
set(CMAKE_CXX_FLAGS_RELEASE "-O2 -DNDEBUG -D_FORTIFY_SOURCE=2")
set(CMAKE_CXX_FLAGS_DEBUG "-g -O0 -DDEBUG")
set(CMAKE_CXX_FLAGS_RELWITHDEBINFO "-g -O2")

set(CMAKE_EXE_LINKER_FLAGS "-Wl,-z,relro,-z,now -Wl,-z,noexecstack")
set(CMAKE_SHARED_LINKER_FLAGS "-Wl,-z,relro,-z,now -Wl,-z,noexecstack")

set(CMAKE_POSITION_INDEPENDENT_CODE ON)

set(STATIC_LINKING_PREFERENCE TRUE)

if(STATIC_LINKING_PREFERENCE)
    set(CMAKE_FIND_LIBRARY_SUFFIXES .a .so)
    set(LINK_SEARCH_START STATIC)
endif()

find_package(OpenSSL 3.0 REQUIRED)
find_package(SQLite3 REQUIRED)
find_package(Boost 1.74 REQUIRED COMPONENTS headers)
find_package(nlohmann_json 3.9 REQUIRED)
find_package(ZLIB REQUIRED)

find_package(CURL QUIET)
if(CURL_FOUND)
    add_definitions(-DBEOUTOS_HAS_CURL)
else()
    message(STATUS "libcurl not found - horus-activation will use raw socket fallback")
endif()

add_definitions(
    -DBEOUTOS_VERSION="${BEOUTOS_VERSION}"
    -DBEOUTOS_BUILD_DATE="${BEOUTOS_BUILD_DATE}"
    -DBEOUTOS_VERSION_MAJOR=${BEOUTOS_VERSION_MAJOR}
    -DBEOUTOS_VERSION_MINOR=${BEOUTOS_VERSION_MINOR}
    -DBEOUTOS_VERSION_PATCH=${BEOUTOS_VERSION_PATCH}
)

enable_testing()

add_subdirectory(common)
add_subdirectory(core/cli)
add_subdirectory(core/provisioning)
add_subdirectory(core/activation)
add_subdirectory(core/configdb)
add_subdirectory(core/overlay)
add_subdirectory(core/update)
