set(COMMON_SRC
    src/logger.cpp
    src/util.cpp
    src/db.cpp
)

set(COMMON_HDR
    include/horus/logger.hpp
    include/horus/types.hpp
    include/horus/util.hpp
    include/horus/db.hpp
)

add_library(horus-common-static STATIC ${COMMON_SRC})
set_target_properties(horus-common-static PROPERTIES
    OUTPUT_NAME horus-common
    ARCHIVE_OUTPUT_DIRECTORY ${CMAKE_BINARY_DIR}/lib
)
target_include_directories(horus-common-static PUBLIC
    ${CMAKE_CURRENT_SOURCE_DIR}/include
    ${CMAKE_BINARY_DIR}
)
target_link_libraries(horus-common-static PUBLIC
    OpenSSL::SSL
    OpenSSL::Crypto
    SQLite::SQLite3
    ZLIB::ZLIB
)

add_library(horus-common-shared SHARED ${COMMON_SRC})
set_target_properties(horus-common-shared PROPERTIES
    OUTPUT_NAME horus-common
    LIBRARY_OUTPUT_DIRECTORY ${CMAKE_BINARY_DIR}/lib
    VERSION ${PROJECT_VERSION}
    SOVERSION ${PROJECT_VERSION_MAJOR}
)
target_include_directories(horus-common-shared PUBLIC
    ${CMAKE_CURRENT_SOURCE_DIR}/include
    ${CMAKE_BINARY_DIR}
)
target_link_libraries(horus-common-shared PUBLIC
    OpenSSL::SSL
    OpenSSL::Crypto
    SQLite::SQLite3
    ZLIB::ZLIB
)

install(TARGETS horus-common-static horus-common-shared
    ARCHIVE DESTINATION /usr/lib/horus
    LIBRARY DESTINATION /usr/lib/horus
)

install(FILES ${COMMON_HDR}
    DESTINATION /usr/include/horus
)

install(DIRECTORY include/horus
    DESTINATION /usr/include
)
