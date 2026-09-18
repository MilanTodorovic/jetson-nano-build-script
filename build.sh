#!/bin/bash

SCRIPT_DIR="$(dirname "$(readlink -f "$0")")"

echo "This script is mainly a wrapper around the jetson-nano-image build process."
echo "It will call `just` and the corresponding scripts to build the rootfs and Jetson image."
echo "It additionally offers to compile an overclocked version of the kernel and copy it over to the flashed image, and setup all the media library Docker containers."
read -p "Are you ready to proceed? (y/n) [default=n]: " ready
if [[ "$ready" != "y" ]]; then
    echo "Exiting..."
    exit 0
fi

echo "Changing directory to Desktop"
cd /home/$USER/Desktop

echo "Cloning jetson-nano-image"
# Builds a Ubuntu 20.04 image, with the latest JetPack version (32.7.6)
# Newer versions aren't supported due to nVidia not giving a flying fuck
git clone --depth=1 https://github.com/MilanTodorovic/jetson-nano-image

echo "Checking if `just` is installed"
if ! dpkg -s just &> /dev/null
then
    echo "  Package `just` missing from host system."
    echo "    Searching for package in apt..."
    if apt-cache --names-only search "^just$"
    then
        echo "    Package available thru apt-get."
        sudo apt-get install --no-install-recommends -y just
    else
        echo "    Package not found in apt, trying snap..."
        sudo snap install just
        if ! dpkg -s just &> /dev/null
        then
            echo "    Package `just` not found in apt or snap. Press any key to exit."
            read -rsn 1
        fi
    fi
else
    echo "  Package `just` installed."
fi
echo "All good. Proceding to build script."

echo "NOTICE: The following image will be built with a 4GB swapfile and with ZRAM disabled (will use ZSWAP in the boot agruments; look further bellow in the script file).\n If you don't want this, take the time to comment out the line in `/jetson-nano-image/Containerfile.rootfs.20_04`"
read -rsn 1 -p "When you are ready press any key to procede with the build."

echo "Building rootfs"
cd ../jetson-nano-image && just build-jetson-rootfs 20.04

read -p "Jetson model: (jetson-nano, jetson-nano-2gb) [default=jetson-nano]: " model
read -p "Jetson revision: (100, 200, 300) [default=200]: " revision
JETSON_MODEL="${model:-jetson-nano}"
JETSON_REVISION="${revision:-200}"
echo "Building Jetson image"
just build-jetson-image -b $JETSON_MODEL -r $JETSON_REVISION

read -p "Flash image to drive? (y/n) [default=n]: " flash
if [[ "$flash" == "y" ]]; then
    read -p "Specify drive path: (/dev/mmcblk0 or /dev/sdX) [default=/dev/mmcblk0]: " drive
    DRIVE=${drive:-/dev/mmcblk0}
    echo "Flashing jetson_nano_ubuntu20.img to device $DRIVE"
    sudo just flash-jetson-image jetson_nano_ubuntu20.img $DRIVE
fi

read -p "Clean up? (y/n) [default=n]: " clean
if [[ "$clean" == "y" ]]; then
    echo "Cleaning up"
    just clean
fi

cd ..
read -p "Would you like to build an overclocked version of the kernel? (y/n) [default=n]: " build_overclock
if [[ "$build_overclock" == "y" ]]; then
    echo "There are two branches available: jetpack32.7.6 and Overclock-extreme."
    echo "jetpack32.7.6 offers 2GHz on the CPU, 1GHz on the GPU and 844MHz on the NVDEC. PSU suggestion 5v 4a."
    echo "Overclock-extreme offers 2.2GHz on the CPU, 1.15GHz on the GPU and 844MHz on the NVDEC. PSU suggestion 5v 5a."
    read -p "Choose a branch: (jetpack32.7.6 or Overclock-extreme) [default=jetpack32.7.6]: " branch
    BRANCH=${branch:-jetpack32.7.6}
    echo "Cloning jetson-nano-overclock"

    git clone -b $BRANCH --depth=1 https://github.com/MilanTodorovic/jetson-nano-overclock

    echo "Downloading GCC 9.2"
    # Download GCC 9.2, the last version which successfully compiles the overclocked kernel
    # You can use any version from 7.3.1 up to 9.2
    curl -o gcc-9.2.tar.xz https://developer.arm.com/-/media/Files/downloads/gnu-a/9.2-2019.12/binrel/gcc-arm-9.2-2019.12-x86_64-aarch64-none-linux-gnu.tar.xz
    tar -xJf gcc-9.2.tar.xz
    rm gcc-9.2.tar.xz

    echo "Building jetson_nano_overclock"
    cd jetson-nano-overclock && ./build.sh

    echo "Copying kernel and modules to drive"
    cp -f /home/$USER/kernel_out/build_92/Image $DRIVE/boot/Image
    cp -f /home/$USER/kernel_out/build_92/zImage $DRIVE/boot/zImage
    cp -f /home/$USER/kernel_out/build_92/dts/. $DRIVE/boot/
    # DTB directory has only one file per default: /boot/dtb/kernel_tegra210-p3448-0000-p3449-0000-b00.dtb
    # REthink if this step is neccessary
    cp -f /home/$USER/kernel_out/build_92/dts/. $DRIVE/boot/dtb/
    cp -fr /home/$USER/kernel_out/modules_92/lib/firmware/. $DRIVE/lib/firmware/
    cp -fr /home/$USER/kernel_out/modules_92/lib/modules/. $DRIVE/lib/modules/
fi

read -p "If you installed the image on an external drive, would you like to add boot parameters to boot from it? (y/n) [default=n]: " boot
if [[ "$boot" == "y" ]]; then
    echo "Changing kernel parameters to boot from $DRIVE"
    PARTUUID="$(blkid $DRIVE | grep -oP 'PARTUUID="\K[^"]+')"
    sudo sed -i 's/APPEND ${cbootargs}/APPEND ${cbootargs} root=PARTUUID='$PARTUUID' rw rootwait rootfstype=ext4 zswap.enabled=1 zswap.compressor=lzo zswap.max_pool_percent=25 console=ttyS0,115200n8 console=tty0 fbcon=map:0 net.ifnames=0/g' $DRIVE/boot/extlinux/extlinux.conf
fi

# TODO
cd ..
git clone --depth=1 https://github.com/MilanTodorovic/jetson-nano-media-server
cd jetson-nano-media-server


cd ..
read -p "Would you like to delete all downloaded and built files? (y/n) [default=n]: " delete
if [[ "$delete" == "y" ]]; then
    rm -rf /home/$USER/kernel_out
    rm -rf /home/$USER/jetson-nano-overclock
    rm -rf /home/$USER/jetson-nano-image
    rm -rf /home/$USER/jetson-nano-media-server
    rm -rf /home/$USER/gcc-9.2
fi

echo "All done."

read -p "Would you like to delete this script and its directory? (y/n) [default=n]: " delete_script
if [[ "$delete_script" == "y" ]]; then
    cd /tmp || exit 0
    rm -rf "$SCRIPT_DIR"
fi
