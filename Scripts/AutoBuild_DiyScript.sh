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
}

Diy-Part1() {
	Diy_Part1_Base

	Update_Makefile xray-core package/lean/helloworld/xray-core
	Update_Makefile exfat package/kernel/exfat

	ExtraPackages git other OpenClash https://github.com/vernesong master
	ExtraPackages git other openwrt-passwall https://github.com/xiaorouji main
	ExtraPackages git other luci-app-argon-config https://github.com/jerrykuku
	ExtraPackages git other luci-app-adguardhome https://github.com/Hyy2001X
	ExtraPackages git other luci-app-shutdown https://github.com/Hyy2001X
	ExtraPackages svn other luci-app-smartdns https://github.com/immortalwrt/immortalwrt/trunk/package/ntlf9t
	ExtraPackages git other luci-app-serverchan https://github.com/tty228
	ExtraPackages svn other luci-app-socat https://github.com/Lienol/openwrt-package/trunk
	ExtraPackages svn other luci-app-usb3disable https://github.com/immortalwrt/luci/trunk/applications
	ExtraPackages svn other luci-app-eqos https://github.com/immortalwrt/immortalwrt/trunk/package/ntlf9t
	ExtraPackages git other luci-app-bearDropper https://github.com/NateLol
	ExtraPackages git other luci-app-onliner https://github.com/rufengsuixing
}

Diy-Part2() {
	Diy_Part2_Base
	ExtraPackages svn other/../../feeds/packages/admin netdata https://github.com/openwrt/packages/trunk/admin

	Replace_File Customize/uhttpd.po feeds/luci/applications/luci-app-uhttpd/po/zh-cn
	Replace_File Customize/webadmin.po package/lean/luci-app-webadmin/po/zh-cn
	Replace_File Customize/mwan3.config package/feeds/packages/mwan3/files/etc/config mwan3

	case ${TARGET_PROFILE} in
	d-team_newifi-d2)
		Replace_File Customize/mac80211.sh package/kernel/mac80211/files/lib/wifi
		Replace_File Customize/system_newifi-d2 package/base-files/files/etc/config system
		Replace_File Customize/102-mt7621-fix-cpu-clk-add-clkdev.patch target/linux/ramips/patches-5.4
	;;
	*)
		Replace_File Customize/system_common package/base-files/files/etc/config system
	;;
	esac
}

Diy-Part3() {
	Diy_Part3_Base
}
