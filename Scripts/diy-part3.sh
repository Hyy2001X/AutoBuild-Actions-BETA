#!/bin/bash

mkdir -p ./bin/Firmware
Compile_Time=`date +'%Y-%m-%d %H:%M:%S'`
Version=`egrep -o "R[0-9]+\.[0-9]+\.[0-9]+" ./package/lean/default-settings/files/zzz-default-settings`
Default_Firmware=openwrt-ramips-mt7621-d-team_newifi-d2-squashfs-sysupgrade.bin
AutoBuild_Firmware=AutoBuild-d-team_newifi-d2-Lede-$Version`(date +-%Y%m%d.bin)`
AutoBuild_Detail=AutoBuild-d-team_newifi-d2-Lede-$Version`(date +-%Y%m%d.detail)`
mv ./bin/targets/ramips/mt7621/$Default_Firmware ./bin/Firmware/$AutoBuild_Firmware
cd ./bin/Firmware
Firmware_Size=`ls -l $AutoBuild_Firmware | awk '{print $5}'`
Firmware_Size_MB=`awk 'BEGIN{printf "固件大小:%.2fMB\n",'$((Firmware_Size))'/1000000}'`
Firmware_MD5=`md5sum $AutoBuild_Firmware | cut -d ' ' -f1`
Firmware_SHA256=`sha256sum $AutoBuild_Firmware | cut -d ' ' -f1`
echo "$Firmware_Size_MB" > ./$AutoBuild_Detail
echo -e "编译日期:$Compile_Time\n" >> ./$AutoBuild_Detail
echo -e "MD5:$Firmware_MD5\nSHA256:$Firmware_SHA256" >> ./$AutoBuild_Detail
