#!/bin/bash
set -e

# setup_deps.sh
# Installs dependencies and fixes library links for compilation.

echo ">>> Step 1: Installing system dependencies (requires sudo)..."
if command -v apt-get &> /dev/null; then
    # Update package list
    sudo apt-get update || echo "Warning: apt-get update failed, trying to continue..."
    
    # Install required development packages
    # libjemalloc-dev is optional as silo bundles it, but good to have.
    sudo apt-get install -y build-essential libncurses5-dev libssl-dev libaio-dev zlib1g-dev || \
        echo "Warning: apt-get install failed. You might need to install these manually."
else
    echo "Skipping apt-get (not on Debian/Ubuntu or missing permissions)."
fi

echo ">>> Step 2: Setting up local library symlinks for the linker..."
# Determine the project root
PROJECT_ROOT=$(pwd)
LIBS_DIR="$PROJECT_ROOT/libs"

mkdir -p "$LIBS_DIR"
echo "Created $LIBS_DIR"

# Helper function to find a system library and link it locally
link_lib() {
    local target_name=$1  # e.g., libz.so
    local search_pattern=$2 # e.g., libz.so (for grep)

    echo "  Processing $target_name..."

    # 1. Try to find the path using ldconfig
    local path=$(ldconfig -p | grep "$search_pattern" | head -n 1 | awk '{print $NF}')

    # 2. If ldconfig fails, try finding in common lib paths
    if [ -z "$path" ]; then
        path=$(find /lib /usr/lib -name "$search_pattern*" -print -quit 2>/dev/null)
    fi

    if [ -n "$path" ]; then
        echo "    Found system library at: $path"
        if [ -L "$LIBS_DIR/$target_name" ] || [ -e "$LIBS_DIR/$target_name" ]; then
            echo "    Link already exists, refreshing..."
            rm "$LIBS_DIR/$target_name"
        fi
        ln -s "$path" "$LIBS_DIR/$target_name"
        echo "    Linked: libs/$target_name -> $path"
    else
        echo "    ERROR: Could not find system library matching '$search_pattern'. Compilation might fail."
    fi
}

# Create symlinks for libraries that often lack the unversioned .so in non-dev environments
link_lib "libz.so" "libz.so"
link_lib "libaio.so" "libaio.so"
link_lib "libssl.so" "libssl.so"
link_lib "libcrypto.so" "libcrypto.so"

echo ">>> Setup complete."
echo "You can now run 'make dbtest' (or 'make -j')."
