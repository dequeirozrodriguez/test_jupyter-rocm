#!/bin/bash
# ============================================================
# ROCm Container - Setup

set -e

CONTAINER_DIR="$HOME/containers"
BIN_DIR="$HOME/bin"
CONTAINER_NAME="rocm.sif"
CONTAINER_PATH="$CONTAINER_DIR/$CONTAINER_NAME"

GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m'

echo -e "${GREEN}╔════════════════════════════════════════════════════════════╗${NC}"
echo -e "${GREEN}║              ROCm Container - Setup                        ║${NC}"
echo -e "${GREEN}╚════════════════════════════════════════════════════════════╝${NC}"
echo ""

create_directories() {
    echo -e "${YELLOW}[1/4] Creating directories...${NC}"

    mkdir -p "$CONTAINER_DIR"
    mkdir -p "$BIN_DIR"
    mkdir -p "$HOME/.cache/torch"
    mkdir -p "$HOME/.local/lib/python3.10/site-packages"
    mkdir -p "$HOME/.local/bin"

    echo -e "${GREEN}  ✓ Created: $CONTAINER_DIR${NC}"
    echo -e "${GREEN}  ✓ Created: $BIN_DIR${NC}"
    echo -e "${GREEN}  ✓ Created: ~/.local/lib/python3.10/site-packages (persistent packages)${NC}"
}

build_container() {
    echo -e "${YELLOW}[2/4] Building ROCm container...${NC}"

    if [ -f "$CONTAINER_PATH" ]; then
        echo -e "${GREEN}  ✓ Container already exists: $CONTAINER_PATH${NC}"
        read -p "  Rebuild? (y/N): " rebuild
        if [ "$rebuild" != "y" ] && [ "$rebuild" != "Y" ]; then
            return 0
        fi
    fi

    echo -e "  Pulling rocm/pytorch:rocm7.1.1_ubuntu22.04_py3.10_pytorch_release_2.9.1"
    echo -e "  ${YELLOW}This may take a while (~15-20GB)...${NC}"

    apptainer build "$CONTAINER_PATH" \
        docker://rocm/pytorch:rocm7.1.1_ubuntu22.04_py3.10_pytorch_release_2.9.1

    echo -e "${GREEN}  ✓ Container built: $CONTAINER_PATH${NC}"
}

