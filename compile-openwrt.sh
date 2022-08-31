#!/usr/bin/env bash

BASEDIR=${PWD}

[ -d "${BASEDIR}/openwrt" ] && rm -rf "${BASEDIR}/openwrt"

git clone https://git.openwrt.org/openwrt/openwrt.git
cd openwrt
git fetch -t
git checkout v21.02.3

if [ -d "${BASEDIR}/patches" ]; then
    for patch in $(find "${BASEDIR}/patches" -type f -name '*.patch'); do
        patch -p1 < "${patch}"
    done
fi

./scripts/feeds update -a
./scripts/feeds install -a

wget https://downloads.openwrt.org/releases/21.02.3/targets/rockchip/armv8/config.buildinfo -O .config

PACKAGES="kmod-rt2800-usb rt2800-usb-firmware kmod-cfg80211 kmod-lib80211 kmod-mac80211 kmod-rtl8192cu \
            docker docker-compose dockerd luci-app-dockerman luci-lib-docker \
            base-files block-mount fdisk luci-app-minidlna minidlna samba4-server \
            samba4-libs luci-app-samba4 wireguard-tools luci-app-wireguard wpa-supplicant hostapd \
            openvpn-openssl luci-app-openvpn watchcat openssh-sftp-client \
            luci-base luci-ssl luci-mod-admin-full luci-theme-bootstrap \
            kmod-usb-storage kmod-usb-ohci kmod-usb-uhci e2fsprogs fdisk resize2fs \
            htop debootstrap luci-compat luci-lib-ipkg dnsmasq luci-app-ttyd \
            irqbalance ethtool netperf speedtest-netperf iperf3 \
            curl wget rsync file htop lsof less mc tree usbutils bash diffutils \
            openssh-sftp-server nano luci-app-ttyd kmod-fs-exfat \
            kmod-usb-storage block-mount luci-app-minidlna kmod-fs-ext4 \
            urngd usign vpn-policy-routing wg-installer-client wireguard-tools \
            kmod-usb-core kmod-usb3 dnsmasq dropbear e2fsprogs \
            zlib firewall wireless-regdb f2fsck openssh-sftp-server \
            kmod-usb-wdm kmod-usb-net-ipheth usbmuxd \
            kmod-usb-net-cdc-ether mount-utils kmod-rtl8xxxu kmod-rtl8187 \
            kmod-rtl8xxxu rtl8188eu-firmware kmod-rtl8192ce kmod-rtl8192cu kmod-rtl8192de \
            adblock luci-app-adblock kmod-usb-net-asix-ax88179"

for PACKAGE in ${PACKAGES}; do
    echo "CONFIG_PACKAGE_${PACKAGE}=y" >> .config
done

echo 'CONFIG_TARGET_KERNEL_PARTSIZE=1000' >> .config
echo 'CONFIG_TARGET_ROOTFS_PARTSIZE=13000' >> .config
echo 'CONFIG_TARGET_rockchip_armv8_DEVICE_radxa_rock-pi-4=y' >> .config
echo 'CONFIG_HAS_SUBTARGETS=y' >> .config
echo 'CONFIG_HAS_DEVICES=y' >> .config
echo 'CONFIG_TARGET_BOARD="rockchip"' >> .config
echo 'CONFIG_TARGET_SUBTARGET="armv8"' >> .config
echo 'CONFIG_TARGET_PROFILE="DEVICE_radxa_rock-pi-4"' >> .config
echo 'CONFIG_TARGET_ARCH_PACKAGES="aarch64_generic"' >> .config
echo 'CONFIG_TARGET_ROOTFS_EXT4FS=y' >> .config
echo 'CONFIG_TARGET_IMAGES_GZIP=n' >> .config
echo 'CONFIG_TARGET_ROOTFS_SQUASHFS=n' >> .config

sed -i "s/CONFIG_TARGET_MULTI_PROFILE=y/CONFIG_TARGET_MULTI_PROFILE=n/g" .config

make defconfig

cp -R ${BASEDIR}/files .

make download V=s
make tools/install -j$(nproc) V=s
make toolchain/install -j$(nproc) V=s
make -j$(nproc) V=s
