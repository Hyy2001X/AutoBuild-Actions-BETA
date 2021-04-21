#!/bin/bash
# https://github.com/Hyy2001X/AutoBuild-Actions
# AutoBuild Module by Hyy2001
# AutoBuild_Tools for Openwrt

Version=V1.2.2

AutoBuild_Tools() {
	while :
	do
		clear
		echo -e "AutoBuild 固件工具箱 ${Version}\n"
		echo "1.USB 空间扩展"
		echo "2.Samba 一键共享"
		echo "3.软件包安装"
		echo -e "\nq.退出\n"
		read -p "请从上方选择一个操作:" Choose
		case $Choose in
		q)
			rm -rf /tmp/AutoExpand /tmp/AutoSamba
			clear
			exit
		;;
		1)
			uci set fstab.@global[0].auto_mount='0'
			uci set fstab.@global[0].auto_swap='0'
			uci commit fstab
			AutoExpand_UI
		;;
		2)
			AutoSamba_UI
		;;
		3)
			AutoInstall_UI
		;;
		esac
	done
}

AutoExpand_UI() {
	clear
	echo -e "一键 USB 扩展内部空间\n"
	USB_Check_Core
	[[ -n "${Check_Disk}" ]] && {
		for ((i=1;i<=${Disk_Number};i++));
		do
			Disk_info=$(sed -n ${i}p ${Disk_Processed_List})
			List_Disk ${Disk_info}
		done
		echo -e "\nq.返回"
		echo "r.重新载入列表"
	} || {
		echo "未检测到外接硬盘!" && sleep 2
		return
	}
	echo ""
	read -p "请输入要操作的硬盘编号[1-${Disk_Number}]:" Choose
	echo ""
	case ${Choose} in
	q)
		return
	;;
	r)
		block mount
		AutoExpand_UI
	;;
	*)
		[[ "${Choose}" -gt 0 ]] > /dev/null 2>&1 && [[ "${Choose}" -le "${Disk_Number}" ]] > /dev/null 2>&1 && {
			which mkfs.ext4 > /dev/null 2>&1
			[[ $? -eq 0 ]] && {
				AutoExpand_Core
			} || {
				echo "请先安装 [e2fsprogs] !" && sleep 3
			}			
		} || {
			echo "选择错误,请输入正确的选项!"
			sleep 2 && AutoExpand_UI
			exit
		}
	;;
	esac
}

