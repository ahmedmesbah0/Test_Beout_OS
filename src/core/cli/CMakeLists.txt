set(CLI_SRC
    main.cpp
    cli.cpp
    command.cpp
    parser.cpp
    session.cpp
)

set(CLI_HDR
    cli.hpp
    command.hpp
    parser.hpp
    session.hpp
)

add_executable(horus-cli ${CLI_SRC})

target_include_directories(horus-cli PRIVATE
    ${CMAKE_CURRENT_SOURCE_DIR}
)

target_link_libraries(horus-cli PRIVATE
    horus-common-static
    OpenSSL::SSL
    OpenSSL::Crypto
    SQLite::SQLite3
)

set_target_properties(horus-cli PROPERTIES
    OUTPUT_NAME horus-cli
    RUNTIME_OUTPUT_DIRECTORY ${CMAKE_BINARY_DIR}/bin
)

install(TARGETS horus-cli
    RUNTIME DESTINATION /usr/bin
)

install(FILES ${CLI_HDR}
    DESTINATION /usr/include/horus/core/cli
)

install(CODE "execute_process(COMMAND ${CMAKE_COMMAND} -E copy_if_different
    ${BEOUTOS_INSTALL_DIR}/horus-cli
    ${CMAKE_INSTALL_PREFIX}/usr/bin/horus-cli
)")