create_scripts() {
    echo -e "${YELLOW}[3/4] Creating helper scripts...${NC}"

    # --- rocm-container ---
    cat > "$BIN_DIR/rocm-container" << 'SCRIPT'
#!/bin/bash
CONTAINER="${ROCM_CONTAINER:-$HOME/containers/rocm.sif}"
WORK_DIR="${1:-$PWD}"

if [ ! -f "$CONTAINER" ]; then
    echo "Error: Container not found: $CONTAINER"
    exit 1
fi

EXTRA_BINDS=""
[ -d "/dados" ] && EXTRA_BINDS="$EXTRA_BINDS --bind /dados:/dados"
[ -d "/scratch" ] && EXTRA_BINDS="$EXTRA_BINDS --bind /scratch:/scratch"
[ -d "/shared" ] && EXTRA_BINDS="$EXTRA_BINDS --bind /shared:/shared"

exec apptainer shell \
    --contain \
    --cleanenv \
    --bind /dev/kfd \
    --bind /dev/dri \
    --bind "$HOME:$HOME" \
    --bind /tmp:/tmp \
    $EXTRA_BINDS \
    --pwd "$WORK_DIR" \
    --env "TORCH_HOME=$HOME/.cache/torch" \
    --env "PYTHONPATH=$HOME/.local/lib/python3.10/site-packages" \
    --env "PS1=\[\033[1;31m\](rocm)\[\033[0m\] \[\033[1;34m\]\W\[\033[0m\] \$ " \
    "$CONTAINER"
SCRIPT
    chmod +x "$BIN_DIR/rocm-container"
    echo -e "${GREEN}  ✓ Created: $BIN_DIR/rocm-container${NC}"

    # --- rocm-container-run ---
    cat > "$BIN_DIR/rocm-container-run" << 'SCRIPT'
#!/bin/bash
CONTAINER="${ROCM_CONTAINER:-$HOME/containers/rocm.sif}"

if [ ! -f "$CONTAINER" ]; then
    echo "Error: Container not found: $CONTAINER"
    exit 1
fi

if [ $# -eq 0 ]; then
    echo "Usage: rocm-container-run <command> [args...]"
    exit 1
fi

EXTRA_BINDS=""
[ -d "/dados" ] && EXTRA_BINDS="$EXTRA_BINDS --bind /dados:/dados"
[ -d "/scratch" ] && EXTRA_BINDS="$EXTRA_BINDS --bind /scratch:/scratch"
[ -d "/shared" ] && EXTRA_BINDS="$EXTRA_BINDS --bind /shared:/shared"

exec apptainer exec \
    --contain \
    --cleanenv \
    --bind /dev/kfd \
    --bind /dev/dri \
    --bind "$HOME:$HOME" \
    --bind /tmp:/tmp \
    $EXTRA_BINDS \
    --pwd "$PWD" \
    --env "TORCH_HOME=$HOME/.cache/torch" \
    --env "PYTHONPATH=$HOME/.local/lib/python3.10/site-packages" \
    "$CONTAINER" \
    "$@"
SCRIPT
    chmod +x "$BIN_DIR/rocm-container-run"
    echo -e "${GREEN}  ✓ Created: $BIN_DIR/rocm-container-run${NC}"

    # --- rocm-container-pip ---
    cat > "$BIN_DIR/rocm-container-pip" << 'SCRIPT'
#!/bin/bash
PROTECTED="torch torchvision torchaudio"
BIN_DIR="$(dirname "$0")"
TARGET="$HOME/.local/lib/python3.10/site-packages"

# Check if trying to install protected packages directly
for pkg in $PROTECTED; do
    for arg in "$@"; do
        if [[ "$arg" == "$pkg" ]] || [[ "$arg" =~ ^${pkg}[\=\>\<\~\!] ]]; then
            echo "⚠️  ERROR: '$pkg' is protected (ROCm version installed in container)"
            echo ""
            echo "The container already has PyTorch with ROCm support."
            echo "Installing from PyPI would break GPU acceleration."
            echo ""
            echo "Current installation:"
            "$BIN_DIR/rocm-container-run" python -c "import torch; print(f'  torch=={torch.__version__}')" 2>/dev/null
            exit 1
        fi
    done
done

# For install commands
if [[ "$1" == "install" ]]; then
    # Run the install with --no-build-isolation so packages can see container's torch
    "$BIN_DIR/rocm-container-run" pip install \
        --target "$TARGET" \
        --no-build-isolation \
        --upgrade-strategy only-if-needed \
        "${@:2}"

    INSTALL_STATUS=$?

    # Check if any protected package got installed as dependency and remove it
    CLEANED=0
    for pkg in $PROTECTED; do
        PKG_DIR="$TARGET/$pkg"
        PKG_DIST=$(find "$TARGET" -maxdepth 1 -type d -name "${pkg}-*" 2>/dev/null | head -1)
        PKG_DIST_INFO=$(find "$TARGET" -maxdepth 1 -type d -name "${pkg}-*.dist-info" 2>/dev/null | head -1)

        if [ -d "$PKG_DIR" ]; then
            rm -rf "$PKG_DIR"
            CLEANED=1
        fi
        if [ -n "$PKG_DIST" ] && [ -d "$PKG_DIST" ]; then
            rm -rf "$PKG_DIST"
            CLEANED=1
        fi
        if [ -n "$PKG_DIST_INFO" ] && [ -d "$PKG_DIST_INFO" ]; then
            rm -rf "$PKG_DIST_INFO"
            CLEANED=1
        fi
    done

    # Also check for nvidia/triton that come with torch
    for pkg in nvidia triton; do
        for dir in "$TARGET"/${pkg}* "$TARGET"/${pkg}-*; do
            if [ -d "$dir" ]; then
                rm -rf "$dir"
                CLEANED=1
            fi
        done
    done

    if [ $CLEANED -eq 1 ]; then
        echo ""
        echo "⚠️  Removed PyTorch/CUDA packages that were pulled as dependencies."
        echo "   The container's ROCm version will be used instead."
    fi

    exit $INSTALL_STATUS
else
    # For non-install commands (list, show, etc), just pass through
    exec "$BIN_DIR/rocm-container-run" pip "$@"
fi
SCRIPT
    chmod +x "$BIN_DIR/rocm-container-pip"
    echo -e "${GREEN}  ✓ Created: $BIN_DIR/rocm-container-pip${NC}"
}

configure_path() {
    echo -e "${YELLOW}[4/4] Configuring PATH...${NC}"

    if [[ ":$PATH:" == *":$BIN_DIR:"* ]]; then
        echo -e "${GREEN}  ✓ $BIN_DIR already in PATH${NC}"
    else
        if ! grep -q "export PATH=\"\$HOME/bin:\$PATH\"" "$HOME/.bashrc"; then
            echo '' >> "$HOME/.bashrc"
            echo '# ROCm Container tools' >> "$HOME/.bashrc"
            echo 'export PATH="$HOME/bin:$PATH"' >> "$HOME/.bashrc"
            echo -e "${GREEN}  ✓ Added $BIN_DIR to PATH in .bashrc${NC}"
        fi
    fi
}

main() {
    create_directories
    build_container
    create_scripts
    configure_path

    echo ""
    echo -e "${GREEN}╔════════════════════════════════════════════════════════════╗${NC}"
    echo -e "${GREEN}║                    Setup Complete!                         ║${NC}"
    echo -e "${GREEN}╚════════════════════════════════════════════════════════════╝${NC}"
    echo ""
    echo -e "Commands:"
    echo -e "  ${GREEN}rocm-container${NC}        - Interactive shell"
    echo -e "  ${GREEN}rocm-container-run${NC}    - Run command"
    echo -e "  ${GREEN}rocm-container-pip${NC}    - Install packages"
    echo ""
    echo -e "Usage:"
    echo -e "  ${YELLOW}rocm-container${NC}                        # enter shell"
    echo -e "  ${YELLOW}rocm-container-run python train.py${NC}    # run script"
    echo -e "  ${YELLOW}rocm-container-pip install numpy${NC}"
    echo ""
}

if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
    main "$@"
fi