#!/bin/bash
# https://github.com/Hyy2001X/AutoBuild-Actions
# AutoBuild Module by Hyy2001
# AutoBuild_Tools for Openwrt

Version=V1.2.3

AutoBuild_Tools() {
while :
do
	clear
	cat /etc/banner
	echo -e "\n\nAutoBuild 固件工具箱 ${Version}\n"
	echo "1. USB 空间扩展"
	echo "2. Samba 一键共享"
	echo "3. 软件包安装"
	echo "4. 查找文件(夹)"
	echo "u. 固件更新"
	echo -e "\nx. 更新脚本"
	echo -e "q. 退出\n"
	read -p "请从上方选择一个操作:" Choose
	case $Choose in
	q)
		rm -rf ${AutoBuild_Tools_Temp}
		clear
		exit 0
	;;
	u)
		[ -f /bin/AutoUpdate.sh ] && {
			AutoUpdate_UI
		} || {
			echo "未检测到 '/bin/AutoUpdate.sh',请确保当前固件支持一键更新!"
		}
	;;
	x)
		
		wget -q ${Github_Raw}/Scripts/AutoBuild_Tools.sh -O ${AutoBuild_Tools_Temp}/AutoBuild_Tools.sh
		if [[ $? == 0 ]];then
			echo -e "\n[AutoBuild_Tools] 脚本更新成功!"
			rm -f /bin/AutoBuild_Tools.sh.sh
			mv -f ${AutoBuild_Tools_Temp}/AutoBuild_Tools.sh /bin
			chmod +x /bin/AutoBuild_Tools.sh
		else
			echo -e "\n[AutoBuild_Tools] 脚本更新失败!"
		fi
		sleep 2
	;;
	1)
		which block > /dev/null 2>&1
		[[ ! $? -eq 0 ]] && {
			echo -e "\n缺少相应依赖包,请先安装 [block-mount] !"
			sleep 3
		} || {
			uci set fstab.@global[0].auto_mount='0'
			uci set fstab.@global[0].auto_swap='0'
			uci commit fstab
			AutoExpand_UI
		}
	;;
	2)
		AutoSamba_UI
	;;
	3)
		AutoInstall_UI
	;;
	4)
		echo ""
		read -p "请选择要查找的类型[1.文件/*.文件夹]:" _Type
		[[ "${_Type}" == 1 ]] && _Type="f" || _Type="d"
		read -p "请输入要查找的路径:" _Path
		[[ -z "${_Path}" ]] && _Path="/"
		read -p "请输入要查找的文件(夹)名称:" _Name
		while [[ -z "${_Name}" ]]
		do
			echo -e "\n文件(夹)名称不能为空!\n"
			read -p "请输入要查找的文件(夹)名称:" _Name
		done
		echo -e "\n开始从 [${_Path}] 中查找 [${_Name}],请耐心等待 ...\n"
		PKG_Finder ${_Type} ${_Path} ${_Name}
		Enter
	;;
	esac
done
}

