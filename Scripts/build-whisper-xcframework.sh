#!/bin/bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
PROJECT_DIR="$(dirname "$SCRIPT_DIR")"
BUILD_DIR="$PROJECT_DIR/.build-whisper"
FRAMEWORK_DIR="$PROJECT_DIR/Frameworks"
WHISPER_TAG="v1.8.1"

echo "=== Building whisper.cpp XCFramework (arm64 only) ==="

if [ -d "$FRAMEWORK_DIR/whisper.xcframework" ]; then
    echo "whisper.xcframework already exists. Delete it to rebuild."
    exit 0
fi

if ! command -v cmake &> /dev/null; then
    echo "Error: cmake not found. Install with: brew install cmake"
    exit 1
fi

rm -rf "$BUILD_DIR"
mkdir -p "$BUILD_DIR"
cd "$BUILD_DIR"

# Clone whisper.cpp
echo "=== Cloning whisper.cpp $WHISPER_TAG ==="
git clone --depth 1 --branch "$WHISPER_TAG" https://github.com/ggerganov/whisper.cpp.git
cd whisper.cpp

# Build for macOS arm64 only
echo "=== Building for macOS arm64 ==="
cmake -B build \
    -DCMAKE_OSX_ARCHITECTURES="arm64" \
    -DCMAKE_OSX_DEPLOYMENT_TARGET="13.0" \
    -DBUILD_SHARED_LIBS=OFF \
    -DWHISPER_BUILD_TESTS=OFF \
    -DWHISPER_BUILD_EXAMPLES=OFF \
    -DGGML_METAL=ON \
    -DGGML_ACCELERATE=ON \
    -DCMAKE_BUILD_TYPE=Release
cmake --build build --config Release -j$(sysctl -n hw.ncpu)

# Prepare headers and merged library
echo "=== Preparing library ==="
mkdir -p output/lib output/include

cp include/whisper.h output/include/
# Copy all ggml public headers — whisper.h transitively includes ggml-cpu.h, ggml-backend.h, etc.
cp ggml/include/*.h output/include/

# Find all static libs and merge into one.
# Use `libtool -static` (not `ar x` + `ar rcs`) so duplicate .o filenames across libs
# (e.g. ggml-cpu/quants.c.o vs ggml-cpu/arch/arm/quants.c.o) don't clobber each other.
LIB_LIST=()
while IFS= read -r lib; do
    LIB_LIST+=("$lib")
done < <(find "$PWD/build" -name "*.a" -not -path "*/CMakeFiles/*" | sort)
echo "Libraries found:"
printf '  %s\n' "${LIB_LIST[@]}"

libtool -static -o output/lib/libwhisper.a "${LIB_LIST[@]}"

# Create XCFramework
echo "=== Creating XCFramework ==="
mkdir -p "$FRAMEWORK_DIR"
xcodebuild -create-xcframework \
    -library output/lib/libwhisper.a \
    -headers output/include \
    -output "$FRAMEWORK_DIR/whisper.xcframework"

# Copy Metal shader if present
METAL_LIB=$(find build -name "*.metallib" 2>/dev/null | head -1)
if [ -n "$METAL_LIB" ]; then
    echo "=== Copying Metal library ==="
    mkdir -p "$PROJECT_DIR/Resources"
    find build -name "*.metallib" -exec cp {} "$PROJECT_DIR/Resources/" \;
fi

# Cleanup
rm -rf "$BUILD_DIR"

echo "=== Done! ==="
ls -la "$FRAMEWORK_DIR/whisper.xcframework/"
