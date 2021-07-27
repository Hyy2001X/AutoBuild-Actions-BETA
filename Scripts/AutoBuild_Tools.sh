#!/bin/bash
# AutoBuild Module by Hyy2001 <https://github.com/Hyy2001X/AutoBuild-Actions>
# AutoBuild_Tools for Openwrt
# Depends on: bash wget curl block-mount e2fsprogs smartmontools

Version=V1.6

ECHO() {
	local Color
	case $1 in
		r) Color="${Red}";;
		g) Color="${Green}";;
		b) Color="${Blue}";;
		y) Color="${Yellow}";;
		x) Color="${Grey}";;
	esac
	[[ $# -gt 1 ]] && shift
	echo -e "${White}${Color}${*}${White}"
}

AutoBuild_Tools() {
while :
do
	clear
	ECHO y "$(cat /etc/banner)"
	ECHO x "\n\nAutoBuild 固件工具箱 ${Version}\n"
	echo "1. USB 空间扩展"
	echo "2. Samba 一键共享"
	echo "3. 安装依赖包"
	echo "4. 端口占用列表"
	echo "5. 查看硬盘信息"
	ECHO x "\nu. 固件更新"
	ECHO y "x. 更新脚本"
	echo -e "q. 退出程序\n"
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
			ECHO r "\n未检测到 '/bin/AutoUpdate.sh',请确保当前固件支持一键更新!"
		}
	;;
	x)
		
		wget -q ${Github_Raw}/Scripts/AutoBuild_Tools.sh -O ${Main_tmp}/AutoBuild_Tools.sh
		if [[ $? == 0 ]];then
			ECHO y "\n[AutoBuild_Tools] 脚本更新成功!"
			rm -f /bin/AutoBuild_Tools.sh.sh
			mv -f ${Main_tmp}/AutoBuild_Tools.sh /bin
			chmod +x /bin/AutoBuild_Tools.sh
		else
			ECHO r "\n[AutoBuild_Tools] 脚本更新失败!"
		fi
		sleep 2
	;;
	1)
		which block > /dev/null 2>&1
		[[ ! $? -eq 0 ]] && {
			ECHO r "\n缺少相应依赖包,请先安装 [block-mount] !"
			sleep 3
		} || {
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
			ECHO r "\n缺少相应依赖包,请先安装 [smartmontools] !"
			sleep 3
		} || Smart_Info
	;;
	esac
done
}

AutoExpand_UI() {
	clear
	ECHO x "一键使用 USB 扩展内部空间"
	USB_Info
	[[ -s ${Block_Info} ]] && {
		echo "   设备		硬盘格式	挂载点		可用空间"
		cat ${Disk_Processed_List} | while read Disk_info ;do
			List_Disk ${Disk_info}
		done
		echo -e "\nq. 返回"
		echo "r. 重新载入列表"
	} || {
		ECHO r "未检测到任何外接设备!"
		sleep 3
		return 1
	}
	local Logic_Disk_Count=$(sed -n '$=' ${Logic_Disk_List})
	echo ""
	read -p "请输入要操作的硬盘编号[1-${Logic_Disk_Count}]:" Choose
	case ${Choose} in
	q)
		return
	;;
	r)
		AutoExpand_UI
	;;
	*)
		[[ ${Choose} =~ [0-9] && ${Choose} -le ${Logic_Disk_Count} && ${Choose} -gt 0 ]] > /dev/null 2>&1 && {
			which mkfs.ext4 > /dev/null 2>&1
			if [[ $? == 0 ]];then
				Choose_Disk=$(sed -n ${Choose}p ${Disk_Processed_List} | awk '{print $1}')
				Choose_Mount=$(grep "${Choose_Disk}" ${Disk_Processed_List} | awk '{print $4}')
				AutoExpand_Core ${Choose_Disk} ${Choose_Mount}
			else
				ECHO r "\n系统缺少相应依赖包,请先安装 [e2fsprogs] !" && sleep 3
				return
			fi
		} || {
			ECHO r "\n输入错误,请输入正确的选项!"
			sleep 2 && AutoExpand_UI
		}
	;;
	esac
}