USB_Check_Core() {
	block mount
	rm -rf ${AutoExpend_Tmp}/*
	echo "$(block info)" > ${Block_Info}
	Check_Disk="$(cat ${Block_Info} | awk  -F ':' '/sd/{print $1}')"
	[[ -n "${Check_Disk}" ]] && {
		echo "${Check_Disk}" > ${Disk_List}
		Disk_Number=$(sed -n '$=' ${Disk_List})
		for Disk_Name in $(cat ${Disk_List})
		do
			Mounted_Point=$(grep "${Disk_Name}" ${Block_Info} | egrep -o 'MOUNT="/[a-z].+' | awk -F '["]' '/MOUNT/{print $2}')
			#Mounted_Point=$(grep "${Disk_Name}" ${Block_Info} | egrep -o 'MOUNT=.*' | awk '{print $1}' | sed -r 's/MOUNT="(.*)"/\1/')
			[[ -z "${Mounted_Point}" ]] && Mounted_Point="$(df -h | grep "${Disk_Name}" | awk '{print $6}' | awk 'NR==1')"
			Disk_Available="$(df -m | grep "${Disk_Name}" | awk '{print $4}' | awk 'NR==1')"
			[[ -z "${Disk_Available}" ]] && Disk_Available=0
			Disk_Format="$(cat  ${Block_Info} | grep "${Disk_Name}" | egrep -o 'TYPE="[a-z].+' | awk -F '["]' '/TYPE/{print $2}')"
			touch ${Disk_Processed_List}
			[[ -n "${Mounted_Point}" ]] && {
				echo "${Disk_Name} ${Mounted_Point} ${Disk_Format} ${Disk_Available}MB" >> ${Disk_Processed_List}
			} || {
				echo "${Disk_Name} ${Disk_Format}" >> ${Disk_Processed_List}
			}
		done
	}
}

AutoExpand_Core() {
	Choosed_Disk="$(sed -n ${Choose}p ${Disk_Processed_List} | awk '{print $1}')"
	echo "警告: 本次操作将把硬盘: '${Choosed_Disk}' 格式化为 'ext4' 格式,请提前做好数据备份工作!"
	read -p "是否继续本次操作?[Y/n]:" Choose
	[[ "${Choose}" == Y ]] || [[ "${Choose}" == y ]] && sleep 3 && echo "" || {
		sleep 3
		echo "用户已取消操作."
		break
	}
	[[ "$(mount)" =~ "${Choosed_Disk}" ]] > /dev/null 2>&1 && {
		Choosed_Disk_Mounted="$(mount | grep "${Choosed_Disk}" | awk '{print $3}')"
		echo "取消挂载: '${Choosed_Disk}' on '${Choosed_Disk_Mounted}' ..."
		umount -l ${Choosed_Disk_Mounted} > /dev/null 2>&1
		[[ "$(mount)" =~ "${Choosed_Disk_Mounted}" ]] > /dev/null 2>&1 && {
			echo "取消挂载: '${Choosed_Disk_Mounted}' 失败 !"
			exit
		}
	}
	echo "正在格式化硬盘: '${Choosed_Disk}' 为 'ext4' 格式 ..."
	mkfs.ext4 -F ${Choosed_Disk} > /dev/null 2>&1
	echo "格式化完成! 挂载硬盘: '${Choosed_Disk}' 到 ' /tmp/extroot' ..."
	mkdir -p /tmp/introot && mkdir -p /tmp/extroot
	mount --bind / /tmp/introot
	mount ${Choosed_Disk} /tmp/extroot
	echo "正在备份系统文件到 硬盘: '${Choosed_Disk}',请耐心等待 ..."
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
	umount -l /mnt/bak
	echo -e "操作结束,外接硬盘: '${Choosed_Disk}' 已挂载到 '/'.\n"
	read -p "挂载完成后需要重启生效,是否立即重启路由器?[Y/n]:" Choose
	[[ ${Choose} == Y ]] || [[ ${Choose} == y ]] && {
		sleep 3 && echo -e "\n正在重启路由器,请耐心等待 ..."
		sync
		reboot
	} || {
		echo "用户已取消重启操作."
		sleep 3
		break
	}
}

List_Disk() {
	[[ -n "${3}" ]] && {
		echo "${i}. '${1}' 挂载点: '${2}' 格式: '${3}' 可用空间: ${4}"
	} || echo "${i}. '${1}' 格式: '${2}' 未挂载"
}

AutoSamba_UI() {
	while :
	do
		clear
		echo -e "Samba 工具箱\n"
		echo "1.删除所有 Samba 挂载点"
		echo "2.自动生成 Samba 共享"
		echo "3.关闭/开启自动共享"
		echo -e "\nq.返回\n"
		read -p "请从上方选择一个操作:" Choose
		case $Choose in
		1)
			Remove_Samba_Settings
		;;
		2)
			Mount_Samba_Devices
		;;
		3)
			autosamba="$(uci get samba.@samba[0].autoshare)"
			[[ ${autosamba} == 0 ]] && {
				uci set samba.@samba[0].autoshare='1'
				autosamba_mode="开启"
			} || {
				uci set samba.@samba[0].autoshare='0'
				autosamba_mode="关闭"
			}
			echo -e "\n已${autosamba_mode} Samba 自动共享!"
			uci commit samba
			sleep 3
		;;
		q)
			break
		;;
		esac
	done
}

Remove_Samba_Settings() {
	while :
	do
		Samba_config="$(grep "sambashare" /etc/config/samba | wc -l)"
		[[ "${Samba_config}" -eq 0 ]] && break
		uci delete samba.@sambashare[0]
		uci commit
	done
	echo -e "\n已删除所有 Samba 挂载点!"
	sleep 2
}

Mount_Samba_Devices() {
	echo "$(cat /proc/mounts  | awk  -F ':' '/sd/{print $1}')" > ${Samba_Disk_List}
	Disk_Number=$(sed -n '$=' ${Samba_Disk_List})
	echo ""
	for ((i=1;i<=${Disk_Number};i++));
	do
		Disk_Name=$(sed -n ${i}p ${Samba_Disk_List} | awk '{print $1}')
		Disk_Mounted_Point=$(sed -n ${i}p ${Samba_Disk_List} | awk '{print $2}')
		Samba_Name=${Disk_Mounted_Point#*/mnt/}
		uci show 2>&1 | grep "sambashare" > ${UCI_Show_List}
		if [[ ! "$(cat ${UCI_Show_List})" =~ "${Disk_Name}" ]] > /dev/null 2>&1 ;then
			echo "共享硬盘: '${Disk_Name}' on '${Disk_Mounted_Point}' 到 '${Samba_Name}' ..."
			echo -e "\nconfig sambashare" >> ${Samba_Config_File}
			echo -e "\toption auto '1'" >> ${Samba_Config_File}
			echo -e "\toption name '${Samba_Name}'" >> ${Samba_Config_File}
			echo -e "\toption device '${Disk_Name}'" >> ${Samba_Config_File}
			echo -e "\toption path '${Disk_Mounted_Point}'" >> ${Samba_Config_File}
			echo -e "\toption read_only 'no'" >> ${Samba_Config_File}
			echo -e "\toption guest_ok 'yes'" >> ${Samba_Config_File}
			echo -e "\toption create_mask '0666'" >> ${Samba_Config_File}
			echo -e "\toption dir_mask '0777'" >> ${Samba_Config_File}
		else
			echo "硬盘: '${Disk_Name}' 已设置共享."
		fi
	done
	/etc/init.d/samba restart
	sleep 3
}

