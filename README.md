# AutoBuild-Actions

Actions for Building OpenWRT

测试通过的设备: **!x86**、`d-team_newifi-d2`、`phicomm_k2p`

使用方法/Usage:
------

1. 首先需要获取[Github Token](https://github.com/settings/tokens/new),`Note`项随意填写,`Select scopes`项如果不懂就全部打勾,完成后点击`Generate token`

2. 复制获取到的Token值,**一定要保存到本地,Token值只会显示一次!**

3. `Fork`此仓库,然后进入你的`AutoBuild-Actions`仓库

4. 点击右上方菜单中的`Settings`,点击`Secrets`-`New Secrets`,`Name`项填写`RELEASE_TOKEN`,`Value`项填写你在第 1 步中获取到的Token

客制化固件:
------

1. 进入你的`AutoBuild-Actions`仓库

2. 编辑`/Customize/AutoUpdate.sh`文件,修改`第 7 行`为你要编译的设备名称,修改`第 8 行`为你的 Github 地址

3. 编辑`/Sctipts/diy-script.sh`文件,修改`第 7 行`为作者,作者将在路由器后台显示`Compiled by Hyy2001`

4. **添加额外的软件包:** 编辑`Scrips/diy-script.sh`中的 `Diy-Part1()` 函数,参照下方语法添加第三方包到源码
```
   [git clone]     ExtraPackages git Github仓库 远程分支
    
   [svn checkout]  ExtraPackages svn Github仓库/trunk
```

5. **添加自定义文件:** 首先上传自定义文件到`/Customize`,然后编辑 `Diy-Part1()` 函数,参照参照现有 `mv2` 语法添加自定义文件到源码

自动编译&&升级固件:
------

1. 进入你的`AutoBuild-Actions`仓库

2. 编辑`/.github/workflows/AutoBuild.yml`文件,取消注释`第 21-22 行`,并按需修改

3. 打开Openwrt管理界面,点击`系统`-`定时更新`,设置自动升级的时间并保存(**需要 [luci-app-autoupdate](https://github.com/Hyy2001X/luci-app-autoupdate) 支持**)

使用指令升级固件:
------

在终端输入: `bash /bin/AutoUpdate.sh`

不保留配置升级: `bash /bin/AutoUpdate.sh -n`

使用最新脚本升级: `curl -s https://raw.githubusercontent.com/Hyy2001X/Openwrt-AutoUpdate/master/AutoUpdate.sh | bash`