USB_Info() {
	echo -ne "\nLoading USB Configuration ..."
	local Disk_Name Logic_Mount Logic_Format Logic_Available
	rm -f ${Block_Info} ${Logic_Disk_List} ${Disk_Processed_List} ${Phy_Disk_List} ${UUID_List}
	touch ${Disk_Processed_List} ${UUID_List}
	block mount
	block info | grep -v "mtdblock" | grep "sd[a-z][0-9]" > ${Block_Info}
	[[ -s ${Block_Info} ]] && {
		cat ${Block_Info} | awk -F ':' '/sd/{print $1}' > ${Logic_Disk_List}
		for Disk_Name in $(cat ${Logic_Disk_List})
		do
			UUID=$(grep "${Disk_Name}" ${Block_Info} | egrep -o 'UUID=".+"' | awk -F '["]' '/UUID/{print $2}')
			Logic_Mount=$(grep "${Disk_Name}" ${Block_Info} | egrep -o 'MOUNT="/[0-9a-zA-Z].+"|MOUNT="/"' | awk -F '["]' '/MOUNT/{print $2}')
			[[ -z ${Logic_Mount} ]] && Logic_Mount="$(df | grep "${Disk_Name}" | awk '{print $6}' | awk 'NR==1')"
			Logic_Format="$(grep "${Disk_Name}" ${Block_Info} | egrep -o 'TYPE="[0-9a-zA-Z].+' | awk -F '["]' '/TYPE/{print $2}')"
			Logic_Available="$(df -h | grep "${Disk_Name}" | awk '{print $4}' | awk 'NR==1')"
			echo "${Disk_Name}	${UUID}	${Logic_Format}	${Logic_Mount}	${Logic_Available}" >> ${Disk_Processed_List}
		done
		grep -o "/dev/sd[a-z]" ${Logic_Disk_List} | sort | uniq > ${Phy_Disk_List}
	}
	echo -ne "\r                             \r"
	return
}

List_Disk() {
	[[ $4 == / ]] && {
		echo "$(awk '{print $1}' ${Disk_Processed_List} | grep -n "$1" | cut -d ':' -f1). $1	$3		$4		$5"
	} || {
		echo "$(awk '{print $1}' ${Disk_Processed_List} | grep -n "$1" | cut -d ':' -f1). $1	$3		$4	$5"
	}
}

AutoExpand_Core() {
	ECHO r "\n警告: 操作开始后请不要中断任务或进行其他操作,否则可能导致设备数据丢失 !"
	ECHO r "同时连接多个 USB 设备可能导致分区错位路由器不能正常启动 !"
	ECHO r "\n本操作将把设备 '$1' 格式化为 ext4 格式,请提前做好数据备份工作 !"
	read -p "是否执行格式化操作?[Y/n]:" Choose
	[[ ${Choose} == [Yesyes] ]] && {
		ECHO y "\n开始运行脚本 ..."
		sleep 3
	} || return 0
	echo "禁用自动挂载 ..."
	uci set fstab.@global[0].auto_mount='0'
	uci commit fstab
	[[ -n $2 ]] && {
		echo "卸载设备 '$1' 位于 '$2' ..."
		umount -l $2 > /dev/null 2>&1
		[[ $? != 0 ]] && {
			ECHO r "设备 '$2' 卸载失败 !"
			exit 1
		}
	}
	echo "正在格式化设备 '$1' 为 ext4 格式,请耐心等待 ..."
	mkfs.ext4 -F $1 > /dev/null 2>&1
	[[ $? == 0 ]] && {
		echo "设备 '$1' 已成功格式化为 ext4 格式 !"
		USB_Info
	} || {
		ECHO r "设备 '$1' 格式化失败 !"
		exit 1
	}
	local UUID=$(grep "$1" ${Disk_Processed_List} | awk '{print $2}')
	echo "UUID: ${UUID}"
	echo "挂载设备 '$1' 到 ' /tmp/extroot' ..."
	mkdir -p /tmp/introot || {
		ECHO r "临时文件夹 '/tmp/introot' 创建失败 !"
		exit 1
	}
	mkdir -p /tmp/extroot || {
		ECHO r "临时文件夹 '/tmp/extroot' 创建失败 !"
		exit 1
	}
	mount --bind / /tmp/introot || {
		ECHO r "挂载 '/' 到 '/tmp/introot' 失败 !"
		exit 1

	}
	mount $1 /tmp/extroot || {
		ECHO r "挂载 '$1' 到 '/tmp/extroot' 失败 !"
		exit 1

	}
	echo "正在复制系统文件到 '$1' ..."
	tar -C /tmp/introot -cf - . | tar -C /tmp/extroot -xf -
	echo "卸载设备 '/tmp/introot' '/tmp/extroot' ..."
	umount /tmp/introot
	umount /tmp/extroot
	sync
	for ((i=0;i<=10;i++));do
		uci delete fstab.@mount[0] > /dev/null 2>&1
	done
	echo "写入新分区表到 '/etc/config/fstab' ..."
	cat >> /etc/config/fstab <<EOF
config mount
        option enabled '1'
        option uuid '${UUID}'
        option target '/'

EOF
	uci commit fstab
	ECHO y "\n运行结束,外接设备 '$1' 已挂载到系统分区 !\n"
	ECHO r "警告: 固件更新将会导致扩容失效,当前硬盘数据将会丢失,请提前做好备份工作 !\n"
	read -p "操作需要重启生效,是否立即重启?[Y/n]:" Choose
	[[ ${Choose} == [Yesyes] ]] && {
		ECHO g "\n正在重启设备,请耐心等待 ..."
		sync
		reboot
		exit
	} || exit
}

AutoSamba_UI() {
	USB_Info
	Samba_tmp="${Main_tmp}/AutoSamba"
	Samba_UCI_List="${Main_tmp}/UCI_List"
	[[ ! -d ${Main_tmp} ]] && mkdir -p "${Main_tmp}"
	while :
	do
		clear
		ECHO x "Samba 工具箱\n"
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
			ECHO y "\n已${autosamba_mode} Samba 自动共享!"
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
	ECHO y "\n已删除所有 Samba 挂载点!"
	sleep 2
}

Mount_Samba_Devices() {
	Logic_Disk_Count=$(sed -n '$=' ${Disk_Processed_List})
	for ((i=1;i<=${Logic_Disk_Count};i++));
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
	ECHO x "安装依赖包\n"
	AutoInstall_UI_mod 1 block-mount
	AutoInstall_UI_mod 2 e2fsprogs
	AutoInstall_UI_mod 3 smartmontools
	echo "u. 更新软件包列表"
	echo -e "\nq. 返回\n"
	read -p "请从上方选择一个操作:" Choose
	echo ""
	case $Choose in
	q)
		break
	;;
	u)
		opkg update
		sleep 3
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
	echo "2. 强制更新固件 (跳过版本号、SHA256 校验,并强制刷写固件) [保留配置]"
	echo "3. 不保留配置更新固件 [全新安装]"
	echo "4. 列出固件信息"
	echo "5. 清除固件下载缓存"
	echo "6. 更改 Github API 地址"
	echo "7. 指定 x86 设备下载 UEFI/Legacy 引导的固件"
	ECHO y "\nx. 更新 [AutoUpdate] 脚本"
	echo -e "q. 返回\n"
	read -p "请从上方选择一个操作:" Choose
	case ${Choose} in
	q)
		break
	;;
	x)
		bash /bin/AutoUpdate.sh -x
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
			ECHO r "\nGithub 地址不能为空!"
		}
		sleep 2
	;;
	7)
		echo ""
		read -p "请输入你想要的启动方式[UEFI/Legacy]:" _BOOT
		[[ -n ${_BOOT} ]] && bash /bin/AutoUpdate.sh -B ${_BOOT} || {
			ECHO r "\n启动方式不能为空!"
		}
		sleep 2
	;;
	esac
done
}

Smart_Info() {
	USB_Info
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
		ECHO y "\n$1 安装成功!"
	} || ECHO r "\n$1 安装失败!"
	sleep 2
}

Enter() {
	echo "" && read -p "按下[回车]键以继续..." Key
}

White="\e[0m"
Yellow="\e[33m"
Red="\e[31m"
Blue="\e[34m"
Grey="\e[36m"
Green="\e[32m"

Main_tmp="/tmp/AutoBuild_Tools"
Logic_Disk_List="${Main_tmp}/Logic_Disk_List"
Phy_Disk_List="${Main_tmp}/Phy_Disk_List"
Block_Info="${Main_tmp}/Block_Info"
Disk_Processed_List="${Main_tmp}/Disk_Processed_List"
Smart_Info1="${Main_tmp}/Smart_Info1"
Smart_Info2="${Main_tmp}/Smart_Info2"
[[ ! -d ${Main_tmp} ]] && mkdir -p "${Main_tmp}"
Github_Raw="https://raw.githubusercontent.com/Hyy2001X/AutoBuild-Actions/master"
AutoBuild_Tools