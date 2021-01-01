#!/bin/bash
# https://github.com/Hyy2001X/AutoBuild-Actions
# AutoBuild Module by Hyy2001
# AutoExpand_Storage(BETA) for Openwrt

Version=V1.0-BETA

AutoExpand_UI() {
	uci set fstab.@global[0].auto_mount='0'
	uci set fstab.@global[0].auto_swap='0'
	uci commit fstab
	[ ! -d /tmp/autocheckUSB ] && mkdir -p /tmp/autocheckUSB
	rm -rf /tmp/autocheckUSB/*
	touch ${Disk_Processed_List}
	echo "$(block info)" > ${Block_Info}
	Check_Disk="$(cat  ${Block_Info} | awk  -F ':' '/sd/{print $1}')"
	clear
	echo -e "Newifi-D2 一键扩展内部空间 ${Version}\n"
	if [ ! -z "${Check_Disk}" ];then
		echo "${Check_Disk}" > ${Disk_List}
		Disk_Number=$(sed -n '$=' ${Disk_List})
		echo -e "硬盘数量: ${Disk_Number}\n"
		for Disk_Name in $(cat ${Disk_List})
		do
			Mounted_on="$(df -h | grep "${Disk_Name}" | awk '{print $6}')"
			Disk_Available="$(df -m | grep "${Disk_Name}" | awk '{print $4}')"
			Disk_Format="$(cat  ${Block_Info} | grep "${Disk_Name}" | egrep -o 'TYPE="[a-z].+' | awk -F '["]' '/TYPE/{print $2}')"
			if [ ! -z "$Mounted_on" ];then
				echo "${Disk_Name} ${Mounted_on} ${Disk_Format} ${Disk_Available}MB" >> ${Disk_Processed_List}
			else
				echo "${Disk_Name} ${Disk_Format}" >> ${Disk_Processed_List}
			fi
		done
		for ((i=1;i<=${Disk_Number};i++));
		do
			Disk_info=$(sed -n ${i}p ${Disk_Processed_List})
			List_Disk ${Disk_info}
		done
		echo -e "\nq.退出"
		echo "r.重新载入列表"
	else
		echo "未检测到外接硬盘!"
		exit
	fi
	echo ""
	read -p "请输入要操作的硬盘编号[1-${Disk_Number}]:" Choose
	echo ""
	case ${Choose} in
	q)
		exit
	;;
	r)
		AutoExpand_UI
	;;
	*)
		if [ ${Choose} -gt 0 ] > /dev/null 2>&1 && [ ${Choose} -le ${Disk_Number} ] > /dev/null 2>&1;then
			AutoExpand_Core
		else
			echo "选择错误,请输入正确的选项!"
			sleep 2 && AutoExpand_UI
			exit
		fi
	;;
	esac
}

AutoExpand_Core() {
	Choosed_Disk="$(sed -n ${Choose}p ${Disk_Processed_List} | awk '{print $1}')"
	echo "警告: 本次操作将把硬盘: '${Choosed_Disk}' 格式化为 'ext4' 格式,请做好数据备份工作!"
	read -p "是否继续本次操作?[Y/n]:" Choose
	if [ ${Choose} == Y ] || [ ${Choose} == y ];then
		sleep 3 && echo ""
	else
		echo "用户已取消操作."
		exit
	fi
	if [[ "$(mount)" =~ "${Choosed_Disk}" ]];then
		Choosed_Disk_Mounted="$(mount | grep "${Choosed_Disk}" | awk '{print $3}')"
		echo "取消挂载: '${Choosed_Disk}' on '${Choosed_Disk_Mounted}' ..."
		umount ${Choosed_Disk_Mounted} > /dev/null 2>&1
	fi
	if [[ ! "$(opkg list | awk '{print $1}')" =~ "e2fsprogs" ]];then
		echo "正在安装: 'e2fsprogs',请耐心等待 ..."
		opkg update > /dev/null 2>&1
		opkg install e2fsprogs > /dev/null 2>&1
	fi
	echo "正在格式化硬盘: '${Choosed_Disk}' 为 'ext4' ..."
	mkfs.ext4 -F ${Choosed_Disk} > /dev/null 2>&1
	echo "格式化完成! 挂载 '${Choosed_Disk}' 到 ' /tmp/extroot' ..."
	mkdir -p /tmp/introot && mkdir -p /tmp/extroot
	mount --bind / /tmp/introot
	mount ${Choosed_Disk} /tmp/extroot
	echo "正在备份系统文件,请耐心等待 ..."
	tar -C /tmp/introot -cf - . | tar -C /tmp/extroot -xf -
	echo "取消挂载: '/tmp/introot' '/tmp/extroot' ..."
	umount /tmp/introot && umount /tmp/extroot
	[ ! -d /mnt/bak ] && mkdir -p /mnt/bak
	mount ${Choosed_Disk} /mnt/bak
	echo "同步系统文件改动 ..."
	sync
	echo "写入 '分区表' 到 '/etc/config/fstab' ..."
	block detect > /etc/config/fstab
	sed -i "s?/mnt/bak?/?g" /etc/config/fstab
	for ((i=0;i<=${Disk_Number};i++));
	do
		uci set fstab.@mount[${i}].enabled='1' > /dev/null 2>&1
	done
	uci commit fstab
	umount /mnt/bak
	echo "操作结束,外接硬盘: '${Choosed_Disk}' 已挂载到 '/'."
	exit
}

List_Disk() {
	if [ ! -z ${3} ];then
		echo "${i}.外接硬盘: '${1}' 挂载点: '${2}' 格式: '${3}' 可用空间: ${4}"
	else
		echo "${i}.外接硬盘: '${1}' 格式: '${2}' 未挂载"
	fi
}

Disk_List="/tmp/autocheckUSB/disk_list"
Block_Info="/tmp/autocheckUSB/block_info"
Disk_Processed_List="/tmp/autocheckUSB/disk_processed_list"
AutoExpand_UI
