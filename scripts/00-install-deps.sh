#!/usr/bin/env bash
set -euo pipefail

sudo apt update
sudo apt install -y \
	bc bison build-essential cpio device-tree-compiler file gawk \
	dosfstools flex gcc-arm-linux-gnueabihf git libelf-dev \
	libgnutls28-dev libncurses-dev libssl-dev mtools \
	parted patch python3-dev qemu-system-arm qemu-utils rsync swig \
	u-boot-tools unzip wget

if [[ -x /usr/bin/gnuinstall ]]; then
	sudo update-alternatives --install /usr/bin/install install /usr/bin/gnuinstall 100 >/dev/null 2>&1 || true
	sudo update-alternatives --set install /usr/bin/gnuinstall >/dev/null 2>&1 || true
	command -v install
	install --version | head -n 1
fi

hash -r
arm-linux-gnueabihf-gcc --version | head -n 1
qemu-system-arm --version | head -n 1
mkimage -V | head -n 1
