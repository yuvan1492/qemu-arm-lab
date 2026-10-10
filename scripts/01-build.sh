#!/usr/bin/env bash
set -euo pipefail

ROOT=$(cd "$(dirname "$0")/.." && pwd)
BUILD="$ROOT/build"
CROSS_COMPILE=arm-linux-gnueabihf-
JOBS=$(nproc)
UBOOT_VERSION=${UBOOT_VERSION:-v2026.10}
LINUX_VERSION=${LINUX_VERSION:-v6.11}

ensure_gnu_install() {
	if [[ -x /usr/bin/gnuinstall ]]; then
		sudo update-alternatives --install /usr/bin/install install /usr/bin/gnuinstall 100 >/dev/null 2>&1 || true
		sudo update-alternatives --set install /usr/bin/gnuinstall >/dev/null 2>&1 || true
		hash -r
	fi
}

ensure_gnu_install
mkdir -p "$BUILD"

UBOOT_SRC="$BUILD/u-boot-src"
if [[ ! -d "$UBOOT_SRC" ]]; then
	git clone --depth 1 --branch "$UBOOT_VERSION" \
		https://github.com/u-boot/u-boot.git "$UBOOT_SRC"
fi
make -C "$UBOOT_SRC" O="$BUILD/u-boot" qemu_arm_defconfig
make -C "$UBOOT_SRC" O="$BUILD/u-boot" \
	CROSS_COMPILE="$CROSS_COMPILE" -j"$JOBS" all

LINUX_SRC="$BUILD/linux-src"
if [[ ! -d "$LINUX_SRC" ]]; then
	git clone --depth 1 --branch "$LINUX_VERSION" \
		https://github.com/torvalds/linux.git "$LINUX_SRC"
fi
make -C "$LINUX_SRC" O="$BUILD/linux" ARCH=arm \
	CROSS_COMPILE="$CROSS_COMPILE" multi_v7_defconfig
make -C "$LINUX_SRC" O="$BUILD/linux" ARCH=arm \
	CROSS_COMPILE="$CROSS_COMPILE" -j"$JOBS" zImage

BUILDROOT_VERSION=2026.08
BUILDROOT_SRC="$BUILD/buildroot-src-$BUILDROOT_VERSION"
BUILDROOT_OUT="$BUILD/buildroot-$BUILDROOT_VERSION"
BUILDROOT_NESTED_OUT="$BUILDROOT_SRC/build/buildroot-$BUILDROOT_VERSION"
if [[ ! -d "$BUILDROOT_SRC" ]]; then
	git clone --depth 1 --branch "$BUILDROOT_VERSION" \
		https://github.com/buildroot/buildroot.git "$BUILDROOT_SRC"
fi

if [[ -s "$BUILDROOT_NESTED_OUT/images/rootfs.ext2" ]]; then
	BUILDROOT_OUT="$BUILDROOT_NESTED_OUT"
else
	make -C "$BUILDROOT_SRC" O="$BUILDROOT_OUT" qemu_arm_vexpress_defconfig
	make -C "$BUILDROOT_SRC" O="$BUILDROOT_OUT" -j"$JOBS" rootfs-ext2
fi

for artifact in \
	"$BUILD/u-boot/u-boot.bin" \
	"$BUILD/linux/arch/arm/boot/zImage" \
	"$BUILDROOT_OUT/images/rootfs.ext2"; do
	if [[ ! -s "$artifact" ]]; then
		echo "Missing build artifact: $artifact" >&2
		exit 1
	fi
done

echo "Build complete. Next: bash scripts/02-make-disk.sh"
