# Android native build for flux-ice: compiles the shared flux-ice wrapper +
# libjuice + the JNI glue into libflux_ice_jni.so (app ADR-0001/0002).
#
# Android is a bionic/Linux target, so — unlike the ESP-IDF controller — it uses
# the UNPATCHED libjuice and the BSD bridge variant (getifaddrs, getrandom, and
# BSD sockets are all present); no lwIP, no port patch.
cmake_minimum_required(VERSION 3.18)
project(flux_ice_jni C)

set(CMAKE_C_STANDARD 11)
set(CMAKE_C_STANDARD_REQUIRED ON)

# flux-interface submodule (repo root / flux-interface); five levels up from
# android/app/src/main/cpp.
get_filename_component(FI "${CMAKE_CURRENT_SOURCE_DIR}/../../../../../flux-interface/flux-ice" ABSOLUTE)

# libjuice options (must be set before add_subdirectory).
set(BUILD_SHARED_LIBS OFF CACHE BOOL "" FORCE)  # static-link the engine
set(NO_SERVER         ON  CACHE BOOL "" FORCE)  # client only
set(NO_TESTS          ON  CACHE BOOL "" FORCE)
set(USE_NETTLE        OFF CACHE BOOL "" FORCE)  # internal crypto (no nettle/openssl dep)
add_subdirectory(${FI}/third_party/libjuice ${CMAKE_BINARY_DIR}/libjuice)

add_library(flux_ice_jni SHARED
    flux_ice_jni.c
    ${FI}/core/flux_ice.c
    ${FI}/core/flux_ice_types.c
    ${FI}/udp/flux_ice_bridge_bsd.c
    ${FI}/mobile/flux_ice_mobile.c
)
target_include_directories(flux_ice_jni PRIVATE ${FI}/include)
# `log` = Android liblog (used by libjuice / diagnostics); JNI comes from the toolchain.
target_link_libraries(flux_ice_jni PRIVATE LibJuice::LibJuiceStatic log)
target_compile_options(flux_ice_jni PRIVATE -Wall -Wextra)
