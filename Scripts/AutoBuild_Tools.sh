#!/bin/bash
# AutoBuild Module by Hyy2001 <https://github.com/Hyy2001X/AutoBuild-Actions>
# AutoBuild_Tools for Openwrt
# Depends on: bash wget curl block-mount e2fsprogs smartmontools

Version=V1.5

ECHO() {
	local Color
	[[ -z $1 ]] && {
		echo -ne "\n${Grey}[$(date "+%H:%M:%S")]${White} "
	} || {
	case $1 in
		r) Color="${Red}";;
		g) Color="${Green}";;
		b) Color="${Blue}";;
		y) Color="${Yellow}";;
		x) Color="${Grey}";;
	esac
		[[ $# -lt 2 ]] && {
			echo -e "\n${Grey}[$(date "+%H:%M:%S")]${White} $1"
			LOGGER $1
		} || {
			echo -e "\n${Grey}[$(date "+%H:%M:%S")]${White} ${Color}$2${White}"
			LOGGER $2
		}
	}
}

LOGGER() {
	[[ ! -f ${Main_tmp}/AutoBuild_Tools.log ]] && touch ${Main_tmp}/AutoBuild_Tools.log
	echo "[$(date "+%Y-%m-%d-%H:%M:%S")] $*" >> ${Main_tmp}/AutoBuild_Tools.log
}

AutoBuild_Tools() {
while :
do
	clear
	echo -e "${Skyb}$(cat /etc/banner)${White}"
	echo -e "\n\nAutoBuild 固件工具箱 ${Version}\n"
	echo "1. USB 空间扩展"
	echo "2. Samba 一键共享"
	echo "3. 软件包安装"
	echo "4. 端口占用列表"
	echo "5. 查看硬盘信息"
	echo "u. 固件更新"
	echo -e "\nx. 更新脚本"
	echo -e "q. 退出\n"
	read -p "请从上方选择一个操作:" Choose
	case $Choose in
	q)
		rm -rf ${Main_tmp}
		clear
		exit 0
	;;
	u)
		[ -f /bin/AutoUpdate.sh ] && {
			AutoUpdate_UI
		} || {
			ECHO r "未检测到 '/bin/AutoUpdate.sh',请确保当前固件支持一键更新!"
		}
	;;
	x)
		
		wget -q ${Github_Raw}/Scripts/AutoBuild_Tools.sh -O ${Main_tmp}/AutoBuild_Tools.sh
		if [[ $? == 0 ]];then
			ECHO y "[AutoBuild_Tools] 脚本更新成功!"
			rm -f /bin/AutoBuild_Tools.sh.sh
			mv -f ${Main_tmp}/AutoBuild_Tools.sh /bin
			chmod +x /bin/AutoBuild_Tools.sh
		else
			ECHO r "[AutoBuild_Tools] 脚本更新失败!"
		fi
		sleep 2
	;;
	1)
		which block > /dev/null 2>&1
		[[ ! $? -eq 0 ]] && {
			ECHO r "缺少相应依赖包,请先安装 [block-mount] !"
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
		clear
		echo -e "端口		服务名称\n"
		netstat -tanp | egrep ":::[0-9].+|0.0.0.0:[0-9]+|127.0.0.1:[0-9]+" | awk '{print $4"\t     "$7}' | sed -r 's/:::/\1/' | sed -r 's/0.0.0.0:/\1/' | sed -r 's/127.0.0.1:/\1/'| sed -r 's/[0-9]+.\//\1/' | sort | uniq
		Enter
	;;
	5)
		which smartctl > /dev/null 2>&1
		[[ ! $? -eq 0 ]] && {
			ECHO r "缺少相应依赖包,请先安装 [smartmontools] !"
			sleep 3
		} || Smart_Info
	;;
	esac
done
}

