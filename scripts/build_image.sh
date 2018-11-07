#!/bin/dash
set -e

[ -f $OUTPUT/.flag_build_image_complete ] && exit

echo "===========================构建系统镜像==========================="
# 点
boot0_position=8      # KiB boot0位置
uboot_position=19096  # KiB uboot位置
part_position=20480   # KiB 分区表位置 20MiB x1024/512 == x2

boot_size=50          # 50MiB
root_size=1024		# 1500MiB

rm -fr $IMGOUT
mkdir -p $IMGOUT/part

# 磁盘头部,第一个分区之前的部分
DISK_HEAD=$IMGOUT/head.img
# boot分区 (VFAT)
BOOT=$IMGOUT/boot.img
# root分区(系统分区)
ROOT=$IMGOUT/root.img

dd if=/dev/zero of=$DISK_HEAD bs=1M count=$((part_position/1024)) #1Mx20
dd if=$PREBUILT/boot0.bin of=$DISK_HEAD bs=1K seek=$boot0_position conv=notrunc,sync
dd if=$UBT_OUT/u-boot-with-dtb.bin of=$DISK_HEAD bs=1K seek=$uboot_position conv=notrunc,sync

dd if=/dev/zero of=$BOOT bs=1M count=$boot_size
mkfs.vfat -n BOOT $BOOT #标签BOOT

# 挂载并写入boot分区
[ ! -f $K_OUT/Image ] && exit 1
[ ! -f $PREBUILT/initrd.img ] && exit 1
mount -t vfat $BOOT $IMGOUT/part
mkdir $IMGOUT/part/orangepi
cp -f $K_OUT/Image $IMGOUT/part/orangepi/Image
cp -f $UBT_OUT/$DT_FILE $IMGOUT/part/orangepi/$DT_FILE
cp -f $PREBUILT/initrd.img $IMGOUT/part/initrd.img
cat > $IMGOUT/part/uEnv.txt <<EOF
console=tty0 console=ttyS0,115200n8 no_console_suspend
kernel_filename=orangepi/Image
initrd_filename=initrd.img
ethaddr=$ETHADDR
EOF
sync $IMGOUT/part/*
umount $IMGOUT/part

# 连接boot分区到磁盘头部
dd if=$BOOT of=$DISK_HEAD bs=1M seek=$((part_position/1024)) conv=notrunc,sync oflag=append

dd if=/dev/zero of=$ROOT bs=1M count=$root_size
mkfs.ext4 -O ^64bit,^metadata_csum -F -b 4096 -E stride=2,stripe-width=1024 -L ROOTFS $ROOT

# 挂载并写入root分区
[ ! -d $ROOTFS ] && exit 1
mount -t ext4 $ROOT $IMGOUT/part
cp -rfa $ROOTFS/* $IMGOUT/part
sync $IMGOUT/part/*
umount $IMGOUT/part

# 连接root分区到磁盘头部
dd if=$ROOT of=$DISK_HEAD bs=1M seek=$((part_position/1024+boot_size))

# fdisk进行分区表
# o创建一个空的DOS分区表
# n创建新分区BOOT
# p主分区
# 分区号 1
# 分区起点$((part_position*1024/512))单位扇区(sector)512字节
# 分区终点+${boot_size}M
# t修改分区类型
# c 指定类型为W95 FAT32 (LBA)
# n创建新分区 rootfs
# p主分区
# 分区号 2
# 分区起点$((part_position*1024/512 + boot_size*1024*1024/512))
# 空行 指定默认终点 尾部
# t修改分区类型
# 2号分区(存在多个分区时需指定分区号)
# 83  Linux
# w将修改写入磁盘，保存
cat <<EOF | fdisk $DISK_HEAD
o
n
p
1
$((part_position*1024/512))
+${boot_size}M
t
c
n
p
2
$((part_position*1024/512 + boot_size*1024*1024/512))

t
2
83
w
EOF

mv $DISK_HEAD $OUTPUT/${PLATFORM}.img
cat $OUTPUT/${PLATFORM}.img | md5sum > $OUTPUT/${PLATFORM}.img.md5sum
rm -rf $IMGOUT

echo "===========================成功构建系统镜像==========================="
touch $OUTPUT/.flag_build_image_complete
