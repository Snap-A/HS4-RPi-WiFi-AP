#! /usr/bin/env bash
###
# Apply adjustments to HomeSeer 'root' image
#
# - Adjust speaker setup to use USB speaker instead of internal one.
#
####
# Platform: Raspian RPi 32bit
####

function Usage()
{
    echo "Usage: $0 [-h] <output path>"
    echo ""
    echo "This script adjusts the HomeSeer for RPi root fs image with"
    echo "new or changed files. This is done to in order to create a WiFi Access Point (AP)."
    echo ""
    echo "NOTE: You must run this script as 'root' or with the 'sudo' tool!"
}

if [ "$1" == "-h" ]; then
    Usage
    exit;
fi

if [ -z ${1} ]; then
    echo "Usage: $0 [-h] <output path>"
    exit
fi

ROOT_FS=${1}

###
# We need these paths
OUT_IMG=${ROOT_FS}
INP_IMG=${PWD}

###
INP_DNSB=${INP_IMG}/dnsmasq_base_img.tgz
INP_DNS=${INP_IMG}/dnsmasq_img.tgz
INP_HAPD=${INP_IMG}/hostapd_img.tgz

## Exists! INP_LSSL=${INP_IMG}/libssl_img.tgz
## Exists! INP_NLR=${INP_IMG}/libnl-route_img.tgz

function installTAR()
{
    local SRC=$1
    local DST=$2

    # Extract all files
    rm -rf tmp
    mkdir tmp
    tar -xf ${SRC} -C tmp

    # Copy files
    mkdir -p ${DST}
    
    cd tmp
    cp -a * ${DST}/
    cd ..
}

######
# MAIN
######

###
# Sanity

if [ ! -e ${OUT_IMG}/lib/systemd/system ]; then
    echo "The directory '${OUT_IMG}' seem invalid. Did find root filesystem"
    exit
fi
if [ ! -e ${OUT_IMG}/etc/systemd/system/multi-user.target.wants ]; then
    echo "The directory '${OUT_IMG}' seem invalid. Did find root filesystem"
    exit
fi

###
# Add 'systemd' hostapd scripts
if [ ! -f ${OUT_IMG}/lib/systemd/system/hostapd.service ]; then
  echo "Enable hostapd: AP on 192.168.64.x"
  cp ${INP_IMG}/hostapd.service ${OUT_IMG}/lib/systemd/system/
  cp ${INP_IMG}/hostapd@.service ${OUT_IMG}/lib/systemd/system/

  # hostapd
  if [ -e ${INP_HAPD} ]; then
    echo "Seting up Wifi AP..."

    installTAR ${INP_HAPD} ${OUT_IMG}
    installTAR ${INP_DNSB} ${OUT_IMG}
    installTAR ${INP_DNS} ${OUT_IMG}

    # Set US WiFi region
    mkdir -p ${OUT_IMG}/etc/wpa_supplicant/
    if [ -e ${OUT_IMG}/etc/wpa_supplicant/wpa_supplicant.conf ]; then
	mv ${OUT_IMG}/etc/wpa_supplicant/wpa_supplicant.conf ${OUT_IMG}/etc/wpa_supplicant/wpa_supplicant.conf_orig
    fi
    cp ${INP_IMG}/wpa_supplicant_US.conf ${OUT_IMG}/etc/wpa_supplicant/wpa_supplicant.conf

    # Disable WLAN0 use to DHCP client
    if [ -e ${OUT_IMG}/etc/dhcpcd.conf ]; then
	mv ${OUT_IMG}/etc/dhcpcd.conf ${OUT_IMG}/etc/dhcpcd.conf_orig
    fi
    cp ${INP_IMG}/dhcpcd_AP.conf ${OUT_IMG}/etc/dhcpcd.conf

    # Set 192.168.64.1 fixed IP
    mkdir -p ${OUT_IMG}/etc/network/
    if [ -e ${OUT_IMG}/etc/network/interfaces ]; then
	mv ${OUT_IMG}/etc/network/interfaces ${OUT_IMG}/etc/network/interfaces_orig
    fi
    cp ${INP_IMG}/interfaces_64 ${OUT_IMG}/etc/network/interfaces

    # Set 192.168.64.1 DNS
    cp ${INP_IMG}/dnsmasq_64.conf ${OUT_IMG}/etc/dnsmasq.conf

    # Set Wifi WPA password and protect file
    mkdir -p ${OUT_IMG}/etc/hostapd/
    cp ${INP_IMG}/hostapd_ZwavePI.conf ${OUT_IMG}/etc/hostapd/hostapd.conf
    chmod 0600 ${OUT_IMG}/etc/hostapd/hostapd.conf
    
    echo "Done Wifi AP"

    ### Systemd syslinks
    #
    echo "Setting up systemd config..."
    pushd ${OUT_IMG}/etc/systemd

    # hostapd
    cd system/multi-user.target.wants
    ln -s /lib/systemd/system/hostapd.service .
    cd ../..

    # dnsmasq
    cd system/multi-user.target.wants
    ln -s /lib/systemd/system/dnsmasq.service .
    cd ../..

    popd
    echo "Systemd config done."
  fi
fi

echo "Syncing image..."
sync
sleep 2
echo "Done"
