#!/bin/bash
# AutoBuild Module by Hyy2001 <https://github.com/Hyy2001X/AutoBuild-Actions>
# AutoBuild ExtraPackages

# 推荐使用的 case 判断参数:
# OP_Maintainer		Openwrt 源码作者,例如 [coolsnowwolf] [openwrt] [lienol/Lienol] [immortalwrt]
# OP_REPO_NAME		Openwrt 仓库名称,例如 [lede] [openwrt] [immortalwrt]
# OP_BRANCH			Openwrt 源码分支,例如 [master] [main] [openwrt-21.02] [v21.02.0-rc3] ...
# TARGET_PROFILE	设备名称,例如 [asus_rt-acrh17] [d-team_newifi-d2] [redmi_ax6] ...
# TARGET_BOARD		设备架构,例如 [x86] [ramips] [ipq807x] [ath79] ...
#
# [git] AddPackage git 存放位置 仓库名称 仓库作者 分支
# [svn] AddPackage svn 存放位置 软件包名 仓库作者/仓库名称/branches/分支/路径(可选)

## e.g. 当前使用源码为 coolsnowwolf/lede:master 时添加下列软件包
case "${OP_Maintainer}/${OP_REPO_NAME}:${OP_BRANCH}" in
coolsnowwolf/lede:master)
	AddPackage git other AutoBuild-Packages Hyy2001X master
	AddPackage svn other luci-app-smartdns kenzok8/openwrt-packages/trunk
	AddPackage svn other luci-app-socat Lienol/openwrt-package/trunk
	AddPackage svn other luci-app-eqos kenzok8/openwrt-packages/trunk
	AddPackage git other OpenClash vernesong master
	# AddPackage git other OpenAppFilter destan19 master
	# AddPackage svn other luci-app-ddnsto linkease/nas-packages/trunk/luci
	# AddPackage svn other ddnsto linkease/nas-packages/trunk/network/services
	
	case "${TARGET_PROFILE}" in
	asus_rt-acrh17 | d-team_newifi-d2)
		AddPackage git other luci-app-usb3disable rufengsuixing master
	;;
	x86_64)
		AddPackage git other openwrt-passwall xiaorouji main
		rm -rf packages/lean/autocore
		AddPackage git lean autocore-modify Hyy2001X master
	;;
	esac
;;
esac