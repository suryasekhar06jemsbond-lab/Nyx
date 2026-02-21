cmake_minimum_required(VERSION 3.20)
project(nyx_backends C)

set(CMAKE_C_STANDARD 11)
set(CMAKE_C_STANDARD_REQUIRED ON)

add_library(nyx_native_hooks_stub STATIC
    generated/nyx_native_hooks_stub.c
    src/nyx_backend_runtime.c
)

target_include_directories(nyx_native_hooks_stub
    PUBLIC
        ${CMAKE_CURRENT_SOURCE_DIR}/generated
        ${CMAKE_CURRENT_SOURCE_DIR}/src
)

if(MSVC)
    target_compile_options(nyx_native_hooks_stub PRIVATE /W4)
else()
    target_compile_options(nyx_native_hooks_stub PRIVATE -Wall -Wextra -Wpedantic)
endif()

# Future domain libraries (render/physics/ai/net/audio/logic) should be linked here.
# Example:
# add_subdirectory(src/render)
# target_link_libraries(nyx_native_hooks_stub PRIVATE nyx_backend_render)
