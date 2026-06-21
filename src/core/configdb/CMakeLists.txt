set(CONFIGDB_SRC
    main.cpp
    config_store.cpp
    interface.cpp
    firewall_rule.cpp
    license_token.cpp
)

set(CONFIGDB_HDR
    config_store.hpp
    interface.hpp
    firewall_rule.hpp
    license_token.hpp
)

add_library(horus-configdb-lib STATIC
    config_store.cpp
    interface.cpp
    firewall_rule.cpp
    license_token.cpp
)

set_target_properties(horus-configdb-lib PROPERTIES
    OUTPUT_NAME horus-configdb-lib
    ARCHIVE_OUTPUT_DIRECTORY ${CMAKE_BINARY_DIR}/lib
)

target_include_directories(horus-configdb-lib PUBLIC
    ${CMAKE_CURRENT_SOURCE_DIR}
)

target_link_libraries(horus-configdb-lib PUBLIC
    horus-common-static
    SQLite::SQLite3
)

add_executable(horus-configdb ${CONFIGDB_SRC})

target_include_directories(horus-configdb PRIVATE
    ${CMAKE_CURRENT_SOURCE_DIR}
)

target_link_libraries(horus-configdb PRIVATE
    horus-configdb-lib
    horus-common-static
    SQLite::SQLite3
)

set_target_properties(horus-configdb PROPERTIES
    OUTPUT_NAME horus-configdb
    RUNTIME_OUTPUT_DIRECTORY ${CMAKE_BINARY_DIR}/bin
)

install(TARGETS horus-configdb horus-configdb-lib
    RUNTIME DESTINATION /usr/bin
    ARCHIVE DESTINATION /usr/lib/horus
)

install(FILES ${CONFIGDB_HDR}
    DESTINATION /usr/include/horus/core/configdb
)
