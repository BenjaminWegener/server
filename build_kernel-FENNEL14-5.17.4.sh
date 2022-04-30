#!/bin/bash
echo "This script updates the kernel of the ubuntu focal image for the FENNEL14 sku0 chromebook."
echo "Be sure to use the exact image on an usb pendrive mounted as /dev/sda!"
echo "Image can be downloaded at https://github.com/hexdump0815/imagebuilder/releases/download/210724-03/chromebook_kukui-aarch64-focal.img.gz"
if [[ $EUID -ne 0 ]]; then
    echo "$0 is not running as root. Try using sudo."
    exit 2
fi

echo "We need to delete /compile!!! Do you wish to continue?"
select yn in "Yes" "No"; do
    case $yn in
        Yes ) 
            sudo rm -rf /compile;
            break;;
        No ) exit;;
    esac
done

mkdir /compile
apt install -y build-essential flex bison gettext libiberty-dev libpci-dev libelf-dev libssl-dev libslang2-dev libperl-dev python-all-dev liblzma-dev libzstd-dev libcap-dev libnuma-dev libbabeltrace-dev systemtap-sdt-dev libdw-dev apt-utils binutils-dev git wget libunwind-dev

cd /compile
mkdir doc
cd doc
wget https://github.com/hexdump0815/linux-mainline-mediatek-mt81xx-kernel/archive/edbb24627650c1c64561d51473d7c519ecc37d1c.zip
unzip edbb24627650c1c64561d51473d7c519ecc37d1c.zip
mv linux-mainline-mediatek-mt81xx-kernel-edbb24627650c1c64561d51473d7c519ecc37d1c stable-mt

# remove fix-cursor-patch since giving error
rm -rf /compile/doc/stable-mt/misc.cbm/patches/5.13.2/mt81xx-cadmium-fix-cursor.patch

wget https://github.com/hexdump0815/kernel-config-options/archive/864d8824e768abc555608e9c199ce3eb52f21b63.zip
unzip 864d8824e768abc555608e9c199ce3eb52f21b63.zip
mv kernel-config-options-864d8824e768abc555608e9c199ce3eb52f21b63 kernel-config-options

cd ..
mkdir source
cd source
#wget https://mirrors.edge.kernel.org/pub/linux/kernel/v5.x/linux-5.13.19.tar.xz
cp /linux-5.17.4.tar.xz .
tar -xvf linux-5.17.4.tar.xz
mv linux-5.17.4 linux-stable-mt

mkdir /compile/result
mkdir /compile/result/stable-mt








# directories:
# - /compile/doc/stable-mt - the files in this dir
# - /compile/source/linux-stable-mt - the kernel sources checked out from gitrepo
# - /compile/result/stable-mt - the resulting kernel, modules etc. tar.gz files
# - /compile/doc/kernel-config-options - https://github.com/hexdump0815/kernel-config-options
# name: stb-mt8

# INFO this is for mt8183 based chromebooks - see also readme.cbm

cd /compile/source/linux-stable-mt

#cp /5.17.4-fixes.zip .
#unzip -o 5.17.4-fixes.zip

# patches for mt8183/kukui
#for i in /compile/doc/stable-mt/misc.cbm/patches/5.13.2/mt8183*.patch; do
#  echo === $i
#  patch -p1 < $i
#done
#for i in /compile/doc/stable-mt/misc.cbm/patches/5.13.2/mt81xx*.patch; do
#  echo === $i
#  patch -p1 < $i
#done

# add additional dts files from v5.14
#cp -v /compile/doc/stable-mt/misc.cbm/misc/v5.14-dts/*.dts* arch/arm64/boot/dts/mediatek
#patch -p1 < /compile/doc/stable-mt/misc.cbm/misc/v5.14-dts/add-v5.14-dts-files.patch

#rm -f /compile/source/linux-stable-mt/arch/arm64/boot/dts/mediatek/mt8183-kukui-jacuzzi-fennel14.dts
#cp /mt8183-kukui-jacuzzi-fennel14.dts /compile/source/linux-stable-mt/arch/arm64/boot/dts/mediatek/

cp /5.17.4-config.cfg /compile/doc/kernel-config-options
echo "config ready, do you wish to continue?"
select yn in "Yes" "No"; do
    case $yn in
        Yes )
            break;;
        No ) exit;;
    esac
done

