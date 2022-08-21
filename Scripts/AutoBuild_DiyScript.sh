#!/bin/bash
# AutoBuild Module by Hyy2001 <https://github.com/Hyy2001X/AutoBuild-Actions>
# AutoBuild DiyScript

Firmware_Diy_Core() {

	Author=AUTO
	Author_URL=AUTO
	Default_Flag=AUTO
	Default_IP="192.168.1.1"
	Default_Title="Powered by AutoBuild-Actions"

	Short_Fw_Date=true
	x86_Full_Images=false
	Fw_Format=false
	Regex_Skip="packages|buildinfo|sha256sums|manifest|kernel|rootfs|factory|itb|profile"

	AutoBuild_Features=true
}

Firmware_Diy() {

	# 请在该函数内定制固件

	# 可用预设变量, 其他可用变量请参考运行日志
	# ${OP_AUTHOR}			OpenWrt 源码作者
	# ${OP_REPO}			OpenWrt 仓库名称
	# ${OP_BRANCH}			OpenWrt 源码分支
	# ${TARGET_PROFILE}		设备名称
	# ${TARGET_BOARD}		设备架构
	# ${TARGET_FLAG}		固件名称后缀

	# ${WORK}			OpenWrt 源码位置
	# ${CONFIG_FILE}		使用的配置文件名称
	# ${FEEDS_CONF}			OpenWrt 源码目录下的 feeds.conf.default 文件
	# ${CustomFiles}		仓库中的 /CustomFiles 绝对路径
	# ${Scripts}			仓库中的 /Scripts 绝对路径
	# ${FEEDS_LUCI}			OpenWrt 源码目录下的 package/feeds/luci 目录
	# ${FEEDS_PKG}			OpenWrt 源码目录下的 package/feeds/packages 目录
	# ${BASE_FILES}			OpenWrt 源码目录下的 package/base-files/files 目录

	case "${OP_AUTHOR}/${OP_REPO}:${OP_BRANCH}" in
	coolsnowwolf/lede:master)
		cat >> ${Version_File} <<EOF

sed -i '/check_signature/d' /etc/opkg.conf

sed -i 's/\"services\"/\"nas\"/g' /usr/lib/lua/luci/controller/aliyundrive-webdav.lua
sed -i 's/services/nas/g' /usr/lib/lua/luci/view/aliyundrive-webdav/aliyundrive-webdav_log.htm
sed -i 's/services/nas/g' /usr/lib/lua/luci/view/aliyundrive-webdav/aliyundrive-webdav_status.htm

sed -i 's/\"services\"/\"vpn\"/g' /usr/lib/lua/luci/controller/v2ray_server.lua
sed -i 's/\"services\"/\"vpn\"/g' /usr/lib/lua/luci/model/cbi/v2ray_server/index.lua
sed -i 's/\"services\"/\"vpn\"/g' /usr/lib/lua/luci/model/cbi/v2ray_server/user.lua
sed -i 's/services/vpn/g' /usr/lib/lua/luci/view/v2ray_server/log.htm
sed -i 's/services/vpn/g' /usr/lib/lua/luci/view/v2ray_server/users_list_status.htm
sed -i 's/services/vpn/g' /usr/lib/lua/luci/view/v2ray_server/users_list_status.htm
sed -i 's/services/vpn/g' /usr/lib/lua/luci/view/v2ray_server/v2ray.htm

if [ -z "\$(grep "REDIRECT --to-ports 53" /etc/firewall.user 2> /dev/null)" ]
then
	echo '#iptables -t nat -A PREROUTING -p udp --dport 53 -j REDIRECT --to-ports 53' >> /etc/firewall.user
	echo '#iptables -t nat -A PREROUTING -p tcp --dport 53 -j REDIRECT --to-ports 53' >> /etc/firewall.user
	echo '#[ -n "\$(command -v ip6tables)" ] && ip6tables -t nat -A PREROUTING -p udp --dport 53 -j REDIRECT --to-ports 53' >> /etc/firewall.user
	echo '#[ -n "\$(command -v ip6tables)" ] && ip6tables -t nat -A PREROUTING -p tcp --dport 53 -j REDIRECT --to-ports 53' >> /etc/firewall.user
fi
exit 0
EOF
		sed -i "s?/bin/login?/usr/libexec/login.sh?g" ${FEEDS_PKG}/ttyd/files/ttyd.config
		sed -i 's/luci-theme-bootstrap/luci-theme-argon-mod/g' feeds/luci/collections/luci/Makefile
		sed -i '/uci commit luci/i\uci set luci.main.mediaurlbase="/luci-static/argon-mod"' $(PKG_Finder d package default-settings)/files/zzz-default-settings
		# AddPackage git lean luci-theme-argon jerrykuku 18.06
		AddPackage git lean luci-app-argon-config jerrykuku master
		AddPackage svn other luci-app-smartdns immortalwrt/luci/branches/openwrt-18.06/applications
		sed -i 's/..\/..\//\$\(TOPDIR\)\/feeds\/luci\//g' $(PKG_Finder d package luci-app-smartdns)/Makefile
		AddPackage svn other luci-app-eqos immortalwrt/luci/branches/openwrt-18.06/applications
		sed -i 's/..\/..\//\$\(TOPDIR\)\/feeds\/luci\//g' $(PKG_Finder d package luci-app-eqos)/Makefile
		# AddPackage svn other luci-app-socat immortalwrt/luci/branches/openwrt-18.06/applications
		# sed -i 's/..\/..\//\$\(TOPDIR\)\/feeds\/luci\//g' $(PKG_Finder d package luci-app-socat)/Makefile
		AddPackage git other OpenClash vernesong master
		AddPackage git other luci-app-ikoolproxy iwrt main
		AddPackage git other helloworld fw876 master
		sed -i 's/143/143,8080,8443,6969,1337,6672/' $(PKG_Finder d package luci-app-ssr-plus)/root/etc/init.d/shadowsocksr

		patch < ${CustomFiles}/Patches/fix_shadowsocksr_alterId.patch -p1 -d ${WORK}
		patch < ${CustomFiles}/Patches/fix_ntfs3_conflict_with_antfs.patch -p1 -d ${WORK}
		patch < ${CustomFiles}/Patches/fix_aria2_auto_create_download_path.patch -p1 -d ${WORK}

		case "${TARGET_BOARD}" in
		ramips)
			sed -i "/DEVICE_COMPAT_VERSION := 1.1/d" target/linux/ramips/image/mt7621.mk
			Copy ${CustomFiles}/Depends/automount $(PKG_Finder d "package" automount)/files 15-automount
		;;
		esac

		case "${TARGET_PROFILE}" in
		d-team_newifi-d2)
			Copy ${CustomFiles}/${TARGET_PROFILE}_system ${BASE_FILES}/etc/config system
			patch < ${CustomFiles}/d-team_newifi-d2_mt76_dualband.patch -p1 -d ${WORK}
		;;
		x86_64)
			AddPackage git passwall-depends openwrt-passwall xiaorouji packages
			AddPackage git passwall-luci openwrt-passwall xiaorouji luci
			rm -rf packages/lean/autocore
			AddPackage git lean autocore-modify Hyy2001X master
			sed -i -- 's:/bin/ash:'/bin/bash':g' ${BASE_FILES}/etc/passwd
			patch < ${CustomFiles}/Patches/upgrade_intel_igpu_drv.patch -p1 -d ${WORK}
		;;
		esac
	;;
	immortalwrt/immortalwrt*)
		sed -i "s?/bin/login?/usr/libexec/login.sh?g" ${FEEDS_PKG}/ttyd/files/ttyd.config
	;;
	esac
}