AutoExpand_UI() {
	clear
	echo -e "一键 USB 扩展内部空间/AutoExpand\n"
	USB_Check_Core
	[[ -n "${Check_Disk}" ]] && {
		for ((i=1;i<=${Disk_Number};i++));
		do
			Disk_info=$(sed -n ${i}p ${Disk_Processed_List})
			List_Disk ${Disk_info}
		done
		echo -e "\nq. 返回"
		echo "r. 重新载入列表"
	} || {
		echo "未检测到外接硬盘!" && sleep 2
		return 1
	}
	echo ""
	read -p "请输入要操作的硬盘编号[1-${Disk_Number}]:" Choose
	echo ""
	case ${Choose} in
	q)
		return 0
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
				echo "缺少相应依赖包,请先安装 [e2fsprogs] !" && sleep 3
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
	rm -rf ${AutoExpend_Temp}/*
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
	echo "注意: 操作开始后请不要中断任务或进行其他操作,否则可能导致设备数据丢失!"
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
			exit 1
		}
	}
	echo "正在格式化硬盘: '${Choosed_Disk}',请耐心等待 ..."
	mkfs.ext4 -F ${Choosed_Disk} > /dev/null 2>&1
	echo "硬盘格式化完成! 挂载硬盘: '${Choosed_Disk}' 到 ' /tmp/extroot' ..."
	mkdir -p /tmp/introot && mkdir -p /tmp/extroot
	mount --bind / /tmp/introot
	mount ${Choosed_Disk} /tmp/extroot
	echo "正在备份系统文件到硬盘: '${Choosed_Disk}',请耐心等待 ..."
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
		uci set fstab.@mount[${i}].enabled='1'
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
		echo -e "Samba 工具箱/AutoSamba\n"
		echo "1. 删除所有 Samba 挂载点"
		echo "2. 自动生成 Samba 共享"
		echo "3. 关闭/开启自动共享"
		echo -e "\nq. 返回\n"
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
		uci show 2>&1 | grep "sambashare" > ${Samba_UCI_List}
		if [[ ! "$(cat ${Samba_UCI_List})" =~ "${Disk_Name}" ]] > /dev/null 2>&1 ;then
			echo "共享硬盘: '${Disk_Name}' on '${Disk_Mounted_Point}' 到 '${Samba_Name}' ..."
			echo -e "\nconfig sambashare" >> ${Samba_Config}
			echo -e "\toption auto '1'" >> ${Samba_Config}
			echo -e "\toption name '${Samba_Name}'" >> ${Samba_Config}
			echo -e "\toption device '${Disk_Name}'" >> ${Samba_Config}
			echo -e "\toption path '${Disk_Mounted_Point}'" >> ${Samba_Config}
			echo -e "\toption read_only 'no'" >> ${Samba_Config}
			echo -e "\toption guest_ok 'yes'" >> ${Samba_Config}
			echo -e "\toption create_mask '0666'" >> ${Samba_Config}
			echo -e "\toption dir_mask '0777'" >> ${Samba_Config}
		else
			echo "硬盘: '${Disk_Name}' 已设置共享点: '${Samba_Name}' !"
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
	echo "1. 更新软件包列表"
	AutoInstall_UI_mod 2 block-mount
	AutoInstall_UI_mod 3 e2fsprogs
	echo "x. 自定义软件包名"
	echo -e "\nq. 返回\n"
	read -p "请从上方选择一个操作:" Choose
	echo ""
	case $Choose in
	q)
		break
	;;
	x)
		echo -e "常用的附加参数:\n"
		echo "--force-depends		在安装、删除软件包时无视失败的依赖"
		echo "--force-downgrade	允许降级安装软件包"
		echo -e "--force-reinstall	重新安装软件包\n"
		read -p "请输入你想安装的软件包名和附加参数:" PKG_NAME
		Install_opkg_mod $PKG_NAME
	;;
	1)
		opkg update
		sleep 1
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

AutoUpdate_UI() {
while :
do
	AutoUpdate_Version=$(awk 'NR==6' /bin/AutoUpdate.sh | awk -F '[="]+' '/Version/{print $2}')
	clear
	echo -e "AutoBuild 固件更新/AutoUpdate ${AutoUpdate_Version}\n"
	echo "1. 更新固件 [保留配置]"
	echo "2. 强制更新固件 (跳过版本号验证,自动安装缺失的软件包) [保留配置]"
	echo "3. 不保留配置更新固件 [全新安装]"
	echo "4. 列出固件信息"
	echo "5. 清除固件下载缓存"
	echo "6. 更改 Github API 地址"
	echo "7. 指定 x86 设备下载 UEFI/Legacy 引导的固件"
	echo -e "\nx. 更新 [AutoUpdate] 脚本"
	echo -e "q. 返回\n"
	read -p "请从上方选择一个操作:" Choose
	case ${Choose} in
	q)
		break
	;;
	x)
		wget -q ${Github_Raw}/Scripts/AutoUpdate.sh -O ${AutoBuild_Tools_Temp}/AutoUpdate.sh
		[[ $? == 0 ]] && {
			echo -e "\n脚本更新成功!"
			rm -f /bin/AutoUpdate.sh
			mv -f ${AutoBuild_Tools_Temp}/AutoUpdate.sh /bin
			chmod +x /bin/AutoUpdate.sh
		} || echo -e "\n脚本更新失败!"
		sleep 2
	;;
	1)
		bash /bin/AutoUpdate.sh
	;;
	2)
		bash /bin/AutoUpdate.sh -f
	;;
	3)
		bash /bin/AutoUpdate.sh -n
	;;
	4)
		bash /bin/AutoUpdate.sh -l
		Enter
	;;
	5)
		bash /bin/AutoUpdate.sh -d
		sleep 1
	;;
	6)
		echo ""
		read -p "请输入新的 Github 地址:" _API
		[[ -n ${_API} ]] && bash /bin/AutoUpdate.sh -c ${_API} || {
			echo "Github 地址不能为空!"
		}
		sleep 2
	;;
	7)
		echo ""
		read -p "请输入你想要的启动方式[UEFI/Legacy]:" _BOOT
		[[ -n ${_BOOT} ]] && bash /bin/AutoUpdate.sh -b ${_BOOT} || {
			echo -e "\n启动方式不能为空!"
		}
		sleep 2
	;;
	esac
done
}

AutoInstall_UI_mod() {
	[[ "$(opkg list | awk '{print $1}')" =~ "${2}" ]] > /dev/null 2>&1 && {
		echo "${1}. 安装 [${2}] [已安装]"
	} ||  echo "${1}. 未安装 [${2}] [已安装]"
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

PKG_Finder() {
	[[ $# -ne 3 ]] && {
		TIME "[ERROR] Error options: [$#] [$*] !"
		return 0
	}
	unset PKG_RESULT
	_PKG_TYPE=${1}
	_PKG_DIR=${2}
	_PKG_NAME=${3}
	[[ -z ${_PKG_TYPE} ]] && [[ -z ${_PKG_NAME} ]] || [[ -z ${_PKG_DIR} ]] && return
	_PKG_RESULT=$(find ${_PKG_DIR} -name ${_PKG_NAME} -type ${_PKG_TYPE} -exec echo {} \;)
	[[ -n "${_PKG_RESULT}" ]] && echo "${_PKG_RESULT}"
	unset _PKG_TYPE _PKG_DIR _PKG_NAME
}

AutoBuild_Tools_Temp="/tmp/AutoBuild_Tools"
AutoExpend_Temp="${AutoBuild_Tools_Temp}/AutoExpand"
Disk_List="${AutoExpend_Temp}/Disk_List"
Block_Info="${AutoExpend_Temp}/Block_Info"
Disk_Processed_List="${AutoExpend_Temp}/Disk_Processed_List"
[ ! -d "${AutoExpend_Temp}" ] && mkdir -p "${AutoExpend_Temp}"
Samba_Config="/etc/config/samba"
Samba_Temp="${AutoBuild_Tools_Temp}/AutoSamba"
Samba_Disk_List="${Samba_Temp}/Disk_List"
Samba_UCI_List="${Samba_Temp}/UCI_List"
[ ! -d "${Samba_Temp}" ] && mkdir -p "${Samba_Temp}"
Github_Raw="https://raw.githubusercontent.com/Hyy2001X/AutoBuild-Actions/master"
AutoBuild_Tools