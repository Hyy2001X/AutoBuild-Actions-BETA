#!/bin/bash
# https://github.com/Hyy2001X/AutoBuild-Actions
# AutoBuild Module by Hyy2001
# AutoUpdate

Version=V3.2-b
TARGET_PROFILE=d-team_newifi-d2
Github=https://github.com/Hyy2001X/AutoBuild-Actions

function TIME() {
echo -ne "\n[$(date "+%H:%M:%S")] "
}

Github_Tags=$Github/releases/tag/AutoUpdate
Github_Download=$Github/releases/download/AutoUpdate
clear && echo "Openwrt-AutoUpdate Script $Version"
cd /etc
CURRENT_VERSION=`awk 'NR==1' ./openwrt_info > /dev/null 2>&1`
if [ "$CURRENT_VERSION" == "" ]; then
	echo -e "\n警告:当前固件版本获取失败!"
	CURRENT_VERSION=未知
fi
CURRENT_DEVICE=`awk 'NR==2' ./openwrt_info > /dev/null 2>&1`
if [ "$CURRENT_DEVICE" == "" ]; then
	echo -e "\n警告:当前设备名称获取失败,使用预设名称[$TARGET_PROFILE]"
	CURRENT_DEVICE=$TARGET_PROFILE
fi
cd /tmp
TIME && echo "正在获取云端固件版本..."
GET_Version=`wget --no-check-certificate -q $Github_Tags -O - | egrep -o 'R[0-9]+.[0-9]+.[0-9]+.[0-9]+' | awk 'NR==1'`
if [ "$GET_Version" == "" ]; then
	TIME && echo "云端固件版本获取失败!"
	exit
fi
echo -e "\n当前固件版本:$CURRENT_VERSION"
echo -e "云端固件版本:$GET_Version\n"
if [ $CURRENT_VERSION == $GET_Version ];then
	read -p "已是最新版本,是否强制更新固件?[Y/N]:" Choose
	case $Choose in
	Y)
		TIME && echo -e "开始强制更新固件...\n"
	;;
	y)
		TIME && echo -e "开始强制更新固件...\n"
	;;
	*)
		TIME &&  echo "用户已取消强制更新,即将退出更新程序..."
		sleep 2
		exit
	esac
fi
Firmware_Info="AutoBuild-${CURRENT_DEVICE}-Lede-${GET_Version}"
Firmware="${Firmware_Info}.bin"
Firmware_Detail="${Firmware_Info}.detail"
echo "云端固件名称:$Firmware"
Google_Check=`curl -I -s --connect-timeout 5 www.google.com -w %{http_code} | tail -n1`
if [ ! "$Google_Check" == 200 ];then
	TIME && echo "Google 连接失败,可能导致固件下载速度缓慢!"
fi
TIME && echo "正在下载固件,请耐心等待..."
wget -q $Github_Download/$Firmware -O $Firmware
if [ ! "$?" == 0 ]; then
	TIME && echo "下载失败,请检查网络后重试!"
	exit
fi
TIME && echo "下载成功!固件大小:$(du -h $Firmware | awk '{print $1}')B"
TIME && echo "正在下载固件详细信息..."
wget -q $Github_Download/$Firmware_Detail -O $Firmware_Detail
if [ ! "$?" == 0 ]; then
	TIME && echo "下载失败,请检查网络后重试!"
	exit
fi
GET_MD5=`awk -F'[ :]' '/MD5/ {print $2;exit}' $Firmware_Detail`
CURRENT_MD5=`md5sum $Firmware | cut -d ' ' -f1`
echo -e "\n当前固件MD5:$CURRENT_MD5"
echo "云端固件MD5:$GET_MD5"
if [ "$GET_MD5" == "" ] || [ "$CURRENT_MD5" == "" ];then
	echo -e "\nMD5获取失败!"
	exit
fi
if [ ! "$GET_MD5" == "$CURRENT_MD5" ];then
	echo -e "\nMD5对比不通过,请检查网络后重试!"
	exit
fi
TIME && echo "MD5对比通过,准备升级固件..."
sleep 3
TIME && echo -e "开始升级固件,请耐心等待...\n"
sysupgrade $Firmware
