## Actions for Building OpenWRT

![GitHub Stars](https://img.shields.io/github/stars/Hyy2001X/AutoBuild-Actions.svg?style=flat-square&label=Stars&logo=github)
![GitHub Forks](https://img.shields.io/github/forks/Hyy2001X/AutoBuild-Actions.svg?style=flat-square&label=Forks&logo=github)

**自动编译:本项目将在每天 19:00 自动编译固件,如需自助更新请点击 ***Star*****

测试通过的设备: `d-team_newifi-d2`、`phicomm_k2p`

测试通过的源码: [Lede](https://github.com/coolsnowwolf/lede)

## Github Actions 部署指南(STEP 1):

1. 首先需要获取[Github Token](https://github.com/settings/tokens/new),`Note`项随意填写,`Select scopes`**全部打勾**,完成后点击`Generate token`

2. 复制页面中显示的 **Token**

   **注意: 一定要第一时间保存到本地, Token 值只会显示一次!**

3. ***Fork*** 此仓库,然后进入你的`AutoBuild-Actions`仓库

4. 点击右上方菜单中的`Settings`,点击`Secrets`-`New Secrets`,`Name`项填写`RELEASE_TOKEN`,`Value`项粘贴你在第 2 步中复制的 **Token** 

   **注意: 以上操作只需操作一次!**

## 客制化固件(STEP 2):

1. 进入你的`AutoBuild-Actions`仓库

2. 首先需要将本地的 '.config' 文件**重命名**并上传到`AutoBuild-Actions`仓库根目录

3. 编辑`.github/workflows/AutoBuild.yml`文件,修改`第 27 行`为你上传的 '.config' 文件名称

4. 编辑`Scripts/AutoBuild_DiyScript.sh`文件,修改`第 7 行`为作者,作者将在 OpenWrt 首页显示

   **Diy_Core 下的名词解释:**
```
   Author 作者名称,这个名称将在 OpenWrt 首页显示
   
   Default_Device 路由器的完整名称,例如 d-team_newifi-d2 phicomm_k2p,用于无法从 .config 正常获取设备时备用
   
   INCLUDE_AutoUpdate 启用后,将自动添加 AutoUpdate.sh 和 luci-app-autoupdate 到固件
   
   INCLUDE_AutoBuild_Tools 自动添加 AutoBuild_Tools 到固件
   
   INCLUDE_SSR_Plus 自动添加 fw876 的 SSR Plus+ 仓库到源码目录
   
   INCLUDE_Passwall 自动添加 xiaorouji 的 openwrt-passwall 仓库到源码目录
   
   INCLUDE_Latest_Xray 启用后,将自动更新 v2ray v2ray-plugin xray 到最新版本
   
   INCLUDE_mt7621_OC1000MHz 启用后,mt7621 系列的路由器将自动超频到 1000MHz
   
   INCLUDE_Enable_FirewallPort_53 启用后,自动注释防火墙-自定义规则中的两行 53 端口重定向

```

5. **手动启动编译**: 点击右上方 ***Star*** 即可开始编译,最好先同步我的最新改动~~以获得更多特性(bug)~~

   **AutoBuild 特有指令:** 编辑`Scripts/AutoBuild_DiyScript.sh`,参照下方语法:
```
   [git clone -b]  ExtraPackages git 安装位置 软件包名 Github仓库地址 远程分支
    
   [svn checkout]  ExtraPackages svn 安装位置 软件包名 Github仓库地址/trunk
   
   [mv -f] Replace_File 文件名称 目标路径 重命名文件(可选)
   
   [mkdir -p] Mkdir 文件夹名称
   
   [更新 Makefile] Update_Makefile 软件包名 软件包路径 (仅支持部分软件包,自行测试)
   
```

## 自动编译 && 定时更新:

1. 进入你的`AutoBuild-Actions`仓库

2. 编辑`.github/workflows/AutoBuild.yml`文件,编辑`第 21 行`,并按需修改 corntab 参数(默认每天 19:00 开始编译)

3. 打开 Openwrt 主页,点击`系统`-`定时更新`,设置自动检查更新的时间并保存(需要 [luci-app-autoupdate](https://github.com/Hyy2001X/luci-app-autoupdate) 支持)

## 使用一键更新固件脚本:

   首先需要打开 Openwrt 主页,点击`系统`-`TTYD 终端`或者在浏览器输入`192.168.1.1:7681`,按需输入下方指令:
   
   检查更新(保留配置): `bash /bin/AutoUpdate.sh`

   检查更新(不保留配置): `bash /bin/AutoUpdate.sh -n`
   
   更新到最新稳定版(保留配置): `bash /bin/AutoUpdate.sh -s`
   
   更新到最新稳定版(不保留配置): `bash /bin/AutoUpdate.sh -sn`
   
## 使用一键扩展内部空间\挂载 Samba 共享脚本:

   同上方操作,打开`TTYD 终端`,输入`bash /bin/AutoBuild_Tools.sh`
   
## 鸣谢

   - [Lean's Openwrt](https://github.com/coolsnowwolf/lede)

   - [P3TERX](https://github.com/P3TERX/Actions-OpenWrt)
   
   - [CurssedCoffin](https://github.com/CurssedCoffin)
   
   - [Licsber](https://github.com/Licsber)
   
   - [mab-wien](https://github.com/mab-wien/openwrt-autoupdate)
