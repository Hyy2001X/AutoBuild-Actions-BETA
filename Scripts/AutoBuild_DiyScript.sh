#!/bin/bash
# AutoBuild Module by Hyy2001 <https://github.com/Hyy2001X/AutoBuild-Actions>
# AutoBuild DiyScript

Diy_Core() {
	Author=Hyy2001
	Short_Firmware_Date=true
	Default_LAN_IP=192.168.1.1

	INCLUDE_AutoBuild_Features=true
	INCLUDE_DRM_I915=true
	INCLUDE_Argon=true
	INCLUDE_Obsolete_PKG_Compatible=false
	
	Load_CustomPackages_List=true
	Checkout_Virtual_Images=false
}

Firmware-Diy() {
	case "${TARGET_PROFILE}" in
	d-team_newifi-d2)
		Copy CustomFiles/mac80211.sh package/kernel/mac80211/files/lib/wifi
		Copy CustomFiles/system_${TARGET_PROFILE} package/base-files/files/etc/config system
	;;
	esac
	case "${TARGET_BOARD}" in
	ramips)
		sed -i 's/5.10/5.4/' target/linux/ramips/Makefile
	;;
	esac
}