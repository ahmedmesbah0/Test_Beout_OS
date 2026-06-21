set(OVERLAY_SRC
    main.cpp
    overlay_manager.cpp
)

set(OVERLAY_HDR
    overlay_manager.hpp
)

add_executable(horus-overlay ${OVERLAY_SRC})

target_include_directories(horus-overlay PRIVATE
    ${CMAKE_CURRENT_SOURCE_DIR}
)

target_link_libraries(horus-overlay PRIVATE
    horus-common-static
)

set_target_properties(horus-overlay PROPERTIES
    OUTPUT_NAME horus-overlay
    RUNTIME_OUTPUT_DIRECTORY ${CMAKE_BINARY_DIR}/bin
)

install(TARGETS horus-overlay
    RUNTIME DESTINATION /usr/bin
)

install(FILES ${OVERLAY_HDR}
    DESTINATION /usr/include/horus/core/overlay
)
