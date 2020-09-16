#!/bin/bash
# https://github.com/Hyy2001X/AutoBuild-Actions
# AutoBuild Module by Hyy2001
# AutoBuild Actions

Diy_Core() {
Author=Hyy2001
Github=https://github.com/Hyy2001X
AutoUpdate_Github=https://github.com/Hyy2001X/Openwrt-AutoUpdate
Default_File=./package/lean/default-settings/files/zzz-default-settings
TARGET_BOARD=ramips
TARGET_SUBTARGET=mt7621
TARGET_PROFILE=d-team_newifi-d2
TARGET_ROOTFS=squashfs-sysupgrade.bin

Version=`egrep -o "R[0-9]+\.[0-9]+\.[0-9]+" $Default_File`
Compile_Date=`date +'%Y/%m/%d'`
Compile_Time=`date +'%Y-%m-%d %H:%M:%S'`
}

ExtraPackages() {
[ -d ./package/lean/$2 ] && rm -rf ./package/lean/$2
[ -d ./$2 ] && rm -rf ./$2
while [ ! -f $2/Makefile ]
do
	echo "[$(date "+%H:%M:%S")] Checking out $2 from $3 ..."
	if [ $1 == git ];then
		git clone -b $4 $3/$2 $2 > /dev/null 2>&1
	else
		svn checkout $3/$2 $2 > /dev/null 2>&1
	fi
	if [ -f $2/Makefile ] || [ -f $2/README* ];then
		echo "[$(date "+%H:%M:%S")] Package $2 detected!"
		if [ $2 == OpenClash ];then
			mv $2/luci-app-openclash ./package/lean
		elif [ $2 == Openwrt-AutoUpdate ];then
			mv $2/AutoUpdate.sh ./package/base-files/files/bin
		else
			mv $2 ./package/lean
		fi
		rm -rf ./$2 > /dev/null 2>&1
		break
	else
		echo "[$(date "+%H:%M:%S")] Checkout failed,retry in 3s."
		rm -rf ./$2 > /dev/null 2>&1
		sleep 3
	fi
done
}

Diy-Part1() {
sed -i "s/#src-git helloworld/src-git helloworld/g" feeds.conf.default
[ ! -d ./package/lean ] && mkdir ./package/lean
ExtraPackages git luci-theme-argon https://github.com/jerrykuku 18.06
ExtraPackages svn luci-app-adguardhome https://github.com/Lienol/openwrt/trunk/package/diy
ExtraPackages svn luci-app-smartdns https://github.com/project-openwrt/openwrt/trunk/package/ntlf9t
ExtraPackages svn smartdns https://github.com/project-openwrt/openwrt/trunk/package/ntlf9t
ExtraPackages git OpenClash https://github.com/vernesong master
ExtraPackages git Openwrt-AutoUpdate https://github.com/Hyy2001X master
}

Diy-Part2() {
echo "[$(date "+%H:%M:%S")] Current Openwrt version: $Version-`date +%Y%m%d`"
if [ ! $(grep -o "Compiled by $Author" $Default_File | wc -l) = "1" ];then
	sed -i "s?$Version?$Version Compiled by $Author [$Compile_Date]?g" $Default_File
fi
echo "$Version-`date +%Y%m%d`" > ./package/base-files/files/etc/openwrt_date
echo "[$(date "+%H:%M:%S")] Writing $Version-`date +%Y%m%d` to ./package/base-files/files/etc/openwrt_date ..."
}

Diy-Part3() {
Default_Firmware=openwrt-$TARGET_BOARD-$TARGET_SUBTARGET-$TARGET_PROFILE-$TARGET_ROOTFS
AutoBuild_Firmware=AutoBuild-$TARGET_PROFILE-Lede-$Version`(date +-%Y%m%d.bin)`
AutoBuild_Detail=AutoBuild-$TARGET_PROFILE-Lede-$Version`(date +-%Y%m%d.detail)`
mkdir -p ./bin/Firmware
mv ./bin/targets/$TARGET_BOARD/$TARGET_SUBTARGET/$Default_Firmware ./bin/Firmware/$AutoBuild_Firmware
cd ./bin/Firmware
Firmware_Size=`ls -l $AutoBuild_Firmware | awk '{print $5}'`
Firmware_Size_MB=`awk 'BEGIN{printf "固件大小:%.2fMB\n",'$((Firmware_Size))'/1000000}'`
Firmware_MD5=`md5sum $AutoBuild_Firmware | cut -d ' ' -f1`
Firmware_SHA256=`sha256sum $AutoBuild_Firmware | cut -d ' ' -f1`
echo "$Firmware_Size_MB" > ./$AutoBuild_Detail
echo -e "编译日期:$Compile_Time\n" >> ./$AutoBuild_Detail
echo -e "MD5:$Firmware_MD5\nSHA256:$Firmware_SHA256" >> ./$AutoBuild_Detail
cd ../..
}
