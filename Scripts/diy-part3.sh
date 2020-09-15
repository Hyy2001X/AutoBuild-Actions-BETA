#!/bin/bash

TARGET_BOARD=ramips
TARGET_SUBTARGET=mt7621
TARGET_PROFILE=d-team_newifi-d2

Compile_Time=`date +'%Y-%m-%d %H:%M:%S'`
Version=`egrep -o "R[0-9]+\.[0-9]+\.[0-9]+" ./package/lean/default-settings/files/zzz-default-settings`
Default_Firmware=openwrt-$TARGET_BOARD-$TARGET_SUBTARGET-$TARGET_PROFILE-squashfs-sysupgrade.bin
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