export ARCH=arm64
#scripts/kconfig/merge_config.sh -m arch/arm64/configs/defconfig /compile/doc/kernel-config-options/chromebooks-aarch64.cfg /compile/doc/kernel-config-options/mediatek.cfg /compile/doc/kernel-config-options/docker-options.cfg /compile/doc/kernel-config-options/options-to-remove-generic.cfg /compile/doc/stable-mt/misc.cbm/options/options-to-remove-special.cfg /compile/doc/kernel-config-options/additional-options-generic.cfg /compile/doc/kernel-config-options/additional-options-aarch64.cfg /compile/doc/stable-mt/misc.cbm/options/additional-options-special.cfg
scripts/kconfig/merge_config.sh -m arch/arm64/configs/defconfig /compile/doc/kernel-config-options/5.17.4-config.cfg
( cd /compile/doc/kernel-config-options ; git rev-parse --verify HEAD ) > /compile/doc/stable-mt/misc.cbm/options/kernel-config-options.version
make olddefconfig
./scripts/config --set-str CONFIG_LOCALVERSION "-stb-mt8"
make -j 8 Image dtbs modules
cd tools/perf
make
cd ../power/cpupower
make
cd ../../..
export kver=`make kernelrelease`
echo ${kver}
# remove debug info if there and not wanted
#find . -type f -name '*.ko' | sudo xargs -n 1 objcopy --strip-unneeded
make modules_install
mkdir -p /lib/modules/${kver}/tools
cp -v tools/perf/perf /lib/modules/${kver}/tools
cp -v tools/power/cpupower/cpupower /lib/modules/${kver}/tools
cp -v tools/power/cpupower/libcpupower.so.0.0.1 /lib/modules/${kver}/tools/libcpupower.so.0
# make headers_install INSTALL_HDR_PATH=/usr
cp -v .config /boot/config-${kver}
cp -v arch/arm64/boot/Image /boot/Image-${kver}
mkdir -p /boot/dtb-${kver}
cp -v arch/arm64/boot/dts/mediatek/mt8183*.dtb /boot/dtb-${kver}
cp -v System.map /boot/System.map-${kver}
# start chromebook special - required: apt-get install liblz4-tool vboot-kernel-utils
cp arch/arm64/boot/Image Image
lz4 -f Image Image.lz4
dd if=/dev/zero of=bootloader.bin bs=512 count=1
cp /compile/doc/stable-mt/misc.cbm/misc/cmdline cmdline
mkimage -D "-I dts -O dtb -p 2048" -f auto -A arm64 -O linux -T kernel -C lz4 -a 0 -d Image.lz4 -b arch/arm64/boot/dts/mediatek/mt8183-kukui-jacuzzi-fennel14.dtb kernel.itb kernel.itb
vbutil_kernel --pack vmlinux.kpart --keyblock /usr/share/vboot/devkeys/kernel.keyblock --signprivate /usr/share/vboot/devkeys/kernel_data_key.vbprivk --version 1 --config cmdline --bootloader bootloader.bin --vmlinuz kernel.itb --arch arm
cp -v vmlinux.kpart /boot/vmlinux.kpart-${kver}
rm -f Image Image.lz4 cmdline bootloader.bin kernel.itb vmlinux.kpart
# end chromebook special
cd /boot
update-initramfs -c -k ${kver}
#mkimage -A arm64 -O linux -T ramdisk -a 0x0 -e 0x0 -n initrd.img-${kver} -d initrd.img-${kver} uInitrd-${kver}
tar cvzf /compile/source/linux-stable-mt/${kver}.tar.gz /boot/Image-${kver} /boot/System.map-${kver} /boot/config-${kver} /boot/dtb-${kver} /boot/initrd.img-${kver} /boot/vmlinux.kpart-${kver} /lib/modules/${kver}
cp -v /compile/doc/stable-mt/config.mt8 /compile/doc/stable-mt/config.mt8.old
cp -v /compile/source/linux-stable-mt/.config /compile/doc/stable-mt/config.mt8
cp -v /compile/source/linux-stable-mt/.config /compile/doc/stable-mt/config.mt8-${kver}
cp -v /compile/source/linux-stable-mt/*.tar.gz /compile/result/stable-mt









echo "Do you wish to install the kernel? YOUR INSTALLATION HAS TO BE ON /dev/sda!!! THIS CAN NOT BE UNDONE AND MAY DAMAGE YOUR DEVICE!!!"
select yn in "Yes" "No"; do
    case $yn in
        Yes ) 
            cd /tmp;
            mkdir mnt;
            mount /dev/sda4 /tmp/mnt;
            mount /dev/sda3 /tmp/mnt/boot;
            cd /tmp/mnt;
            cp /compile/result/stable-mt/5.17.4-stb-mt8.tar.gz .;
            tar xzf 5.17.4-stb-mt8.tar.gz;
            dd if=boot/vmlinux.kpart-5.17.4-stb-mt8 of=/dev/sda1;
            umount /tmp/mnt/boot tmp/mnt;
            echo "kernel successfully written...";
            break;;
        No ) exit;;
    esac
done

echo "Do you wish to reboot?"
select yn in "Yes" "No"; do
    case $yn in
        Yes ) 
            reboot;
            break;;
        No ) exit;;
    esac
done

