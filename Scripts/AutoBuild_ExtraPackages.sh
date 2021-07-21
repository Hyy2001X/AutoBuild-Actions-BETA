#!/bin/bash
# AutoBuild Module by Hyy2001 <https://github.com/Hyy2001X/AutoBuild-Actions>
# AutoBuild ExtraPackages

# 推荐使用的 case 判断参数:
# OP_Maintainer		Openwrt 源码作者,例如 [coolsnowwolf] [openwrt] [lienol/Lienol] [immortalwrt]
# OP_REPO_NAME		Openwrt 仓库名称,例如 [lede] [openwrt] [immortalwrt]
# OP_BRANCH			Openwrt 源码分支,例如 [master] [main] [openwrt-21.02] [v21.02.0-rc3] ...
# TARGET_PROFILE	设备名称,例如 [asus_rt-acrh17] [d-team_newifi-d2] [redmi_ax6] ...
# TARGET_BOARD		设备架构,例如 [x86] [ramips] [ipq807x] [ath79] ...

## coolsnowwolf:master 通用软件包
case "${OP_Maintainer},${OP_BRANCH}" in
coolsnowwolf,master)
	AddPackage svn other luci-app-smartdns kenzok8/openwrt-packages/trunk
	AddPackage git other luci-app-serverchan tty228
	AddPackage svn other luci-app-socat Lienol/openwrt-package/trunk
	AddPackage git other luci-app-onliner Hyy2001X
	AddPackage git other luci-app-adguardhome Hyy2001X
	AddPackage svn other luci-app-eqos kenzok8/openwrt-packages/trunk
	AddPackage git other OpenClash vernesong master
	AddPackage git other luci-app-adblock-plus small-5 master
;;
esac

## coolsnowwolf:master 设备独有软件包
case "${TARGET_PROFILE},${OP_Maintainer},${OP_BRANCH}" in
asus_rt-acrh17,coolsnowwolf,master)
	AddPackage git other luci-app-usb3disable rufengsuixing
;;
d-team_newifi-d2,coolsnowwolf,master)
	AddPackage git other luci-app-usb3disable rufengsuixing
	# AddPackage svn package/kernel mt76 openwrt/openwrt/trunk/package/kernel
;;
x86_64,coolsnowwolf,master)
	AddPackage git other openwrt-passwall xiaorouji main
	AddPackage git other luci-app-shutdown Hyy2001X master
	# AddPackage svn other luci-app-ddnsto linkease/nas-packages/trunk/luci
	# AddPackage svn other ddnsto linkease/nas-packages/trunk/network/services
;;
esac