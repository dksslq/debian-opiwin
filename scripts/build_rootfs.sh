#!/bin/dash
set -e

[ -f $BASEDIR/output/.flag_build_rootfs_complete ] && exit

DIST="stretch"
APT_SRC=mirrors.tuna.tsinghua.edu.cn
ARCH=arm64

# 清场
rm -fr $ROOTFS
mkdir -p $ROOTFS

# debootstrap构建基本根文件系统
echo 开始构建基本根文件系统
debootstrap --arch=$ARCH $DIST $ROOTFS https://$APT_SRC/debian

mount -t devpts chpts $ROOTFS/dev/pts

# qemu
QEMULATOR=qemu-arm-static
[ "$ARCH" = "arm64" ] && QEMULATOR=qemu-aarch64-static
#arm64和aarch64其实是不同两家定义的相同的东西
cp -fa /usr/bin/$QEMULATOR "$ROOTFS/usr/bin"

# 安装内核源码
#KVERSION=$(cat $K_SRC/include/config/kernel.release 2> /dev/null)
#mkdir -p $ROOTFS/usr/src
#rm -fr $ROOTFS/usr/src/linux-$KVERSION
#cp -rfa $K_SRC $ROOTFS/usr/src/linux-$KVERSION
#make -C $ROOTFS/usr/src/linux-$KVERSION distclean


########edit etc#########

# mali驱动挂载/卸载脚本
#cat > "$ROOTFS/usr/sbin/insmali" <<EOF
##!/bin/dash
#set -e
#insmod /lib/modules/\$(uname -r)/mali/ump.ko
#insmod /lib/modules/\$(uname -r)/mali/umplock.ko
#insmod /lib/modules/\$(uname -r)/mali/mali.ko
#EOF
#cat > "$ROOTFS/usr/sbin/rmmali" <<EOF
##!/bin/dash
#rmmod mali > /dev/null 2>&1
#rmmod umplock > /dev/null 2>&1
#rmmod ump > /dev/null 2>&1
#EOF
#chmod 0755 $ROOTFS/usr/sbin/insmali
#chmod 0755 $ROOTFS/usr/sbin/rmmali

cat > "$ROOTFS/etc/network/interfaces" <<EOF
auto eth0
iface eth0 inet dhcp
EOF

cat > "$ROOTFS/etc/hostname" <<EOF
orangepi
EOF

cat > "$ROOTFS/etc/resolv.conf" <<EOF
EOF

cat > "$ROOTFS/etc/hosts" <<EOF
127.0.0.1 localhost
127.0.1.1 orangepi

# The following lines are desirable for IPv6 capable hosts
::1     localhost ip6-localhost ip6-loopback
fe00::0 ip6-localnet
ff00::0 ip6-mcastprefix
ff02::1 ip6-allnodes
ff02::2 ip6-allrouters
EOF

cat > "$ROOTFS/etc/fstab" <<EOF
# <file system>	<dir>	<type>	<options>			<dump>	<pass>
/dev/mmcblk0p1	/boot	vfat	defaults			0		2
/dev/mmcblk0p2	/	ext4	defaults,noatime		0		1
EOF

cat > "$ROOTFS/etc/udev/rules.d/90-sunxi-disp-permission.rules" <<EOF
KERNEL=="disp", MODE="0770", GROUP="video"
KERNEL=="cedar_dev", MODE="0770", GROUP="video"
KERNEL=="ion", MODE="0770", GROUP="video"
KERNEL=="mali", MODE="0770", GROUP="video"
EOF
#########################

#########################
mkdir -p "$ROOTFS/var/lib/alsa"
cp -fa $PREBUILT/asound.state "$ROOTFS/var/lib/alsa/asound.state"

#########################
# 安装 模块 头文件 配置
cp -rfa $K_OUT/lib $ROOTFS
cp -rfa $K_OUT/usr $ROOTFS
cp -rfa $K_OUT/etc $ROOTFS

# resolv.conf
cp -fa /etc/resolv.conf $ROOTFS/etc/resolv.conf

#######chroot do#########
LOCALE_LANG="en_US.UTF-8 UTF-8"
#LOCALE_LANG="zh_CN.UTF-8 UTF-8"
EXTRAPKG="dosfstools curl xz-utils iw rfkill wpasupplicant openssh-server alsa-utils vim sudo"
cat > "$ROOTFS/do.sh" <<EOF
#!/bin/dash
set -e

# 禁用交互模式
export DEBIAN_FRONTEND=noninteractive

# 内核源码
#ln -fs /usr/src/linux-$KVERSION /lib/modules/$KVERSION/build
#ln -fs /usr/src/linux-$KVERSION /lib/modules/$KVERSION/source

LC_ALL=C LANG=C apt -y update

# 设置语言
LC_ALL=C LANG=C apt -y install locales
sed -i "s/^# ${LOCALE_LANG}/${LOCALE_LANG}/" /etc/locale.gen # 取消locale.gen文件语言项的注释
sed -i "s/^# zh_CN.UTF-8 UTF-8/zh_CN.UTF-8 UTF-8/" /etc/locale.gen
LC_ALL=C LANG=C locale-gen $LOCALE_LANG
LC_ALL=C LANG=C update-locale LANG=$LOCALE_LANG LANGUAGE=$LOCALE_LANG LC_MESSAGES=$LOCALE_LANG

apt -y install man-db
apt -y install $EXTRAPKG
apt clean

useradd -d /home/dksslq -m -s /bin/bash -u 1000 dksslq
usermod -a -G sudo,adm,input,video,plugdev dksslq
echo root:toor | chpasswd
echo dksslq:123456 | chpasswd

systemctl enable ssh

EOF

chmod +x "$ROOTFS/do.sh"
echo "chroot进入$ROOTFS"
chroot $ROOTFS /do.sh
rm -f "$ROOTFS/do.sh"
#########################

# clean
rm -f $ROOTFS/usr/bin/$QEMULATOR
umount $ROOTFS/dev/pts > /dev/null 2>&1

echo "成功构建根文件系统"
touch $BASEDIR/output/.flag_build_rootfs_complete
