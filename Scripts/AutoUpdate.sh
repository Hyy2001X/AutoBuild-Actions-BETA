#!/bin/bash
# https://github.com/Hyy2001X/AutoBuild-Actions
# AutoBuild Module by Hyy2001
# AutoUpdate for Openwrt

Version=V5.1

TIME() {
	echo -ne "\n[$(date "+%H:%M:%S")] "
}

Install_Pkg() {
	PKG_NAME=${1}
	grep "${PKG_NAME}" /tmp/Package_list > /dev/null 2>&1
	if [[ $? -ne 0 ]];then
		if [[ "${Force_Update}" == "1" ]] || [[ "${AutoUpdate_Mode}" == "1" ]];then
			Choose="Y"
		else
			TIME && read -p "未安装[${PKG_NAME}],是否执行安装?[Y/n]:" Choose
		fi
		if [[ "${Choose}" == Y ]] || [[ "${Choose}" == y ]];then
			TIME && echo -e "开始安装[${PKG_NAME}],请耐心等待...\n"
			opkg update > /dev/null 2>&1
			opkg install ${PKG_NAME}
			if [[ $? -ne 0 ]];then
				TIME && echo "[${PKG_NAME}] 安装失败,请尝试手动安装!"
				exit
			else
				TIME && echo "[${PKG_NAME}] 安装成功!"
			fi
		else
			TIME && echo "用户已取消安装,即将退出更新脚本..."
			sleep 2
			exit
		fi
	fi
}

opkg list | awk '{print $1}' > /tmp/Package_list
Input_Option="$1"
Input_Other="$2"
CURRENT_Version="$(awk 'NR==1' /etc/openwrt_info)"
Github="$(awk 'NR==2' /etc/openwrt_info)"
DEFAULT_Device="$(awk 'NR==3' /etc/openwrt_info)"
Firmware_Type="$(awk 'NR==4' /etc/openwrt_info)"
case ${DEFAULT_Device} in
x86_64)
	[[ -z ${Firmware_Type} ]] && Firmware_Type="img"
	if [[ "${Firmware_Type}" == "img.gz" ]];then
		Compressed_x86="1"
	else
		Compressed_x86="0"
	fi
	if [ -d /sys/firmware/efi ];then
		EFI_Boot="1"
		BOOT_Type="-UEFI"
	else
		EFI_Boot="0"
		BOOT_Type="-Legacy"
	fi
	Firmware_SFX="${BOOT_Type}.${Firmware_Type}"
	Firmware_Detail="${BOOT_Type}.detail"
	CURRENT_Device="x86_64"
;;
*)
	CURRENT_Device="$(jsonfilter -e '@.model.id' < /etc/board.json | tr ',' '_')"
	Firmware_SFX=".${Firmware_Type}"
	[[ -z ${Firmware_SFX} ]] && Firmware_SFX="bin"
	Firmware_Detail=".detail"
esac
Github_Download="${Github}/releases/download/AutoUpdate"
Author="${Github##*com/}"
Github_Tags="https://api.github.com/repos/${Author}/releases/latest"
Disk_List="/tmp/disk_list"
[ -f ${Disk_List} ] && rm -f ${Disk_List}
Check_Disk="$(mount | egrep -o "mnt/+sd[a-zA-Z][0-9]+")"
if [ ! -z "${Check_Disk}" ];then
	echo "${Check_Disk}" > ${Disk_List}
	Disk_Number=$(sed -n '$=' ${Disk_List})
	if [ ${Disk_Number} -gt 1 ];then
		for Disk_Name in $(cat ${Disk_List})
		do
			Disk_Available="$(df -m | grep "${Disk_Name}" | awk '{print $4}')"
			if [ "${Disk_Available}" -gt 20 ];then
				Download_Path="/${Disk_Name}"
				break
			else
				Download_Path="/tmp"
			fi
		done
	else
		Disk_Name="${Check_Disk}"
		Disk_Available="$(df -m | grep "${Disk_Name}" | awk '{print $4}')"
		if [ "${Disk_Available}" -gt 200 ];then
			Download_Path="/${Disk_Name}"
		else
			Download_Path="/tmp"
		fi
	fi
else
	Disk_Number="0"
	Disk_Available="0"
	Download_Path="/tmp"
fi
[ ! -d "${Download_Path}/Downloads" ] && mkdir -p ${Download_Path}/Downloads
cd /etc
clear && echo "Openwrt-AutoUpdate Script ${Version}"
if [[ -z "${Input_Option}" ]];then
	Upgrade_Options="-q" && TIME && echo "执行: 保留配置更新固件[静默模式]"
