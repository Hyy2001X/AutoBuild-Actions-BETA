#!/bin/bash
# AutoBuild Module by Hyy2001 <https://github.com/Hyy2001X/AutoBuild-Actions>
# AutoBuild DiyScript

Diy_Core() {
	Author=Hyy2001
	Default_LAN_IP=192.168.1.1
	Load_CustomPackages_List=true
	Short_Firmware_Date=true
	Checkout_Virtual_Images=false

	INCLUDE_AutoBuild_Features=true
	INCLUDE_DRM_I915=true
	INCLUDE_Argon=true
	INCLUDE_Obsolete_PKG_Compatible=false
}

Firmware-Diy() {
	case "${TARGET_PROFILE}" in
	d-team_newifi-d2)
		Copy CustomFiles/mac80211.sh package/kernel/mac80211/files/lib/wifi
		Copy CustomFiles/system_${TARGET_PROFILE} package/base-files/files/etc/config system
	;;
	esac
	case "${OP_Maintainer}/${OP_REPO_NAME}:${OP_BRANCH}" in
	coolsnowwolf/lede:master)
		sed -i "s?/bin/login?/usr/libexec/login.sh?g" package/feeds/packages/ttyd/files/ttyd.config
	;;
	esac
}