AutoExpand_UI() {
	clear
	echo -e "一键 USB 扩展内部空间/AutoExpand\n"
	USB_Check_Core
	[[ -n ${Check_Disk} ]] && {
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
		[[ ${Choose} -gt 0 ]] > /dev/null 2>&1 && [[ ${Choose} -le ${Disk_Number} ]] > /dev/null 2>&1 && {
			which mkfs.ext4 > /dev/null 2>&1
			[[ $? -eq 0 ]] && {
				AutoExpand_Core
			} || {
				ECHO r "缺少相应依赖包,请先安装 [e2fsprogs] !" && sleep 3
			}			
		} || {
			ECHO r "选择错误,请输入正确的选项!"
			sleep 2 && AutoExpand_UI
			exit
		}
	;;
	esac
}

USB_Check_Core() {
	block mount
	rm -rf ${Main_tmp}/*
	echo "$(block info)" > ${Block_Info}
	Check_Disk="$(cat ${Block_Info} | awk  -F ':' '/sd/{print $1}')"
	[[ -n ${Check_Disk} ]] && {
		echo "${Check_Disk}" > ${Disk_List}
		Disk_Number=$(sed -n '$=' ${Disk_List})
		for Disk_Name in $(cat ${Disk_List})
		do
			Mounted_Point=$(grep "${Disk_Name}" ${Block_Info} | egrep -o 'MOUNT="/[a-z].+' | awk -F '["]' '/MOUNT/{print $2}')
			[[ -z ${Mounted_Point} ]] && Mounted_Point="$(df -h | grep "${Disk_Name}" | awk '{print $6}' | awk 'NR==1')"
			Disk_Available="$(df -m | grep "${Disk_Name}" | awk '{print $4}' | awk 'NR==1')"
			[[ -z ${Disk_Available} ]] && Disk_Available=0
			Disk_Format="$(cat  ${Block_Info} | grep "${Disk_Name}" | egrep -o 'TYPE="[a-z].+' | awk -F '["]' '/TYPE/{print $2}')"
			touch ${Disk_Processed_List}
			[[ -n ${Mounted_Point} ]] && {
				echo "${Disk_Name} ${Mounted_Point} ${Disk_Format} ${Disk_Available}MB" >> ${Disk_Processed_List}
			} || {
				echo "${Disk_Name} ${Disk_Format}" >> ${Disk_Processed_List}
			}
		done
		grep -o "/dev/sd[a-z]" ${Disk_List} | sort | uniq > ${Phy_Disk_List}
	}
}

AutoExpand_Core() {
	Choosed_Disk="$(sed -n ${Choose}p ${Disk_Processed_List} | awk '{print $1}')"
	echo "警告: 本次操作将把硬盘: '${Choosed_Disk}' 格式化为 'ext4' 格式,请提前做好数据备份工作!"
	echo "注意: 操作开始后请不要中断任务或进行其他操作,否则可能导致设备数据丢失!"
	read -p "是否继续本次操作?[Y/n]:" Choose
	[[ ${Choose} == [Yy] ]] && sleep 3 && echo "" || {
		sleep 3
		ECHO "用户已取消操作."
		break
	}
	[[ $(mount) =~ ${Choosed_Disk} ]] > /dev/null 2>&1 && {
		Choosed_Disk_Mounted="$(mount | grep "${Choosed_Disk}" | awk '{print $3}')"
		echo "取消挂载: '${Choosed_Disk}' on '${Choosed_Disk_Mounted}' ..."
		umount -l ${Choosed_Disk_Mounted} > /dev/null 2>&1
		[[ $(mount) =~ ${Choosed_Disk_Mounted} ]] > /dev/null 2>&1 && {
			echo "取消挂载: '${Choosed_Disk_Mounted}' 失败 !"
			exit 1
		}
	}
	ECHO "正在格式化硬盘: '${Choosed_Disk}',请耐心等待 ..."
	mkfs.ext4 -F ${Choosed_Disk} > /dev/null 2>&1
	ECHO "硬盘格式化完成! 挂载硬盘: '${Choosed_Disk}' 到 ' /tmp/extroot' ..."
	mkdir -p /tmp/introot && mkdir -p /tmp/extroot
	mount --bind / /tmp/introot
	mount ${Choosed_Disk} /tmp/extroot
	ECHO "正在备份系统文件到硬盘: '${Choosed_Disk}',请耐心等待 ..."
	tar -C /tmp/introot -cf - . | tar -C /tmp/extroot -xf -
	ECHO "取消挂载: '/tmp/introot' '/tmp/extroot' ..."
	umount /tmp/introot && umount /tmp/extroot
	[ ! -d /mnt/bak ] && mkdir -p /mnt/bak
	mount ${Choosed_Disk} /mnt/bak
	sync
	ECHO "写入 '分区表' 到 '/etc/config/fstab' ..."
	block detect > /etc/config/fstab
	sed -i "s?/mnt/bak?/?g" /etc/config/fstab
	for ((i=0;i<=${Disk_Number};i++));
	do
		uci set fstab.@mount[${i}].enabled='1'
	done
	uci commit fstab
	umount -l /mnt/bak
	ECHO y "操作结束,外接硬盘: '${Choosed_Disk}' 已挂载到 '/'"
	read -p "挂载完成后需要重启生效,是否立即重启路由器?[Y/n]:" Choose
	[[ ${Choose} == [Yy] ]] && {
		sleep 3 && ECHO g "\n正在重启路由器,请耐心等待 ..."
		sync
		reboot
	} || {
		ECHO "用户已取消重启操作."
		sleep 3
		break
	}
}

List_Disk() {
	[[ -n $3 ]] && {
		echo "${i}. '$1' 挂载点: '$2' 格式: '$3' 可用空间: $4"
	} || echo "${i}. '$1' 格式: '$2' 未挂载"
}

AutoSamba_UI() {
	USB_Check_Core
	Samba_tmp="${Main_tmp}/AutoSamba"
	Samba_UCI_List="${Main_tmp}/UCI_List"
	[[ ! -d ${Main_tmp} ]] && mkdir -p "${Main_tmp}"
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
			ECHO y "已${autosamba_mode} Samba 自动共享!"
			uci commit samba
			sleep 2
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
		[[ ${Samba_config} -eq 0 ]] && break
		uci delete samba.@sambashare[0]
		uci commit samba > /dev/null 2>&1
	done
	ECHO y "已删除所有 Samba 挂载点!"
	sleep 2
}

Mount_Samba_Devices() {
	Disk_Number=$(sed -n '$=' ${Disk_Processed_List})
	for ((i=1;i<=${Disk_Number};i++));
	do
		Disk_Name=$(sed -n ${i}p ${Disk_Processed_List} | awk '{print $1}')
		Disk_Mounted_Point=$(sed -n ${i}p ${Disk_Processed_List} | awk '{print $2}')
		Samba_Name=${Disk_Mounted_Point#*/mnt/}
		Samba_Name=$(echo ${Samba_Name} | cut -d "/" -f2-5)
		uci show 2>&1 | grep "sambashare" > ${Samba_UCI_List}
		if [[ ! $(cat ${Samba_UCI_List}) =~ ${Disk_Mounted_Point} ]] > /dev/null 2>&1 ;then
			ECHO g "设置挂载点 '${Samba_Name}' ..."
			cat >> /etc/config/samba <<EOF

config sambashare
	option auto '1'
	option name '${Samba_Name}'
	option device '${Disk_Name}'
	option path '${Disk_Mounted_Point}'
	option read_only 'no'
	option guest_ok 'yes'
	option create_mask '0666'
	option dir_mask '0777'
EOF
		else
			ECHO y "'${Disk_Mounted_Point}' 挂载点已存在 !"
		fi
	done
	uci commit samba
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
	AutoInstall_UI_mod 4 smartmontools
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
	4)
		Install_opkg_mod smartmontools
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
	[[ ${DEFAULT_Device} == x86_64 ]] && echo "7. 指定 x86 设备下载 UEFI/Legacy 引导的固件"
	echo -e "\nx. 更新 [AutoUpdate] 脚本"
	echo -e "q. 返回\n"
	read -p "请从上方选择一个操作:" Choose
	case ${Choose} in
	q)
		break
	;;
	x)
		wget -q ${Github_Raw}/Scripts/AutoUpdate.sh -O ${Main_tmp}/AutoUpdate.sh
		[[ $? == 0 ]] && {
			ECHO y "脚本更新成功!"
			rm -f /bin/AutoUpdate.sh
			mv -f ${Main_tmp}/AutoUpdate.sh /bin
			chmod +x /bin/AutoUpdate.sh
		} || ECHO r "脚本更新失败!"
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
		bash /bin/AutoUpdate.sh --list
		Enter
	;;
	5)
		bash /bin/AutoUpdate.sh --clean
		sleep 1
	;;
	6)
		echo ""
		read -p "请输入新的 Github 地址:" Github_URL
		[[ -n ${Github_URL} ]] && bash /bin/AutoUpdate.sh -C ${Github_URL} || {
			ECHO r "Github 地址不能为空!"
		}
		sleep 2
	;;
	7)
		echo ""
		read -p "请输入你想要的启动方式[UEFI/Legacy]:" _BOOT
		[[ -n ${_BOOT} ]] && bash /bin/AutoUpdate.sh -B ${_BOOT} || {
			ECHO r "启动方式不能为空!"
		}
		sleep 2
	;;
	esac
