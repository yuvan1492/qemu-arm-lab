#!/usr/bin/env bash
set -euo pipefail

ROOT=$(cd "$(dirname "$0")/.." && pwd)
UBOOT="$ROOT/build/u-boot/u-boot.bin"
DISK="$ROOT/build/disk.img"

for artifact in "$UBOOT" "$DISK"; do
	if [[ ! -s "$artifact" ]]; then
		echo "Missing $artifact; build first with scripts/01-build.sh and scripts/02-make-disk.sh" >&2
		exit 1
	fi
done

QEMU_ARGS=(
	-machine virt,highmem=off \
	-cpu cortex-a15 \
	-m 1024M \
	-smp 2 \
	-bios "$UBOOT" \
	-drive if=virtio,file="$DISK",format=raw \
	-net nic,model=virtio-net-pci \
	-net user
)

if [[ "${1:-}" == "--test-boot" ]]; then
	LOG=$(mktemp)
	qemu-system-arm "${QEMU_ARGS[@]}" \
		-display none -serial "file:$LOG" -monitor none &
	QEMU_PID=$!
	cleanup() {
		kill "$QEMU_PID" 2>/dev/null || true
		wait "$QEMU_PID" 2>/dev/null || true
		rm -f "$LOG"
	}
	trap cleanup EXIT

	for ((attempt = 0; attempt < 90; attempt++)); do
		if grep -Fq 'VFS: Mounted root' "$LOG" && \
			grep -Fq 'Welcome to Buildroot' "$LOG"; then
			echo "QEMU boot passed: Linux mounted root and started Buildroot."
			exit 0
		fi
		if ! kill -0 "$QEMU_PID" 2>/dev/null; then
			echo "QEMU exited before Buildroot started." >&2
			cat "$LOG" >&2
			exit 1
		fi
		sleep 1
	done
	echo "Timed out waiting for the Buildroot login prompt." >&2
	cat "$LOG" >&2
	exit 1
fi

if [[ $# -ne 0 ]]; then
	echo "Usage: $0 [--test-boot]" >&2
	exit 2
fi

exec qemu-system-arm "${QEMU_ARGS[@]}" \
	-nographic -serial mon:stdio -monitor none
