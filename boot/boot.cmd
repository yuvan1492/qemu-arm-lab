setenv kernel_addr_r 0x42000000
virtio scan
fatload virtio 0:1 ${kernel_addr_r} zImage
fdt addr ${fdtcontroladdr}
setenv bootargs 'console=ttyAMA0,115200 root=/dev/vda2 rootwait rw'
bootz ${kernel_addr_r} - ${fdtcontroladdr}
