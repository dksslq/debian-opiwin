#!/bin/dash
set -e

[ -f $OUTPUT/.flag_build_kernel_complete ] && exit

TOOLCHAIN=$BASEDIR/toolchain/gcc-linaro-aarch/bin/aarch64-linux-gnu-
ARCH=arm64
CONFIG=${PLATFORM}_linux_defconfig
KO_LOAD=$PREBUILT/etc/modules-load.d

mkdir -p $K_OUT/usr 
mkdir -p $K_OUT/lib
#make -C $K_SRC clean

# 配置内核
if [ ! -f $K_SRC/.config ];then
	make -C $K_SRC ARCH=$ARCH CROSS_COMPILE=$TOOLCHAIN $CONFIG
fi

# kernel
make -C $K_SRC ARCH=$ARCH CROSS_COMPILE=$TOOLCHAIN LOCALVERSION="-pine64" -j8
cp -fa $K_SRC/arch/arm64/boot/Image $K_OUT/Image
# padding /lib
# 模块 /lib/modules
make -C $K_SRC ARCH=$ARCH CROSS_COMPILE=$TOOLCHAIN modules_install INSTALL_MOD_PATH=$K_OUT
# 安装固件
cp -rfa $PREBUILT/lib/firmware $K_OUT/lib
# 自加载模块配置
mkdir -p $K_OUT/etc/modules-load.d
cp -rfa $KO_LOAD/* $K_OUT/etc/modules-load.d
# Kernel firmware /lib/firmware
#make -C $K_SRC ARCH=$ARCH CROSS_COMPILE=$TOOLCHAIN firmware_install INSTALL_MOD_PATH=$K_OUT

rm -f $K_OUT/lib/modules/`cat $K_SRC/include/config/kernel.release 2> /dev/null`/build
rm -f $K_OUT/lib/modules/`cat $K_SRC/include/config/kernel.release 2> /dev/null`/source

# 头文件 /usr/include
make -C $K_SRC ARCH=$ARCH CROSS_COMPILE=$TOOLCHAIN headers_install INSTALL_HDR_PATH=$K_OUT/usr

######mali400 drivers######
mali400(){
	local UMP_KO=$MDRIVERS/gpu/mali400/kernel_mode/driver/src/devicedrv
	local MALI_DRM=$MDRIVERS/gpu/mali400/kernel_mode/driver/src/egl/x11/drm_module/mali_drm
	local MALI_MOD_INSTALL_DIR=$K_OUT/lib/modules/`cat $K_SRC/include/config/kernel.release 2> /dev/null`/mali
	mkdir -p $MALI_MOD_INSTALL_DIR
	make -C $MDRIVERS/gpu ARCH=$ARCH CROSS_COMPILE=$TOOLCHAIN LICHEE_KDIR=$K_SRC LICHEE_MOD_DIR=${MALI_MOD_INSTALL_DIR} LICHEE_PLATFORM=linux

	#cp $UMP_KO/mali/mali.ko $MALI_MOD_INSTALL_DIR
	#cp $UMP_KO/ump/ump.ko   $MALI_MOD_INSTALL_DIR
	#cp $UMP_KO/umplock/umplock.ko $MALI_MOD_INSTALL_DIR
	#cp $MALI_DRM/mali_drm.ko $MALI_MOD_INSTALL_DIR
}

#mali400
#########################

echo "成功构建内核"
touch $OUTPUT/.flag_build_kernel_complete
