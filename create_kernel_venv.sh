#!/bin/bash
# =============================================================================
#===create_kernel_venv.sh
#
#creates a local Jupyter kernel WITH venv (isolated environment)
#no root needed!
#
#usage:
#  ./create_kernel_venv.sh -n <kernel-name> [-r <rocm-version>] [-f <requirements.txt>]
#
#examples:
#  ./create_kernel_venv.sh -n my-kernel
#  ./create_kernel_venv.sh -n my-kernel -r rocm6.3
#  ./create_kernel_venv.sh -n my-kernel -r rocm6.4 -f requirements.txt
#
# =============================================================================

set -e

#defaults
KERNEL_NAME=""
ROCM_VERSION="rocm6.4"
REQUIREMENTS_FILE=""

usage() {
    echo "Usage: $0 -n <kernel-name> [-r <rocm-version>] [-f <requirements.txt>]"
    echo ""
    echo "Options:"
    echo "  -n, --name        Kernel name (required)"
    echo "  -r, --rocm        ROCm version (default: rocm6.4)"
    echo "  -f, --file        requirements.txt file (optional)"
    echo "  -h, --help        Show this help"
    echo ""
    echo "Examples:"
    echo "  $0 -n rocm-ml"
    echo "  $0 -n gpu-env -r rocm6.3"
    echo "  $0 -n gpu-env -r rocm6.4 -f requirements.txt"
    exit 1
}

while [[ $# -gt 0 ]]; do
    case $1 in
        -n|--name)
            KERNEL_NAME="$2"
            shift 2
            ;;
        -r|--rocm)
            ROCM_VERSION="$2"
            shift 2
            ;;
        -f|--file)
            REQUIREMENTS_FILE="$2"
            shift 2
            ;;
        -h|--help)
            usage
            ;;
        *)
            echo "unknown option: $1"
            usage
            ;;
    esac
done

#validate only for kkkernel
if [ -z "$KERNEL_NAME" ]; then
    echo "Error: Kernel name is required (-n)"
    usage
fi

if [ -n "$REQUIREMENTS_FILE" ] && [ ! -f "$REQUIREMENTS_FILE" ]; then
    echo "Error: Requirements file not found: $REQUIREMENTS_FILE"
    exit 1
fi

VENV_PATH="$HOME/venvs/$KERNEL_NAME"
INDEX_URL="https://download.pytorch.org/whl/${ROCM_VERSION}"

echo "==================///============================"
echo "  Creating Jupyter kernel (with venv)"
echo "  Kernel: $KERNEL_NAME"
echo "  Venv:   $VENV_PATH"
echo "  ROCm:   $ROCM_VERSION"
[ -n "$REQUIREMENTS_FILE" ] && echo "  Reqs:   $REQUIREMENTS_FILE"
echo "==================///============================"

#create the venv
echo "[1/5] Creating virtual environment..."
mkdir -p "$HOME/venvs"
python3 -m venv "$VENV_PATH"
source "$VENV_PATH/bin/activate"

#upgradingg pip
echo "[2/5] Upgrading pip, wheel, setuptools and so on..."
pip install -U pip wheel setuptools

#innstalling from requirements.txt (filtering out torch)
if [ -n "$REQUIREMENTS_FILE" ]; then
    echo "[3/5] Installing from $REQUIREMENTS_FILE (excluding torch*)..."
    grep -v -E "^torch(vision|audio)?([^a-zA-Z]|$)" "$REQUIREMENTS_FILE" > /tmp/requirements_filtered.txt || true
    if [ -s /tmp/requirements_filtered.txt ]; then
        pip install -r /tmp/requirements_filtered.txt
    fi
    rm -f /tmp/requirements_filtered.txt
else
	echo "[3/5] No requirements.txt provided, skipping (if you havent passed any, it is no problem)..."
fi

#install PyTorch ROCm LAST (since overwrites any torch from dependencies)
echo "[4/5] Installing PyTorch ROCm (overwrites any existing torch)..."
pip install torch torchvision torchaudio --index-url "$INDEX_URL"

#register and ipykrernl for local installation;usage
echo "[5/5] Installing ipykernel and registering kernel..."
pip install ipykernel
python -m ipykernel install --user --name "$KERNEL_NAME" --display-name "Python (ROCm - $KERNEL_NAME)"

echo ""
echo "Done! In Jupyter, select: 'Python (ROCm - $KERNEL_NAME)'"
echo ""
echo "To activate in terminal: source $VENV_PATH/bin/activate"
echo ""