AutoInstall_UI() {
while :
	do
		clear
		echo -e "安装软件包\n"
		echo "1.更新软件包列表"
		AutoInstall_UI_Mod 2 block-mount
		AutoInstall_UI_Mod 3 e2fsprogs
		echo "x.自定义软件包名"
		echo -e "\nq.返回\n"
		read -p "请从上方选择一个操作:" Choose
		echo ""
		case $Choose in
		q)
			break
		;;
		x)
			echo "常用的附加参数:"
			echo "--force-depends		在安装、删除软件包时无视失败的依赖"
			echo "--force-downgrade	允许降级安装软件包"
			echo -e "--force-reinstall	重新安装软件包\n"
			read -p "请输入你想安装的软件包名:" PKG_NAME
			Install_opkg_mod $PKG_NAME
		;;
		1)
			opkg update
		;;
		2)
			Install_opkg_mod block-mount	
		;;
		3)
			Install_opkg_mod e2fsprogs
		;;
		esac
	done
}

AutoInstall_UI_Mod() {
	[[ "$(opkg list | awk '{print $1}')" =~ "${2}" ]] > /dev/null 2>&1 && {
		echo "${1}.安装 [${2}] [已安装]"
	} ||  echo "${1}.未安装 [${2}] [已安装]"
}

Install_opkg_mod() {
	opkg install ${*}
	[[ "$(opkg list | awk '{print $1}')" =~ "${1}" ]] > /dev/null 2>&1 && {
		echo -e "\n${1} 安装成功!"
	} || echo -e "\n${1} 安装失败!"
	sleep 2
}

Enter() {
	echo "" && read -p "按下[回车]键以继续..." Key
}

AutoExpend_Tmp="/tmp/AutoExpand"
Disk_List="${AutoExpend_Tmp}/Disk_List"
Block_Info="${AutoExpend_Tmp}/Block_Info"
Disk_Processed_List="${AutoExpend_Tmp}/Disk_Processed_List"
[ ! -d "${AutoExpend_Tmp}" ] && mkdir -p ${AutoExpend_Tmp}
Samba_Config_File="/etc/config/samba"
Samba_Tmp="/tmp/AutoSamba"
Samba_Disk_List="${Samba_Tmp}/Disk_List"
UCI_Show_List="${Samba_Tmp}/UCI_List"
[ ! -d "${Samba_Tmp}" ] && mkdir -p "${Samba_Tmp}"
which block > /dev/null 2>&1
[[ $? -eq 0 ]] && AutoBuild_Tools || {
	echo -e "\nAutoBuild_Tools 不适用于此固件,请先安装 [block-mount] !"
}