#!/usr/bin/env bash

# Change these to fit the versions you want to compile
OPENWRT_VERSION='21.02.3'
OPENWRT_PACKAGES_BRANCH='openwrt-21.02'

# Do not change these as they are used by the script
BASEDIR="${PWD}"

# Bash Color mapping
grey='\e[1;30m'
red='\e[0;31m'
RED='\e[1;31m'
green='\e[0;32m'
GREEN='\e[1;32m'
yellow='\e[0;33m'
YELLOW='\e[1;33m'
purple='\e[0;35m'
PURPLE='\e[1;35m'
white='\e[0;37m'
WHITE='\e[1;37m'
blue='\e[0;34m'
BLUE='\e[1;34m'
cyan='\e[0;36m'
CYAN='\e[1;36m'
NC='\e[0m'

# Allows us to say things using colors so its easy to see in the console
say() {
    echo -e "${RED}[${yellow}*** ${CYAN}${1} ${yellow}***${RED}]${NC}"
}

# If we have an openwrt directory, we want to start fresh so alert us and exit
[ -d "${BASEDIR}/openwrt" ] && { say "Found existing openwrt directory, please delete it before running this script"; exit 1; }

# Clone openwrt from its git repo and fetch the branch we want to compile
say "Cloning openwrt"
git clone https://git.openwrt.org/openwrt/openwrt.git
cd openwrt
git fetch -t
say "Checking out OpenWRT ${OPENWRT_VERSION}"
git checkout v${OPENWRT_VERSION}

# If we have any patches to install, do it now
say "Running Patches"
if [ -d "${BASEDIR}/patches" ]; then
    for patch in $(find "${BASEDIR}/patches" -type f -name '*.patch'); do
        say "Applying patch ${patch}"
        patch -p1 < "${patch}"
    done
fi

# Create our feeds.conf to use the one always up to date
say "Creating our own feeds.conf"
cat << EOF > feeds.conf
src-git-full packages https://git.openwrt.org/feed/packages.git;${OPENWRT_PACKAGES_BRANCH}
src-git-full luci https://git.openwrt.org/project/luci.git;${OPENWRT_PACKAGES_BRANCH}
src-git-full routing https://git.openwrt.org/feed/routing.git;${OPENWRT_PACKAGES_BRANCH}
src-git-full telephony https://git.openwrt.org/feed/telephony.git;${OPENWRT_PACKAGES_BRANCH}
EOF

# Run feed commands pre-build, do this before creating our .config as it did not work when ran after
say "Updating and Installing Feeds"
./scripts/feeds update -a
./scripts/feeds install -a

# Copy in the custom files directory if it exists - this adds our scripts and files to openwrt
[ -d "${BASEDIR}/files" ] && { say "Copying our custom files into openwrt folder"; cp -R "${BASEDIR}/files/" "${BASEDIR}/openwrt/"; } || { say "No files directory found"; exit 1; }

# Download our "base" .config from openwrt
say "Fetching our .config"
wget https://downloads.openwrt.org/releases/"${OPENWRT_VERSION}"/targets/rockchip/armv8/config.buildinfo -O .config

# Write out our custom flags to the existing .config
say "Set build to only be for our selected board"
cat << EOF >> .config
CONFIG_TARGET_KERNEL_PARTSIZE=1000
CONFIG_TARGET_ROOTFS_PARTSIZE=13000
CONFIG_TARGET_rockchip_armv8_DEVICE_radxa_rock-pi-4=y
CONFIG_HAS_SUBTARGETS=y
CONFIG_HAS_DEVICES=y
CONFIG_TARGET_BOARD="rockchip"
CONFIG_TARGET_SUBTARGET="armv8"
CONFIG_TARGET_PROFILE="DEVICE_radxa_rock-pi-4"
CONFIG_TARGET_ARCH_PACKAGES="aarch64_generic"
CONFIG_TARGET_ROOTFS_EXT4FS=n
CONFIG_TARGET_IMAGES_GZIP=n
CONFIG_TARGET_ROOTFS_SQUASHFS=y
CONFIG_BRCMFMAC_SDIO=y
EOF

# Write the packages we want to install to the .config
say "Fixing our our .config"
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
    say "Adding ${PACKAGE} to .config"
    echo "CONFIG_PACKAGE_${PACKAGE}=y" >> .config
done

# Tell openwrt not to compile for multiple boards
sed -i "s/CONFIG_TARGET_MULTI_PROFILE=y/CONFIG_TARGET_MULTI_PROFILE=n/g" .config

# Generate our final .config for image building
say "Running make defconfig to generate .config"
make defconfig

# Go forth and build our OpenWRT image
say "Running the actual make process with $(nproc) processors"
make -j$(nproc)
