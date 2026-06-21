set(PROV_SRC
    main.cpp
    provisioning.cpp
    menu.cpp
    interface_config.cpp
)

set(PROV_HDR
    provisioning.hpp
    menu.hpp
    interface_config.hpp
)

add_executable(horus-provisioning ${PROV_SRC})

target_include_directories(horus-provisioning PRIVATE
    ${CMAKE_CURRENT_SOURCE_DIR}
)

target_link_libraries(horus-provisioning PRIVATE
    horus-common-static
    OpenSSL::SSL
    OpenSSL::Crypto
    SQLite::SQLite3
)

set_target_properties(horus-provisioning PROPERTIES
    OUTPUT_NAME horus-provisioning
    RUNTIME_OUTPUT_DIRECTORY ${CMAKE_BINARY_DIR}/bin
)

install(TARGETS horus-provisioning
    RUNTIME DESTINATION /usr/bin
)

install(FILES ${PROV_HDR}
    DESTINATION /usr/include/horus/core/provisioning
)
