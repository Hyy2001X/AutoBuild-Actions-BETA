#!/bin/bash
# https://github.com/Hyy2001X/AutoBuild-Actions
# AutoBuild Module by Hyy2001
# AutoBuild DiyScript

Diy_Core() {
	Author=Hyy2001
	Default_Device=

	INCLUDE_AutoUpdate=true
	INCLUDE_AutoBuild_Tools=true
	INCLUDE_DRM_I915=true
	INCLUDE_Obsolete_PKG_Compatible=
}

Firmware-Diy() {
	Update_Makefile exfat package/kernel/exfat
	Replace_File CustomFiles/webadmin.po package/lean/luci-app-webadmin/po/zh-cn

	case ${TARGET_PROFILE} in
	d-team_newifi-d2)
		Replace_File CustomFiles/mac80211.sh package/kernel/mac80211/files/lib/wifi
		Replace_File CustomFiles/system_newifi-d2 package/base-files/files/etc/config system
		Replace_File CustomFiles/Patches/102-mt7621-fix-cpu-clk-add-clkdev.patch target/linux/ramips/patches-5.4
	;;
	*)
		Replace_File CustomFiles/system_common package/base-files/files/etc/config system
	;;
	esac
}