else
	case ${Input_Option} in
	-n)
		TIME && echo "执行: 更新固件(不保留配置)"
	;;
	-q)
		TIME && echo "执行: 更新固件(保留配置)"
	;;
	-f)
		Force_Update="1"
		Upgrade_Options="-q"
		TIME && echo "执行: 强制更新固件(保留配置)"
	;;
	-u)
		AutoUpdate_Mode="1"
		Upgrade_Options="-q"
	;;
	-s)
		Stable_Mode="1"
		Upgrade_Options="-q"
		TIME && echo "执行: 更新固件到最新稳定版本(保留配置)"
	;;
	-sn|-ns)
		Stable_Mode="1"
		Upgrade_Options="-n"
		TIME && echo "执行: 更新固件到最新稳定版本(不保留配置)"
	;;
	-c)
		if [[ ! -z "${Input_Other}" ]];then
			sed -i "s?${Github}?${Input_Other}?g" /etc/openwrt_info > /dev/null 2>&1
			echo -e "\nGithub 地址已更换为: ${Input_Other}"
			unset Input_Other
		else
			echo -e "\n使用方法: bash /bin/AutoUpdate.sh -c [地址]"
		fi
		exit
	;;
	-l)
		Overlay_Size="$(df -h | grep ":/overlay" | awk '{print $4}')"
		TMP_Size="$(df -h | grep "tmp" | awk '{print $4}' | awk 'NR==1')"
		echo -e "\n传入参数:	bash ${0} ${@}"
		echo "参数个数:	$#"
		echo "/overlay 可用:	${Overlay_Size}"
		echo "/tmp 可用:	${TMP_Size}"
		echo "硬盘个数:	${Disk_Number}"
		echo "硬盘可用:	${Disk_Available}M"
		echo "固件下载位置:	${Download_Path}/Downloads"
		echo "当前版本:	${CURRENT_Version}"
		echo "Github 地址:	${Github}"
		echo "默认设备:	${DEFAULT_Device}"
		echo "当前设备:	${CURRENT_Device}"
		echo "固件下载地址:	${Github_Download}"
		echo "API地址:	${Github_Tags}"
		echo "作者/仓库:	${Author}"
		if [[ ${DEFAULT_Device} == "x86_64" ]];then
			echo "EFI 引导: 	${EFI_Boot}"
			echo "gz 压缩:	${Compressed_x86}"
		fi
		echo "固件格式:	${Firmware_SFX}"
		exit
	;;
	*)
		echo -e "\n使用方法: bash /bin/AutoUpdate.sh [参数1] [参数2]"
		echo -e "\n可供使用的[参数]:\n"
		echo "	-q	更新固件,不打印备份信息日志[保留配置]"
		echo "	-n	更新固件[不保留配置]"
		echo "	-f	强制更新固件,即跳过版本号验证,自动下载以及安装必要软件包[保留配置]"
		echo "	-u	适用于定时更新的参数,自动下载以及安装必要软件包[保留配置]"
		echo "	-s	更新/回退固件到最新的稳定版本[保留配置]"
		echo "	-sn	更新/回退固件到最新的稳定版本[不保留配置]"
		echo "	-c	[地址] 更换 Github 检查更新地址"
		echo "	-l	列出所有信息"
		echo -e "\nGithub地址:	${Github}"
		echo -e "当前设备:	${DEFAULT_Device}\n"
		exit
	;;
	esac
	if [[ ! "${Force_Update}" == "1" ]] && [[ ! "${AutoUpdate_Mode}" == "1" ]] && [[ ! "${Stable_Mode}" == "1" ]];then
		Upgrade_Options="${Input_Option}"
	fi
fi
if [[ ! "${Force_Update}" == "1" ]] && [[ ! "${AutoUpdate_Mode}" == "1" ]];then
	grep "curl" /tmp/Package_list > /dev/null 2>&1
	if [[ ! $? -ne 0 ]];then
		Google_Check=$(curl -I -s --connect-timeout 5 www.google.com -w %{http_code} | tail -n1)
		[ ! "$Google_Check" == 200 ] && TIME && echo "Google 连接失败,可能导致固件下载速度缓慢!"
	fi
fi
Install_Pkg wget
if [[ -z "${CURRENT_Version}" ]];then
	TIME && echo "警告: 当前固件版本获取失败!"
	CURRENT_Version="未知"
fi
if [[ -z "${CURRENT_Device}" ]];then
	[[ "${Force_Update}" == "1" ]] && exit
	TIME && echo "警告: 当前设备名称获取失败,使用预设名称[$DEFAULT_Device]"
	CURRENT_Device="${DEFAULT_Device}"
