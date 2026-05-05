cmake_minimum_required(VERSION 3.22.1)
project("three_skulls_engine" VERSION 1.0.0 LANGUAGES CXX)

set(CMAKE_CXX_STANDARD 17)
set(CMAKE_CXX_STANDARD_REQUIRED ON)

# ── Optimizaciones por ABI ────────────────────────────────────────
if(${ANDROID_ABI} STREQUAL "arm64-v8a")
    set(CMAKE_CXX_FLAGS "${CMAKE_CXX_FLAGS} -O3 -march=armv8-a -mfpu=neon")
elseif(${ANDROID_ABI} STREQUAL "armeabi-v7a")
    set(CMAKE_CXX_FLAGS "${CMAKE_CXX_FLAGS} -O2 -march=armv7-a -mfpu=neon")
endif()

# ── Fuentes del motor ─────────────────────────────────────────────
add_library(
    three_skulls_engine
    SHARED
    src/main/cpp/jni_bridge.cpp
    src/main/cpp/drawing_engine.cpp
    src/main/cpp/stroke_engine.cpp
    src/main/cpp/layer_manager.cpp
    src/main/cpp/brush_shader.cpp
    src/main/cpp/tskbrush_loader.cpp
)

# ── Librerías del sistema Android ────────────────────────────────
find_library(log-lib log)
find_library(android-lib android)
find_library(egl-lib EGL)
find_library(gles3-lib GLESv3)

target_link_libraries(
    three_skulls_engine
    ${log-lib}
    ${android-lib}
    ${egl-lib}
    ${gles3-lib}
)

# ── Include dirs ──────────────────────────────────────────────────
target_include_directories(
    three_skulls_engine
    PRIVATE
    src/main/cpp
)
