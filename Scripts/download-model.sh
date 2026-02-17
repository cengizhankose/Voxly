#!/bin/bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
PROJECT_DIR="$(dirname "$SCRIPT_DIR")"
RESOURCES_DIR="$PROJECT_DIR/Resources"
MODEL_FILE="$RESOURCES_DIR/ggml-base.bin"
MODEL_URL="https://huggingface.co/ggerganov/whisper.cpp/resolve/main/ggml-base.bin"

if [ -f "$MODEL_FILE" ]; then
    echo "Model already exists at $MODEL_FILE"
    echo "Size: $(du -h "$MODEL_FILE" | cut -f1)"
    exit 0
fi

mkdir -p "$RESOURCES_DIR"

echo "=== Downloading whisper base model ==="
echo "URL: $MODEL_URL"
echo "Destination: $MODEL_FILE"
echo ""

curl -L --progress-bar -o "$MODEL_FILE" "$MODEL_URL"

echo ""
echo "=== Download complete ==="
echo "Size: $(du -h "$MODEL_FILE" | cut -f1)"
echo "Path: $MODEL_FILE"