done
}

Smart_Info() {
	ECHO g "Loading disk information ,please wait..."
	USB_Check_Core
	clear
	smartctl -v | awk 'NR==1'
	cat ${Phy_Disk_List} | while read Phy_Disk
	do
		GET_Smart_Info ${Phy_Disk}
	done
	Enter
}

getinf() {
	grep "$1" $2 | sed "s/^[$1]*//g" 2>/dev/null | sed 's/^[ \t]*//g' 2>/dev/null
}

GET_Smart_Info() {
	smartctl -H -A -i $1 > ${Smart_Info1}
	smartctl -H -A -i -d scsi $1 > ${Smart_Info2}
	if [[ ! $(smartctl -H $1) =~ Unknown ]];then
		[[ $(smartctl -H $1) =~ PASSED ]] && Phy_Health=PASSED || Phy_Health=Failure
	else
		Phy_Health=$(getinf "SMART Health Status:" ${Smart_Info2})
	fi
	Phy_Name=$(getinf "Device Model:" ${Smart_Info1})
	Phy_ID=$(getinf "Serial number:" ${Smart_Info2})
	Phy_Capacity=$(getinf "User Capacity:" ${Smart_Info2})
	Phy_Part_Number=$(grep -c "${Phy_Disk}" ${Disk_Processed_List})
	Phy_Factor=$(getinf "Form Factor:" ${Smart_Info2})
	[[ -z ${Phy_Factor} ]] && Phy_Factor=不可用
	Phy_Sata_Version=$(getinf "SATA Version is:" ${Smart_Info1})
	[[ -z ${Phy_Sata_Version} ]] && Phy_Sata_Version=不可用
	TRIM_Command=$(getinf "TRIM Command:" ${Smart_Info1})
	[[ -z ${TRIM_Command} ]] && TRIM_Command=不可用
	Power_On=$(grep "Power_On" ${Smart_Info1} | awk '{print $NF}')
	Power_Cycle_Count=$(grep "Power_Cycle_Count" ${Smart_Info1} | awk '{print $NF}')
	[[ -z ${Power_On} ]] && {
		Power_Status=未知
	} || {
		Power_Status="${Power_On} 小时 / ${Power_Cycle_Count} 次"
	}
	if [[ $(getinf "Rotation Rate:" ${Smart_Info2}) =~ "Solid State" ]];then
		Phy_Type=固态硬盘
		Phy_RPM=不可用
	else
		Phy_Type=其他硬盘
		if [[ $(getinf "Rotation Rate:" ${Smart_Info2}) =~ rpm ]];then
			Phy_RPM="$(getinf "Rotation Rate:" ${Smart_Info2})"
			Phy_Type=机械硬盘
		else
			Phy_RPM=不可用
		fi
	fi
	[[ -z ${Phy_Name} ]] && {
		Phy_Name="$(getinf Vendor: ${Smart_Info2})$(getinf Product: ${Smart_Info2})"
	}
	Phy_LB=$(getinf "Logical block size:" ${Smart_Info2})
	Phy_PB=$(getinf "Physical block size:" ${Smart_Info2})
	if [[ -n ${Phy_PB} ]];then
		Phy_BS="${Phy_LB} / ${Phy_PB}"
	else
		Phy_BS="${Phy_LB}"
	fi
	Phy_Localtime=$(getinf "Local Time is:" ${Smart_Info2})
	cat <<EOF

	硬盘型号: ${Phy_Name}
	硬盘尺寸: ${Phy_Factor}
	硬盘 ID : ${Phy_ID}
	硬盘容量: ${Phy_Capacity}
	健康状况: ${Phy_Health}
	分区数量: ${Phy_Part_Number}
	SATA 版本: ${Phy_Sata_Version}
	TRIM 指令: ${TRIM_Command}
	硬盘类型: ${Phy_Type}
	硬盘转速: ${Phy_RPM}
	扇区大小: ${Phy_BS}
	通电情况: ${Power_Status}

========================================================

EOF
}

