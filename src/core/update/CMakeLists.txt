set(UPDATE_SRC
    main.cpp
    update_manager.cpp
    signature.cpp
    ab_partition.cpp
)

set(UPDATE_HDR
    update_manager.hpp
    signature.hpp
    ab_partition.hpp
)

add_executable(horus-update ${UPDATE_SRC})

target_include_directories(horus-update PRIVATE
    ${CMAKE_CURRENT_SOURCE_DIR}
)

target_link_libraries(horus-update PRIVATE
    horus-common-static
    OpenSSL::SSL
    OpenSSL::Crypto
)

set_target_properties(horus-update PROPERTIES
    OUTPUT_NAME horus-update
    RUNTIME_OUTPUT_DIRECTORY ${CMAKE_BINARY_DIR}/bin
)

install(TARGETS horus-update
    RUNTIME DESTINATION /usr/bin
)

install(FILES ${UPDATE_HDR}
    DESTINATION /usr/include/horus/core/update
)
