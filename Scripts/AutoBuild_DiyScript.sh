#!/bin/bash
# https://github.com/Hyy2001X/AutoBuild-Actions
# AutoBuild Module by Hyy2001
# AutoBuild DiyScript

Diy_Core() {
	Author=Hyy2001
	Default_Device=d-team_newifi-d2

	INCLUDE_AutoUpdate=true
	INCLUDE_AutoBuild_Tools=true
	INCLUDE_mt7621_OC1000MHz=true

	INCLUDE_SSR_Plus=true
	INCLUDE_Passwall=true
	INCLUDE_HelloWorld=false
	INCLUDE_Bypass=false
	INCLUDE_OpenClash=true
	INCLUDE_OAF=false
}

Diy-Part1() {
	Diy_Part1_Base

	Replace_File Customize/mac80211.sh package/kernel/mac80211/files/lib/wifi

	ExtraPackages git lean luci-theme-argon https://github.com/jerrykuku 18.06
	ExtraPackages git other luci-app-argon-config https://github.com/jerrykuku master
	ExtraPackages git other luci-app-adguardhome https://github.com/Hyy2001X master
	ExtraPackages git other luci-app-shutdown https://github.com/Hyy2001X master
	ExtraPackages svn other luci-app-smartdns https://github.com/project-openwrt/openwrt/trunk/package/ntlf9t
	ExtraPackages git other luci-app-serverchan https://github.com/tty228 master
	ExtraPackages svn other luci-app-socat https://github.com/Lienol/openwrt-package/trunk
	ExtraPackages svn other luci-app-usb3disable https://github.com/project-openwrt/openwrt/trunk/package/ctcgfw
}

Diy-Part2() {
	Diy_Part2_Base
}

Diy-Part3() {
	Diy_Part3_Base
}
