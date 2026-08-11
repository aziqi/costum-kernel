#!/bin/bash
set -e

echo "[1] Clone source..."
git clone --depth=1 --branch CAF https://github.com/thongass000/android_kernel_samsung_a9y18qlte kernel_a9

echo "[2] Setup Toolchain (Proton Clang)..."
if [ ! -d "toolchain" ]; then
    git clone --depth=1 https://github.com/kdrag0n/proton-clang toolchain
fi
export PATH="$(pwd)/toolchain/bin:$PATH"

echo "[3] Integrate KernelSU-Next..."
cd kernel_a9
curl -LSs "https://raw.githubusercontent.com/mlm-games/KernelSU-Non-GKI/main/kernel/setup-subm.sh" | bash -s
python3 KernelSU/scripts/integrate-no-kprobe.py arch/arm64/configs/a9y18qlte_defconfig

echo "[4] Patch defconfig..."
sed -i 's/CONFIG_HAVE_KPROBES=y/# CONFIG_HAVE_KPROBES is not set/g' arch/arm64/configs/a9y18qlte_defconfig
echo "# CONFIG_KPROBE_EVENTS is not set" >> arch/arm64/configs/a9y18qlte_defconfig
echo "CONFIG_KSU=y" >> arch/arm64/configs/a9y18qlte_defconfig
echo "CONFIG_KSU_MANUAL_HOOK=y" >> arch/arm64/configs/a9y18qlte_defconfig

echo "[5] Build kernel..."
export ARCH=arm64
export SUBARCH=arm64
export CC=clang
export CROSS_COMPILE=aarch64-linux-gnu-
export CROSS_COMPILE_ARM32=arm-linux-gnueabi-
export CLANG_TRIPLE=aarch64-linux-gnu-

make O=out a9y18qlte_defconfig
make O=out -j$(nproc) 2>&1 | tee build.log

echo "[6] Package AnyKernel3..."
cd ..
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

echo "✅ SUCCESS: a9y18qlte-KSUN.zip is ready!"
