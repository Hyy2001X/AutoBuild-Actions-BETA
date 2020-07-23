#!/bin/bash
rm -rf openwrt/package/lean/luci-theme-argon
git clone -b 18.06 https://github.com/jerrykuku/luci-theme-argon
mv luci-theme-argon openwrt/package/lean/
