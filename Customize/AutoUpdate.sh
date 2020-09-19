#!/bin/bash
# https://github.com/Hyy2001X/AutoBuild-Actions
# AutoBuild Module by Hyy2001
# AutoUpdate

Author=Hyy2001
Version=V2.7-BETA
Updated=2020.09.19

Github=https://github.com/Hyy2001X/AutoBuild-Actions
Github_Tags=$Github/releases/tag/AutoUpdate
Github_Download=$Github/releases/download/AutoUpdate
TARGET_PROFILE=d-team_newifi-d2

clear
echo -e "Auto-Update Script $Version by $Author\n"
cd /etc
CURRENT_VERSION=`cat ./openwrt_date` > /dev/null 2>&1
if [ "$CURRENT_VERSION" == "" ]; then
	echo -e "警告:当前固件版本获取失败!\n"
	CURRENT_VERSION=未知
fi
CURRENT_DEVICE=`cat ./openwrt_device` > /dev/null 2>&1
if [ "$CURRENT_DEVICE" == "" ]; then
	echo -e "警告:当前设备名称获取失败,使用预设设备名称[$TARGET_PROFILE]!\n"
	CURRENT_DEVICE=$TARGET_PROFILE
fi
cd /tmp
echo "正在获取云端固件版本..."
Check_Version=`wget --no-check-certificate -q $Github_Tags -O - | egrep -o 'R[0-9]+.[0-9]+.[0-9]+.[0-9]+.bin' | awk 'NR==1'`
if [ "$Check_Version" == "" ]; then
	echo -e "\n...未获取到任何信息,请稍后重试!"
	exit
fi
GET_Version=`wget --no-check-certificate -q $Github_Tags -O - | egrep -o 'R[0-9]+.[0-9]+.[0-9]+.[0-9]+' | awk 'NR==1'`
if [ "$GET_Version" == "" ]; then
	echo -e "\n...云端固件版本获取失败!"
	exit
fi
echo -e "\n当前固件版本:$CURRENT_VERSION"
echo -e "云端固件版本:$GET_Version\n"
if [ $CURRENT_VERSION == $GET_Version ];then
	read -p "已是最新版本,是否强制更新固件?[Y/N]:" Choose
	case $Choose in
	Y)
		echo -e "\n开始强制更新固件...\n"
	;;
	y)
		echo -e "\n开始强制更新固件...\n"
	;;
	*)
		echo -e "\n用户已取消强制更新,即将退出更新程序..."
		sleep 2
		exit
	esac
fi
Firmware_Info=AutoBuild-$CURRENT_DEVICE-Lede-$GET_Version
Firmware=${Firmware_Info}.bin
Firmware_Detail=${Firmware_Info}.detail
echo "云端固件名称:$Firmware"
NETWORK=`curl -I -s --connect-timeout 5 www.google.com -w %{http_code} |  tail -n1`
if [ ! "$NETWORK" == 200 ];then
	echo -e "\nGoogle 连接失败,可能导致固件下载速度缓慢!"
fi
echo -e "\n正在下载固件,请耐心等待..."
wget --no-check-certificate -q $Github_Download/$Firmware -O $Firmware
if [ ! "$?" == 0 ]; then
	echo "...下载失败,请检查网络后重试!"
	exit
fi
echo "...下载成功!"
echo "固件大小:$(du -h $Firmware | awk '{print $1}')"
echo -e "\n正在下载固件详细信息..."
wget --no-check-certificate -q $Github_Download/$Firmware_Detail -O $Firmware_Detail
if [ ! "$?" == 0 ]; then
	echo "...下载失败,请检查网络后重试!"
	exit
fi
echo "...下载成功!"
GET_MD5=`awk -F'[ :]' '/MD5/ {print $2;exit}' $Firmware_Detail`
CURRENT_MD5=`md5sum $Firmware | cut -d ' ' -f1`
echo -e "\n当前文件MD5:$CURRENT_MD5"
echo -e "云端文件MD5:$GET_MD5\n"
if [ "$GET_MD5" == "" ] || [ "$CURRENT_MD5" == "" ];then
	echo "MD5获取失败!"
	exit
fi
if [ ! "$GET_MD5" == "$CURRENT_MD5" ];then
	echo "MD5对比不通过,请检查网络后重试!"
	exit
fi
echo "MD5对比通过,准备升级固件..."
sleep 3
echo -e "\n开始升级固件,请耐心等待...\n"
sysupgrade $Firmware
