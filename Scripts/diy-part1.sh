#!/bin/bash

Github=https://github.com/Hyy2001X
AutoUpdate_Github=https://github.com/Hyy2001X/Openwrt-AutoUpdate

ExtraPackages() {
[ ! -d ./package/lean ] && mkdir ./package/lean
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
		echo "[$(date "+%H:%M:%S")] Package/Project $2 detected!"
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

sed -i "s/#src-git helloworld/src-git helloworld/g" feeds.conf.default
ExtraPackages git luci-theme-argon https://github.com/jerrykuku 18.06
ExtraPackages svn luci-app-adguardhome https://github.com/Lienol/openwrt/trunk/package/diy
ExtraPackages svn luci-app-smartdns https://github.com/project-openwrt/openwrt/trunk/package/ntlf9t
ExtraPackages svn smartdns https://github.com/project-openwrt/openwrt/trunk/package/ntlf9t
ExtraPackages git OpenClash https://github.com/vernesong master
ExtraPackages git Openwrt-AutoUpdate https://github.com/Hyy2001X master
