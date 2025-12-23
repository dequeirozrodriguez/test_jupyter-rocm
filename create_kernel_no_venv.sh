#!/bin/bash
#=============================================================================
#===create_kernel_no_venv.sh
#
#it creates a local Jupyter kernel WITHOUT venv (uses pip --user)
#no root needed! You might take a look at the readme.md
#
#usage:
#  ./create_kernel_no_venv.sh -n <kernel-name> [-r <rocm-version>] [-f <requirements.txt>]
#
#examples:
#  ./create_kernel_no_venv.sh -n my-kernel
#  ./create_kernel_no_venv.sh -n my-kernel -r rocm6.3
#  ./create_kernel_no_venv.sh -n my-kernel -r rocm6.4 -f requirements.txt
#===
#=============================================================================

set -e

#ddefaults
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

#validate only for kkernel
if [ -z "$KERNEL_NAME" ]; then
    echo "Error: Kernel name is required (-n)"
    usage
fi

if [ -n "$REQUIREMENTS_FILE" ] && [ ! -f "$REQUIREMENTS_FILE" ]; then
    echo "Error: Requirements file not found: $REQUIREMENTS_FILE"
    exit 1
fi

INDEX_URL="https://download.pytorch.org/whl/${ROCM_VERSION}"

echo "=====================///========================="
echo "  Creating Jupyter kernel (no venv)"
echo "  Kernel: $KERNEL_NAME"
echo "  ROCm:   $ROCM_VERSION"
[ -n "$REQUIREMENTS_FILE" ] && echo "  Reqs:   $REQUIREMENTS_FILE"
echo "=====================///========================="

#upgrading pip but it may be unnecessary so the user can take it off if they really want to take it off
echo "[1/4] Upgrading pip, wheel, setuptools and so on..."
pip install --user -U pip wheel setuptools

#installionmg from requirements.txt given (filtering out torch)
if [ -n "$REQUIREMENTS_FILE" ]; then
    echo "[2/4] Installing from $REQUIREMENTS_FILE (excluding torch*)..."
    grep -v -E "^torch(vision|audio)?([^a-zA-Z]|$)" "$REQUIREMENTS_FILE" > /tmp/requirements_filtered.txt || true
    if [ -s /tmp/requirements_filtered.txt ]; then
        pip install --user -r /tmp/requirements_filtered.txt
    fi
    rm -f /tmp/requirements_filtered.txt
else
	echo "[2/4] No requirements.txt provided, skipping (this is not a problem if you havent passed any)..."
fi

#installing PyTorch ROCm LAST (overwrites any torch from dependencies)
echo "[3/4] Installing PyTorch ROCm (overwrites any existing torch)..."
pip install --user torch torchvision torchaudio --index-url "$INDEX_URL"

#register adn ipykernel, they are neccesary for the local ekrnel
echo "[4/4] Installing ipykernel and registering kernel..."
pip install --user ipykernel
python -m ipykernel install --user --name "$KERNEL_NAME" --display-name "Python (ROCm - $KERNEL_NAME)"

echo ""
echo "Done! In Jupyter, select: 'Python (ROCm - $KERNEL_NAME)'"
echo ""