AutoInstall_UI_mod() {
	[[ $(opkg list | awk '{print $1}') =~ $2 ]] > /dev/null 2>&1 && {
		echo "$1. 安装 [$2] [已安装]"
	} ||  echo "$1. 未安装 [$2] [已安装]"
}

Install_opkg_mod() {
	opkg install ${*}
	[[ $(opkg list | awk '{print $1}') =~ $1 ]] > /dev/null 2>&1 && {
		ECHO y "$1 安装成功!"
	} || ECHO r "$1 安装失败!"
	sleep 2
}

Enter() {
	echo "" && read -p "按下[回车]键以继续..." Key
}

White="\e[0m"
Yellow="\e[33m"
Red="\e[31m"
Blue="\e[34m"
Skyb="\e[36m"

Main_tmp="/tmp/AutoBuild_Tools"
Disk_List="${Main_tmp}/Disk_List"
Block_Info="${Main_tmp}/Block_Info"
Disk_Processed_List="${Main_tmp}/Disk_Processed_List"
Phy_Disk_List="${Main_tmp}/Phy_Disk_List"
Smart_Info1="${Main_tmp}/Smart_Info1"
Smart_Info2="${Main_tmp}/Smart_Info2"
[[ ! -d ${Main_tmp} ]] && mkdir -p "${Main_tmp}"
Github_Raw="https://raw.githubusercontent.com/Hyy2001X/AutoBuild-Actions/master"
AutoBuild_Tools