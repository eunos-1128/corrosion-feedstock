#!/bin/bash

set -exo pipefail

if [[ ${build_platform} != ${target_platform} ]]; then
    case ${target_platform} in
        linux-aarch64)
            cargo_target_args="-DRust_CARGO_TARGET=aarch64-unknown-linux-gnu"
            ;;
        linux-ppc64le)
            cargo_target_args="-DRust_CARGO_TARGET=powerpc64le-unknown-linux-gnu"
            ;;
        osx-arm64)
            cargo_target_args="-DRust_CARGO_TARGET=aarch64-apple-darwin"
            ;;
        *)
            echo "Unsupported cross-compilation target: ${target_platform}"
            exit 1
            ;;
    esac
fi

if [[ "${target_platform}" == "linux-"* ]]; then
    ln -s "${CC}" "${BUILD_PREFIX}/bin/cc"
    ln -s "${CXX}" "${BUILD_PREFIX}/bin/c++"
fi

# Use `lib` instead of `lib64` for tests
sed -i.bak '/include(GNUInstallDirs)/a\
set(CMAKE_INSTALL_LIBDIR lib CACHE STRING "" FORCE)
' cmake/Corrosion.cmake

cmake -S . -B build \
    ${CMAKE_ARGS} \
    -DCMAKE_CXX_FLAGS="${CXXFLAGS} -pthread" \
    -DCMAKE_EXE_LINKER_FLAGS="${CMAKE_EXE_LINKER_FLAGS} -pthread" \
    -DCORROSION_BUILD_TESTS=ON \
    ${cargo_target_args}

cmake --build build --parallel ${CPU_COUNT}

# Skipping tests in case of cross-compiling without emulator
if [[ "${CONDA_BUILD_CROSS_COMPILATION:-}" != "1" || "${CROSSCOMPILING_EMULATOR:-}" != "" ]]; then
    ctest -V --test-dir build --parallel ${CPU_COUNT}
fi

cmake --install build
