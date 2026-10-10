#!/usr/bin/env bash
set -euo pipefail

ROOT=$(cd "$(dirname "$0")/.." && pwd)
BUILD="$ROOT/build"
BUILDROOT_VERSION=${BUILDROOT_VERSION:-2026.08}
DISK="$BUILD/disk.img"
ROOTFS="$BUILD/buildroot-$BUILDROOT_VERSION/images/rootfs.ext2"
if [[ ! -s "$ROOTFS" ]]; then
	ROOTFS="$BUILD/buildroot-src-$BUILDROOT_VERSION/build/buildroot-$BUILDROOT_VERSION/images/rootfs.ext2"
fi
KERNEL="$BUILD/linux/arch/arm/boot/zImage"
BOOTCMD="$ROOT/boot/boot.cmd"
BOOTSCR="$BUILD/boot.scr"

for artifact in "$ROOTFS" "$KERNEL"; do
	if [[ ! -s "$artifact" ]]; then
		echo "Missing $artifact; run scripts/01-build.sh first" >&2
		exit 1
	fi
done

command -v sfdisk >/dev/null
command -v losetup >/dev/null
command -v mkfs.vfat >/dev/null
command -v mkimage >/dev/null

mkdir -p "$BUILD"

if [[ -f "$BOOTCMD" ]]; then
	mkimage -A arm -T script -C none -n "QEMU ARM boot" -d "$BOOTCMD" "$BOOTSCR"
fi

truncate -s 128M "$DISK"
sfdisk "$DISK" <<'PARTITIONS'
label: dos
unit: sectors
start=2048, size=32768, type=c
start=34816, size=131072, type=83
PARTITIONS

LOOP=$(sudo losetup --find --show --partscan "$DISK")
MOUNT_DIR=$(mktemp -d)
cleanup() {
	sudo umount "$MOUNT_DIR" 2>/dev/null || true
	sudo losetup -d "$LOOP" 2>/dev/null || true
	rmdir "$MOUNT_DIR" 2>/dev/null || true
}
trap cleanup EXIT

sudo udevadm settle
sudo mkfs.vfat -F 32 -n BOOT "${LOOP}p1"
sudo dd if="$ROOTFS" of="${LOOP}p2" bs=4M conv=fsync status=progress
sudo mount "${LOOP}p1" "$MOUNT_DIR"
sudo install -m 0644 "$KERNEL" "$MOUNT_DIR/zImage"

if [[ -s "$BOOTSCR" ]]; then
	sudo install -m 0644 "$BOOTSCR" "$MOUNT_DIR/boot.scr"
fi

sync
sudo umount "$MOUNT_DIR"
sudo losetup -d "$LOOP"
trap - EXIT
rmdir "$MOUNT_DIR"

echo "Created $DISK (FAT partition 1 + rootfs partition 2)."
