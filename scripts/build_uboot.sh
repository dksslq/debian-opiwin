#!/bin/dash
set -e

[ -f $OUTPUT/.flag_build_uboot_complete ] && exit

TOOLCHAIN=$BASEDIR/toolchain/gcc-linaro-aarch/gcc-linaro/bin/arm-linux-gnueabihf-
ARCH=arm

mkdir -p $UBT_OUT

# config
make -C $UBT_SRC ARCH=$ARCH CROSS_COMPILE=$TOOLCHAIN ${BOARD_FAMILY}_config
# build
make -C $UBT_SRC ARCH=$ARCH CROSS_COMPILE=$TOOLCHAIN -j8
UBOOT_ORIG=$UBT_SRC/u-boot-${BOARD_FAMILY}.bin

# dts转dtb 生成设备数,kernel给uboot的接口
dtc -Idts -Odtb -o $UBT_OUT/$DT_FILE $K_SRC/arch/arm64/boot/dts/${BOARD_FAMILY}-orangepiwin.dts
# 融合dtb到uboot
$UBT_SRC/tools/boot0img -s $PREBUILT/scp.bin -d $PREBUILT/bl31.bin -u $UBOOT_ORIG -e -F $UBT_OUT/$DT_FILE -o $UBT_OUT/u-boot-with-dtb.bin

echo "成功构建uboot"
touch $OUTPUT/.flag_build_uboot_complete