fi
TIME && echo "正在检查版本更新..."
[ ! -f /tmp/Github_Tags ] && touch /tmp/Github_Tags
wget -q ${Github_Tags} -O - > /tmp/Github_Tags
if [[ ! "$?" == 0 ]];then
	TIME && echo "检查更新失败,请稍后重试!"
	exit
fi
if [[ ${Stable_Mode} == 1 ]];then
	GET_Version_Type="-Stable"
else
	GET_Version_Type=""
fi
GET_FullVersion=$(cat /tmp/Github_Tags | egrep -o "AutoBuild-${CURRENT_Device}-R[0-9]+.[0-9]+.[0-9]+.[0-9]+${GET_Version_Type}" | awk 'END {print}')
GET_Version="${GET_FullVersion#*${CURRENT_Device}-}"
if [[ -z "${GET_FullVersion}" ]] || [[ -z "${GET_Version}" ]];then
	TIME && echo "检查更新失败,请稍后重试!"
	exit
fi
echo -e "\n固件作者: ${Author%/*}"
echo "设备名称: ${DEFAULT_Device}"
echo "固件格式: ${Firmware_SFX}"
echo -e "\n当前固件版本: ${CURRENT_Version}"
echo "云端固件版本: ${GET_Version}"
[[ -z "${Firmware_Type}" ]] && TIME && echo "[固件格式] 获取失败!" && exit
Check_Stable_Version=$(echo ${GET_Version} | egrep -o "R[0-9]+.[0-9]+.[0-9]+.[0-9]+")
if [[ ! ${Force_Update} == 1 ]];then
	if [[ "${CURRENT_Version}" == "${Check_Stable_Version}" ]];then
		[[ "${AutoUpdate_Mode}" == "1" ]] && exit
		TIME && read -p "已是最新版本,是否强制更新固件?[Y/n]:" Choose
		if [[ "${Choose}" == Y ]] || [[ "${Choose}" == y ]];then
			TIME && echo "开始强制更新固件..."
		else
			TIME && echo "已取消强制更新,即将退出更新程序..."
			sleep 1
			exit
		fi
	fi
fi
Firmware_Info="${GET_FullVersion}"
Firmware="${Firmware_Info}${Firmware_SFX}"
Firmware_Detail="${Firmware_Info}${Firmware_Detail}"
echo -e "\n云端固件名称: ${Firmware}"
echo "固件下载地址: ${Github_Download}"
cd ${Download_Path}/Downloads
echo "固件保存位置: ${Download_Path}/Downloads"
TIME && echo "正在下载固件,请耐心等待..."
wget -q "${Github_Download}/${Firmware}" -O ${Firmware}
if [[ ! "$?" == 0 ]];then
	TIME && echo "固件下载失败,请检查网络后重试!"
	exit
fi
TIME && echo "固件下载成功!"
TIME && echo "正在获取云端固件MD5,请耐心等待..."
wget -q ${Github_Download}/${Firmware_Detail} -O ${Firmware_Detail}
if [[ ! "$?" == 0 ]];then
	TIME && echo "MD5 获取失败,请检查网络后重试!"
	exit
fi
GET_MD5=$(awk -F '[ :]' '/MD5/ {print $2;exit}' ${Firmware_Detail})
CURRENT_MD5=$(md5sum ${Firmware} | cut -d ' ' -f1)
echo -e "\n本地固件MD5:${CURRENT_MD5}"
echo "云端固件MD5:${GET_MD5}"
if [[ -z "${GET_MD5}" ]] || [[ -z "${CURRENT_MD5}" ]];then
	TIME && echo -e "MD5 获取失败!"
	exit
fi
if [[ ! "${GET_MD5}" == "${CURRENT_MD5}" ]];then
	TIME && echo -e "MD5 对比失败,请检查网络后重试!"
	exit
else
	TIME && echo -e "MD5 对比通过!"
fi
if [[ ${Compressed_x86} == "1" ]];then
	TIME && echo "检测到固件为 [.gz] 压缩格式,开始解压固件..."
	Install_Pkg gzip
	Firmware="${Firmware_Info}${BOOT_Type}.img"
	rm -f ${Firmware} > /dev/null 2>&1
	gzip -dk ${Firmware} > /dev/null 2>&1
	if [ -f "${Firmware}" ];then
		TIME && echo "固件解压成功,固件名称: ${Firmware}"
	else
		TIME && echo "固件解压失败,请检查相关信息!"
		exit
	fi
fi
TIME && echo -e "开始更新固件,请耐心等待路由器重启...\n"
sleep 3
sysupgrade ${Upgrade_Options} ${Firmware}
if [[ $? -ne 0 ]];then
	TIME && echo "固件刷写失败,请尝试不保留配置[-n]或手动下载固件!"
	exit
fi