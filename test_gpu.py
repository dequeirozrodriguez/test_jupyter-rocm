#!/usr/bin/env python3
"""
ROCm Container - GPU Test Script
Usage: rocm-container-run python test_gpu.py
"""

import sys

def main():
    print("=" * 50)
    print("ROCm Container - GPU Test")
    print("=" * 50)

    try:
        import torch
        print(f"\n✓ PyTorch {torch.__version__}")
    except ImportError:
        print("\n✗ PyTorch not found")
        sys.exit(1)

    if not torch.cuda.is_available():
        print("✗ No GPU available")
        print("\nPossible issues:")
        print("  - /dev/kfd not mounted")
        print("  - /dev/dri not mounted")
        print("  - User not in 'video' group")
        sys.exit(1)

    print(f"✓ CUDA available (ROCm backend)")
    print(f"✓ Device count: {torch.cuda.device_count()}")

    print("\n" + "-" * 50)
    print("GPUs:")
    print("-" * 50)

    for i in range(torch.cuda.device_count()):
        props = torch.cuda.get_device_properties(i)
        print(f"\n  [{i}] {torch.cuda.get_device_name(i)}")
        print(f"      Memory: {props.total_memory / 1024**3:.1f} GB")
        print(f"      Compute: {props.major}.{props.minor}")

    print("\n" + "-" * 50)
    print("Quick test:")
    print("-" * 50)

    try:
        x = torch.randn(1000, 1000, device='cuda')
        y = torch.randn(1000, 1000, device='cuda')
        z = torch.matmul(x, y)
        torch.cuda.synchronize()
        print(f"\n  ✓ Matrix multiplication (1000x1000): OK")
        print(f"  ✓ Result sum: {z.sum().item():.2f}")
    except Exception as e:
        print(f"\n  ✗ Test failed: {e}")
        sys.exit(1)

    print("\n" + "=" * 50)
    print("All tests passed!")
    print("=" * 50)

if __name__ == "__main__":
    main()