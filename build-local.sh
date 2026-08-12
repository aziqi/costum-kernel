#!/bin/bash
set -e

echo "[1] Clone source..."
git clone --depth=1 --branch CAF https://github.com/thongass000/android_kernel_samsung_a9y18qlte kernel_a9

echo "[2] Setup Toolchain (Proton Clang)..."
if [ ! -d "toolchain" ]; then
    git clone --depth=1 https://github.com/kdrag0n/proton-clang toolchain
fi
export PATH="$(pwd)/toolchain/bin:$PATH"

echo "[3] Integrate KernelSU-Next (branch next)..."
cd kernel_a9
git clone --depth=1 --branch next https://github.com/KernelSU-Next/KernelSU-Next KernelSU-Next
cd drivers
ln -sf ../../KernelSU-Next/kernel kernelsu
cd ..
grep -q "kernelsu" drivers/Makefile || printf '\nobj-$(CONFIG_KSU) += kernelsu/\n' >> drivers/Makefile
grep -q 'source "drivers/kernelsu/Kconfig"' drivers/Kconfig || \
  sed -i '/^endmenu/i\source "drivers/kernelsu/Kconfig"' drivers/Kconfig

DEF=arch/arm64/configs/a9y18qlte_defconfig
sed -i 's/^CONFIG_HAVE_KPROBES=y/# CONFIG_HAVE_KPROBES is not set/' "$DEF"
grep -q '^# CONFIG_KPROBE_EVENTS is not set' "$DEF" || echo "# CONFIG_KPROBE_EVENTS is not set" >> "$DEF"
grep -q '^CONFIG_KSU=y' "$DEF" || echo "CONFIG_KSU=y" >> "$DEF"
grep -q '^CONFIG_KSU_MANUAL_HOOK=y' "$DEF" || echo "CONFIG_KSU_MANUAL_HOOK=y" >> "$DEF"
cd ..

echo "[4] Inject manual hooks..."
cd kernel_a9
python3 "../scripts/inject-ksu-hooks.py"
cd ..

echo "[5] Build kernel..."
cd kernel_a9
export ARCH=arm64
export SUBARCH=arm64
export CC=clang
export CROSS_COMPILE=aarch64-linux-gnu-
export CROSS_COMPILE_ARM32=arm-linux-gnueabi-
export CLANG_TRIPLE=aarch64-linux-gnu-
make O=out a9y18qlte_defconfig
make O=out -j$(nproc) 2>&1 | tee build.log
cd ..

echo "[6] Package AnyKernel3..."
if [ ! -f "thongass000-v4.4.205-stable.zip" ]; then
    echo "ERROR: thongass000-v4.4.205-stable.zip not found in current directory!"
    exit 1
fi
rm -rf ak3
mkdir ak3
unzip -q thongass000-v4.4.205-stable.zip -d ak3/
cp kernel_a9/out/arch/arm64/boot/Image.gz-dtb ak3/
sed -i 's/kernel.string=.*/kernel.string=KernelSU-Next @ a9y18qlte by @thongass000/g' ak3/anykernel.sh
cd ak3
zip -r9 ../a9y18qlte-KSUN.zip * -x .git
cd ..

echo "SUCCESS: a9y18qlte-KSUN.zip is ready!"
