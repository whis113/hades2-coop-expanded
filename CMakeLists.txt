cmake_minimum_required(VERSION 3.20)

project(HadesCoop VERSION 0.1.1 LANGUAGES CXX)

set(CMAKE_CXX_STANDARD 20)
set(CMAKE_CXX_STANDARD_REQUIRED ON)

if(MSVC)
    set(CMAKE_MSVC_RUNTIME_LIBRARY "MultiThreaded$<$<CONFIG:Debug>:Debug>")
endif()

add_subdirectory(libs/EASTL-forge1.51)
add_subdirectory(libs/lua-5.2.2)
add_subdirectory(libs/hades2-engine-interface)

add_subdirectory(game)

set(HADES_MOD_INSTALL_PATH ${CMAKE_SOURCE_DIR}/bin/TN_CoopMod)

# Load environment variables from env.cmake
if (EXISTS ${CMAKE_SOURCE_DIR}/env.cmake)
    include(${CMAKE_SOURCE_DIR}/env.cmake)
endif()

install(TARGETS HadesCoopGame
        RUNTIME
        DESTINATION ${HADES_MOD_INSTALL_PATH}
)

install(DIRECTORY ${CMAKE_SOURCE_DIR}/game/scripts/
        DESTINATION ${HADES_MOD_INSTALL_PATH}
)

install(DIRECTORY ${CMAKE_SOURCE_DIR}/install/
        DESTINATION ${CMAKE_SOURCE_DIR}/bin
)
