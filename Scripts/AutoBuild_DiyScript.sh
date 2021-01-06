#!/bin/bash
# https://github.com/Hyy2001X/AutoBuild-Actions
# AutoBuild Module by Hyy2001
# AutoBuild DiyScript

Diy_Core() {
	Author=Hyy2001
	Default_Device=d-team_newifi-d2
}

Diy-Part1() {
	# [ -e feeds.conf.default ] && sed -i "s/#src-git helloworld/src-git helloworld/g" feeds.conf.default
	[ ! -d package/lean ] && mkdir -p package/lean
	
	Update_Makefile xray package/lean/xray
	Update_Makefile v2ray package/lean/v2ray
	Update_Makefile v2ray-plugin package/lean/v2ray-plugin

	Replace_File Scripts/AutoUpdate.sh package/base-files/files/bin
	Replace_File Scripts/AutoBuild_Tools.sh package/base-files/files/bin
	Replace_File Customize/mac80211.sh package/kernel/mac80211/files/lib/wifi
	Replace_File Customize/system package/base-files/files/etc/config
	Replace_File Customize/banner package/base-files/files/etc

	# ExtraPackages svn network/services dnsmasq https://github.com/openwrt/openwrt/trunk/package/network/services
	# ExtraPackages svn network/services dropbear https://github.com/openwrt/openwrt/trunk/package/network/services
	# ExtraPackages svn network/services ppp https://github.com/openwrt/openwrt/trunk/package/network/services
	# ExtraPackages svn network/services hostapd https://github.com/openwrt/openwrt/trunk/package/network/services
	# ExtraPackages svn kernel mt76 https://github.com/openwrt/openwrt/trunk/package/kernel

	ExtraPackages git lean helloworld https://github.com/fw876 master
	ExtraPackages git lean luci-app-autoupdate https://github.com/Hyy2001X main
	ExtraPackages git lean luci-theme-argon https://github.com/jerrykuku 18.06
	ExtraPackages git other luci-app-argon-config https://github.com/jerrykuku master
	ExtraPackages git other luci-app-adguardhome https://github.com/Hyy2001X master
	ExtraPackages svn other luci-app-smartdns https://github.com/project-openwrt/openwrt/trunk/package/ntlf9t
	ExtraPackages svn other smartdns https://github.com/project-openwrt/openwrt/trunk/package/ntlf9t
	ExtraPackages git other OpenClash https://github.com/vernesong master
	ExtraPackages git other luci-app-serverchan https://github.com/tty228 master
	ExtraPackages svn other luci-app-socat https://github.com/project-openwrt/openwrt/trunk/package/lienol
}

Diy-Part2() {
	GET_TARGET_INFO
	Replace_File Customize/mwan3.config package/feeds/packages/mwan3/files/etc/config mwan3
	sed -i 's/143/143,25,5222/' package/lean/helloworld/luci-app-ssr-plus/root/etc/init.d/shadowsocksr
	# ExtraPackages svn feeds/packages mwan3 https://github.com/openwrt/packages/trunk/net
	echo "Author: ${Author}"
	echo "Openwrt Version: ${Openwrt_Version}"
	echo "AutoUpdate Version: ${AutoUpdate_Version}"
	echo "Router: ${TARGET_PROFILE}"
	[ -f $Default_File ] && sed -i "s?${Lede_Version}?${Lede_Version} Compiled by ${Author} [${Display_Date}]?g" $Default_File
	echo "${Openwrt_Version}" > package/base-files/files/etc/openwrt_info
	sed -i "s?Openwrt?Openwrt ${Openwrt_Version} / AutoUpdate ${AutoUpdate_Version}?g" package/base-files/files/etc/banner
}

Diy-Part3() {
	GET_TARGET_INFO
	Default_Firmware="openwrt-${TARGET_BOARD}-${TARGET_SUBTARGET}-${TARGET_PROFILE}-squashfs-sysupgrade.bin"
	AutoBuild_Firmware="AutoBuild-${TARGET_PROFILE}-${Openwrt_Version}.bin"
	AutoBuild_Detail="AutoBuild-${TARGET_PROFILE}-${Openwrt_Version}.detail"
	mkdir -p bin/Firmware
	echo "Firmware: ${AutoBuild_Firmware}"
	mv -f bin/targets/"${TARGET_BOARD}/${TARGET_SUBTARGET}/${Default_Firmware}" bin/Firmware/"${AutoBuild_Firmware}"
	_MD5=$(md5sum bin/Firmware/${AutoBuild_Firmware} | cut -d ' ' -f1)
	_SHA256=$(sha256sum bin/Firmware/${AutoBuild_Firmware} | cut -d ' ' -f1)
	echo -e "\nMD5:${_MD5}\nSHA256:${_SHA256}" > bin/Firmware/"${AutoBuild_Detail}"
}