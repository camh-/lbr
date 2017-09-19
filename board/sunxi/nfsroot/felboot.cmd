setenv bootargs "earlyprintk console=ttyS0,115200 rootwait init=/sbin/init ip=dhcp root=/dev/nfs nfsroot=10.100.110.1:/srv/nfs/root/sunxi,nfsvers=3"
setenv kernel_addr_r 0x42000000
setenv fdt_addr_r 0x43000000
setenv ramdisk_addr_r -
setenv fdt_high 0xffffffff
bootz ${kernel_addr_r} ${ramdisk_addr_r} ${fdt_addr_r}
