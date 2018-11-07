#!/bin/dash
set -e
#检查root权限

export BASEDIR=$(cd "$(dirname "$0")"; pwd)
export OUTPUT=$BASEDIR/output
export PREBUILT=$BASEDIR/vendor
export PLATFORM=OrangePiA64_Win
export BOARD_FAMILY=sun50iw1p1
export ETHADDR=12:34:56:78:9a:bc

# uboot
export UBT_SRC=$BASEDIR/uboot
export UBT_OUT=$OUTPUT/uboot
export DT_FILE=OrangePi-A64.dtb
# 内核源码
export K_SRC=$BASEDIR/linux
# 其他驱动
export MDRIVERS=$K_SRC/modules
export K_OUT=$OUTPUT/kernel
# rootfs
export ROOTFS=$OUTPUT/rootfs
# image
export IMGOUT=$OUTPUT/image

mkdir -p $OUTPUT

do_clean(){
	rm -fr $ROOTFS
	rm -fr $OUTPUT
	make -C $K_SRC distclean
	make -C $UBT_SRC distclean
}

if [ "$1" = "clean" ];then
	echo "清理"
	do_clean
	echo "done."
	exit
fi

apt update
#apt安装
apt_install(){
	dpkg -l | grep -q $1 ||  { 
		echo "$1不存在,尝试安装它."
		apt -y install $1
	}
}
#########安装依赖#########
apt_install qemu-user-static
apt_install debootstrap
apt_install qemu-system-arm
#apt_install kernel-package
#########################

echo "===========================构建完整img镜像==========================="

$BASEDIR/scripts/build_uboot.sh
$BASEDIR/scripts/build_kernel.sh
$BASEDIR/scripts/build_rootfs.sh
$BASEDIR/scripts/build_image.sh

echo "===========================DONE.==========================="

