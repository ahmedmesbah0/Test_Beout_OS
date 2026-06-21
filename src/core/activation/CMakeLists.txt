set(ACT_SRC
    main.cpp
    activation.cpp
    license.cpp
    crypto.cpp
    network.cpp
)

set(ACT_HDR
    activation.hpp
    license.hpp
    crypto.hpp
    network.hpp
)

add_executable(horus-activation ${ACT_SRC})

target_include_directories(horus-activation PRIVATE
    ${CMAKE_CURRENT_SOURCE_DIR}
)

target_link_libraries(horus-activation PRIVATE
    horus-common-static
    OpenSSL::SSL
    OpenSSL::Crypto
    SQLite::SQLite3
)

if(CURL_FOUND)
    target_link_libraries(horus-activation PRIVATE CURL::libcurl)
    target_compile_definitions(horus-activation PRIVATE BEOUTOS_HAS_CURL)
endif()

set_target_properties(horus-activation PROPERTIES
    OUTPUT_NAME horus-activation
    RUNTIME_OUTPUT_DIRECTORY ${CMAKE_BINARY_DIR}/bin
)

install(TARGETS horus-activation
    RUNTIME DESTINATION /usr/bin
)

install(FILES ${ACT_HDR}
    DESTINATION /usr/include/horus/core/activation
)
