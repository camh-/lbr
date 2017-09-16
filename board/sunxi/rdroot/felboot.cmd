setenv bootargs "earlyprintk console=ttyS0,115200 rootwait"
setenv kernel_addr_r 0x42000000
setenv fdt_addr_r 0x43000000
setenv ramdisk_addr_r 0x43300000
setenv fdt_high 0xffffffff
bootz ${kernel_addr_r} ${ramdisk_addr_r} ${fdt_addr_r}
