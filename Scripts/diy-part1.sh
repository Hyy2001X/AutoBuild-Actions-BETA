#!/bin/bash

AutoUpdate_Github=https://github.com/Hyy2001X/Openwrt-AutoUpdate

ExtraPackages() {
[ -d ./package/lean/$2 ] && rm -rf ./package/lean/$2
[ -d ./$2 ] && rm -rf ./$2
while [ ! -f $2/Makefile ]
do
	echo "Checking out $2 from $3 ..."
	if [ $1 == git ];then
		git clone -b $4 $3/$2 $2 > /dev/null 2>&1
	else
		svn checkout $3/$2 $2 > /dev/null 2>&1
	fi
	if [ ! -f $2/Makefile ];then
		echo "Checkout failed,retry in 3s."
		rm -rf $2 > /dev/null 2>&1
		sleep 3
	fi
done
echo "Package $2 detected!"
mv $2 ./package/lean
}

sed -i "s/#src-git helloworld/src-git helloworld/g" feeds.conf.default
ExtraPackages git luci-theme-argon https://github.com/jerrykuku 18.06
ExtraPackages svn luci-app-openclash https://github.com/vernesong/OpenClash/trunk
ExtraPackages svn luci-app-adguardhome https://github.com/Lienol/openwrt/trunk/package/diy
ExtraPackages svn luci-app-smartdns https://github.com/project-openwrt/openwrt/trunk/package/ntlf9t
ExtraPackages svn smartdns https://github.com/project-openwrt/openwrt/trunk/package/ntlf9t
[ -d ./Openwrt-AutoUpdate ] && rm -rf ./Openwrt-AutoUpdate
git clone -b master $AutoUpdate_Github
mv Openwrt-AutoUpdate/AutoUpdate.sh ./package/base-files/files/bin
