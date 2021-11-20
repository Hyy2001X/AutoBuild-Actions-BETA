#!/bin/bash
# AutoBuild Module by Hyy2001 <https://github.com/Hyy2001X/AutoBuild-Actions>
# AutoBuild DiyScript

Firmware_Diy_Core() {

	Author=AUTO
	Author_URL=AUTO
	Default_IP="192.168.1.1"
	Banner_Message="Powered by AutoBuild-Actions"

	Short_Firmware_Date=true
	Checkout_Virtual_Images=false
	Firmware_Format=AUTO
	REGEX_Skip_Checkout="packages|buildinfo|sha256sums|manifest|kernel|rootfs|factory"

	INCLUDE_AutoBuild_Features=true
	INCLUDE_DRM_I915=true
	INCLUDE_Original_OpenWrt_Compatible=false
}

Firmware_Diy() {

	# 请在该函数内定制固件, 建议使用专业文本编辑器进行修改

	# 可用预设变量, 其他可用变量请参考运行日志
	# ${OP_AUTHOR}			OpenWrt 源码作者
	# ${OP_REPO}			OpenWrt 仓库名称
	# ${OP_BRANCH}			OpenWrt 源码分支
	# ${TARGET_PROFILE}		设备名称, 例如: d-team_newifi-d2
	# ${TARGET_BOARD}		设备架构, 例如: ramips

	# ${Home}				OpenWrt 源码位置
	# ${FEEDS_CONF}			[feeds.conf.default] 文件
	# ${CustomFiles}		仓库中的 /CustomFiles 绝对路径
	# ${Scripts}			仓库中的 /Scripts 绝对路径
	# ${FEEDS_LUCI}			OpenWrt 源码目录下的 package/feeds/luci
	# ${FEEDS_PKG}			OpenWrt 源码目录下的 package/feeds/packages
	# ${BASE_FILES}			俗称替换大法的路径, 位于 package/base-files/files

	case "${OP_AUTHOR}/${OP_REPO}:${OP_BRANCH}" in
	coolsnowwolf/lede:master)
		sed -i "s?/bin/login?/usr/libexec/login.sh?g" ${FEEDS_PKG}/ttyd/files/ttyd.config
		AddPackage git lean luci-theme-argon jerrykuku 18.06
		AddPackage git lean luci-app-argon-config jerrykuku master
		AddPackage git other AutoBuild-Packages Hyy2001X master
		AddPackage svn other luci-app-smartdns kenzok8/openwrt-packages/trunk
		AddPackage svn other luci-app-socat Lienol/openwrt-package/trunk
		AddPackage svn other luci-app-eqos kenzok8/openwrt-packages/trunk
		AddPackage git other OpenClash vernesong master
		# AddPackage git other OpenAppFilter destan19 master
		# AddPackage svn other luci-app-ddnsto linkease/nas-packages/trunk/luci
		# AddPackage svn other ddnsto linkease/nas-packages/trunk/network/services

		case "${TARGET_PROFILE}" in
		d-team_newifi-d2)
			patch -i ${CustomFiles}/${TARGET_PROFILE}_mac80211.patch package/kernel/mac80211/files/lib/wifi/mac80211.sh
			Copy ${CustomFiles}/${TARGET_PROFILE}_system ${BASE_FILES}/etc/config system
			sed -i "/DEVICE_COMPAT_VERSION := 1.1/d" target/linux/ramips/image/mt7621.mk
			AddPackage git other luci-app-usb3disable rufengsuixing master
		;;
		x86_64)
			cat >> ${Version_File} <<EOF

sed -i 's#mirrors.cloud.tencent.com/lede#downloads.immortalwrt.cnsztl.eu.org#g' /etc/opkg/distfeeds.conf
sed -i 's#18.06.9/##g' /etc/opkg/distfeeds.conf
sed -i 's#releases/#snapshots/#g' /etc/opkg/distfeeds.conf
EOF
			AddPackage git other openwrt-passwall xiaorouji main
			rm -rf packages/lean/autocore
			AddPackage git lean autocore-modify Hyy2001X master
		;;
		esac
	;;
	esac
}
