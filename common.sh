#!/bin/bash
# https://github.com/281677160/build-actions
# common Module by 28677160
# matrix.target=${FOLDER_NAME}

ACTIONS_VERSION="2.8.0"

function TIME() {
  case "$1" in
    r) local Color="\033[0;31m";;
    g) local Color="\033[0;32m";;
    y) local Color="\033[0;33m";;
    b) local Color="\033[0;34m";;
    z) local Color="\033[0;35m";;
    l) local Color="\033[0;36m";;
    *) local Color="\033[0;0m";;
  esac
echo -e "\n${Color}${2}\033[0m"
}

function variable() {
local overall="$1"
export "${overall}"
echo "${overall}" >> "${GITHUB_ENV}"
}

function Diy_variable() {
# 读取变量
case "${SOURCE_CODE}" in
IMMORTALWRT)
  variable REPO_URL="https://github.com/immortalwrt/immortalwrt"
  variable SOURCE="Immortalwrt"
  variable SOURCE_OWNER="ctcgfw"
  variable DISTRIB_SOURCECODE="immortalwrt"
  variable LUCI_EDITION="$(echo "${REPO_BRANCH}" |sed 's/openwrt-//g')"
  variable GENE_PATH="${HOME_PATH}/package/base-files/files/bin/config_generate"
;;
OFFICIAL)
  variable REPO_URL="https://github.com/openwrt/openwrt"
  variable SOURCE="Official"
  variable SOURCE_OWNER="openwrt"
  variable DISTRIB_SOURCECODE="official"
  variable LUCI_EDITION="$(echo "${REPO_BRANCH}" |sed 's/openwrt-//g')"
  variable GENE_PATH="${HOME_PATH}/package/base-files/files/bin/config_generate"
;;
*)
  TIME r "不支持${SOURCE_CODE}此源码，当前只支持IMMORTALWRT、OFFICIALT"
  exit 1
;;
esac

variable FILES_PATH="${HOME_PATH}/package/base-files/files/etc/shadow"
variable DELETE="${HOME_PATH}/package/base-files/files/etc/deletefile"
variable DEFAULT_PATH="${HOME_PATH}/package/auto-scripts/files/99-first-run"
variable KEEPD_PATH="${HOME_PATH}/package/base-files/files/lib/upgrade/keep.d/base-files-essential"
variable CLEAR_PATH="/tmp/Clear"
variable UPGRADE_DATE="`date -d "$(date +'%Y-%m-%d %H:%M:%S')" +%s`"
variable GUJIAN_DATE="$(date +%m.%d)"
variable LICENSES_DOC="${HOME_PATH}/LICENSES/doc"

# 启动编译时的变量文件
if [[ "${BENDI_VERSION}" == "2" ]]; then
  install -m 0755 /dev/null "${COMPILE_PATH}/relevance/settings.ini"
  VARIABLES=(
  "SOURCE_CODE" "REPO_BRANCH" "CONFIG_FILE"
  "INFORMATION_NOTICE" "UPLOAD_FIRMWARE" "UPLOAD_RELEASE"
  "CACHEWRTBUILD_SWITCH" "UPDATE_FIRMWARE_ONLINE"
  "COMPILATION_INFORMATION" "KEEP_WORKFLOWS" "KEEP_RELEASES"
  )
  for var in "${VARIABLES[@]}"; do
    echo "${var}=${!var}" >> "${COMPILE_PATH}/relevance/settings.ini"
  done

  if [[ "${REPO_URL}" == *"hanwckf"* ]]; then
    sed -i "/REPO_BRANCH/d" "${COMPILE_PATH}/relevance/settings.ini"
    echo "REPO_BRANCH=hanwckf-21.02" >> "${COMPILE_PATH}/relevance/settings.ini"
  fi
fi
}

function Diy_feedsconf() {
local LICENSES_DOC="${GITHUB_WORKSPACE}/openwrt/LICENSES/doc"
[[ ! -d "${LICENSES_DOC}" ]] && mkdir -p "${LICENSES_DOC}"
cp -Rf ${GITHUB_WORKSPACE}/openwrt/feeds.conf.default ${LICENSES_DOC}/feeds.conf.default
if [[ ! -f "${LICENSES_DOC}/feeds.conf.default" ]]; then
  TIME r "文件下载失败,请检查网络"
  exit 1
fi
}

function Diy_checkout() {
# 下载源码后，进行源码微调和增加插件源
TIME y "正在执行：下载和整理应用,请耐心等候..."
cd ${HOME_PATH}
# 添加auto-scripts
echo '#!/bin/sh' > "${DELETE}" && chmod +x "${DELETE}"
if [[ -d "${LINSHI_COMMON}/auto-scripts" ]]; then
  cp -Rf "$LINSHI_COMMON/auto-scripts" "${HOME_PATH}/package/auto-scripts"
else
  TIME r "缺少auto-scripts文件"
  exit 1
fi

sed -i 's/root:.*/root::0:0:99999:7:::/g' "${FILES_PATH}"
grep -q "admin:" ${FILES_PATH} && sed -i 's/admin:.*/admin::0:0:99999:7:::/g' "${FILES_PATH}"

# 添加自定义插件源
# Passwall
sed -i '1i\src-git passwall_luci https://github.com/Openwrt-Passwall/openwrt-passwall.git;main' "${HOME_PATH}/feeds.conf.default"
sed -i '1i\src-git passwall_packages https://github.com/Openwrt-Passwall/openwrt-passwall-packages.git;main' "${HOME_PATH}/feeds.conf.default"

THEME_BRANCH="Theme2"

[[ "${OpenClash_branch}" == "1" ]] && echo "src-git OpenClash https://github.com/vernesong/OpenClash.git;master" >> "${HOME_PATH}/feeds.conf.default"
[[ "${OpenClash_branch}" == "2" ]] && echo "src-git OpenClash https://github.com/vernesong/OpenClash.git;dev" >> "${HOME_PATH}/feeds.conf.default"

# 读取default-settings/files/99-default-settings到ZZZ_PATH并清理登录banner
variable ZZZ_PATH="$(find "$HOME_PATH/package" -name "*-default-settings" -not -path "A/exclude_dir/*" -print)"
[[ -n "${ZZZ_PATH}" ]] && grep -q "openwrt_banner" "${ZZZ_PATH}" && sed -i '/openwrt_banner/d' "${ZZZ_PATH}"

# 更新feeds
cd ${HOME_PATH}
./scripts/feeds clean
if [[ "${BENDI_VERSION}" == "2" ]]; then
  ./scripts/feeds update -a &>/dev/null
else
  ./scripts/feeds update -a
fi

# 更新feeds后再次修改补充
cd ${HOME_PATH}
PACKAGES_TO_REMOVE=(

)

EXCLUDE_DIRS=(
#    "${HOME_PATH}/feeds/danshui"
)

for package in "${PACKAGES_TO_REMOVE[@]}"; do
    find "${HOME_PATH}/feeds" "${HOME_PATH}/package" \
        -path "${EXCLUDE_DIRS[0]}" -prune -o \
        -path "${EXCLUDE_DIRS[1]}" -prune -o \
        -path "${EXCLUDE_DIRS[2]}" -prune -o \
        -name "$package" -type d -exec rm -rf {} +
done

# 更新golang
gitsvn https://github.com/sbwml/packages_lang_golang/tree/25.x ${HOME_PATH}/feeds/packages/lang/golang

# files大法，设置固件无烦恼
if [ -d "${BUILD_PATCHES}" ]; then
  find "${BUILD_PATCHES}" -type f -name '*.patch' -print0 | sort -z | xargs -I % -t -0 -n 1 sh -c "cat '%'  | patch -d './' -p1 --forward --no-backup-if-mismatch"
fi
if [ -d "${BUILD_DIY}" ]; then
  cp -Rf ${BUILD_DIY}/* ${HOME_PATH}
fi
if [ -d "${BUILD_FILES}" ]; then
  cp -Rf ${BUILD_FILES} ${HOME_PATH}
fi

# 定时更新固件的插件包
if grep -q "armvirt=y" $MYCONFIG_FILE || grep -q "armsr=y" $MYCONFIG_FILE; then
  find "${HOME_PATH}" -type d -name "luci-app-autoupdate" |xargs -i rm -rf {}
  if grep -q "luci-app-autoupdate" "${HOME_PATH}/include/target.mk"; then
    sed -i 's?luci-app-autoupdate ??g' ${HOME_PATH}/include/target.mk
  fi
elif [[ "${UPDATE_FIRMWARE_ONLINE}" == "true" ]]; then
    source ${UPGRADE_SH} && Diy_Part1
else
  find "${HOME_PATH}" -type d -name "luci-app-autoupdate" |xargs -i rm -rf {}
  if grep -q "luci-app-autoupdate" "${HOME_PATH}/include/target.mk"; then
    sed -i 's?luci-app-autoupdate ??g' ${HOME_PATH}/include/target.mk
  fi
fi


# 给固件保留配置更新固件的保留项目
cat >> "${KEEPD_PATH}" <<-EOF
/etc/config/AdGuardHome.yaml
/www/luci-static/argon/background
/etc/smartdns/custom.conf
EOF
}


function Diy_IMMORTALWRT() {
cd ${HOME_PATH}
}

function Diy_OFFICIAL() {
cd ${HOME_PATH}
}


function Diy_partsh() {
TIME y "正在执行：自定义文件"
cd ${HOME_PATH}
# 运行自定义文件，然后更新feeds
${DIY_PT1_SH}
./scripts/feeds update -a &>/dev/null
}


function Diy_scripts() {
TIME y "正在执行：更新和安装feeds"
# 运行自定义后,检测主题是否可用
cd ${HOME_PATH}
# 主题设置
if [[ ! "${Mandatory_theme}" == "0" ]] && [[ -n "${Mandatory_theme}" ]]; then
  sed -i "/${Mandatory_theme}/d" $MYCONFIG_FILE
  echo "CONFIG_PACKAGE_luci-theme-$Mandatory_theme=y" >>$MYCONFIG_FILE
  SEARCH_DIRS=("${HOME_PATH}/package" "${HOME_PATH}/feeds")
  TARGET_DIR="luci-theme-${Mandatory_theme}"
  if find "${SEARCH_DIRS[@]}" -type d -name "$TARGET_DIR" -print -quit | grep -q .; then
    [[ -f "${HOME_PATH}/feeds/luci/collections/luci/Makefile" ]] && sed -i -E "s/(\+luci-theme-)[^ \\]*/\1${Mandatory_theme}/g" "${HOME_PATH}/feeds/luci/collections/luci/Makefile"
    [[ -f "${HOME_PATH}/feeds/luci/collections/luci-light/Makefile" ]] && sed -i -E "s/(\+luci-theme-)[^ \\]*/\1${Mandatory_theme}/g" "${HOME_PATH}/feeds/luci/collections/luci-light/Makefile"
  fi
fi
if [[ ! "${Default_theme}" == "0" ]] && [[ -n "${Default_theme}" ]]; then
  sed -i "/${Default_theme}/d" $MYCONFIG_FILE
  echo "CONFIG_PACKAGE_luci-theme-$Default_theme=y" >>$MYCONFIG_FILE
fi

# 更新和安装feeds
./scripts/feeds install -a

# 使用自定义配置文件
[[ -f "$MYCONFIG_FILE" ]] && cp -Rf $MYCONFIG_FILE .config
}


function Diy_profile() {
TIME y "正在执行：识别源码编译为何机型"
cd ${HOME_PATH}
make defconfig > /dev/null 2>&1
variable TARGET_BOARD="$(awk -F '[="]+' '/TARGET_BOARD/{print $2}' ${HOME_PATH}/.config)"
variable TARGET_SUBTARGET="$(awk -F '[="]+' '/TARGET_SUBTARGET/{print $2}' ${HOME_PATH}/.config)"
variable TARGET_PROFILE_DG="$(awk -F '[="]+' '/TARGET_PROFILE/{print $2}' ${HOME_PATH}/.config)"
if [[ -n "$(grep -Eo 'CONFIG_TARGET.*x86.*64.*=y' ${HOME_PATH}/.config)" ]]; then
  variable TARGET_PROFILE="x86-64"
elif [[ -n "$(grep -Eo 'CONFIG_TARGET.*x86.*=y' ${HOME_PATH}/.config)" ]]; then
  variable TARGET_PROFILE="x86-32"
elif [[ -n "$(grep -Eo 'CONFIG_TARGET.*DEVICE.*phicomm.*n1=y' ${HOME_PATH}/.config)" ]]; then
  variable TARGET_PROFILE="phicomm_n1"
elif grep -Eq "TARGET_armvirt=y|TARGET_armsr=y" "$HOME_PATH/.config"; then
  variable TARGET_PROFILE="armsr_rootfs_tar_gz"
elif [[ -n "$(grep -Eo 'CONFIG_TARGET.*DEVICE.*=y' ${HOME_PATH}/.config)" ]]; then
  variable TARGET_PROFILE="$(grep -Eo "CONFIG_TARGET.*DEVICE.*=y" ${HOME_PATH}/.config | sed -r 's/.*DEVICE_(.*)=y/\1/')"
else
  variable TARGET_PROFILE="${TARGET_PROFILE_DG}"
fi
variable FIRMWARE_PATH=${HOME_PATH}/bin/targets/${TARGET_BOARD}/${TARGET_SUBTARGET}
variable TARGET_OPENWRT=openwrt/bin/targets/${TARGET_BOARD}/${TARGET_SUBTARGET}
echo -e "正在编译：${TARGET_PROFILE}\n"
}


function Diy_management() {
cd ${HOME_PATH}
# 机型为armsr_rootfs_tar_gz的时,修改cpufreq代码适配Armvirt
if [[ "${TARGET_BOARD}" =~ (armvirt|armsr) ]]; then
  for X in $(find "${HOME_PATH}" -type d -name "luci-app-cpufreq"); do \
    [[ -d "$X" ]] && \
    sed -i 's/LUCI_DEPENDS.*/LUCI_DEPENDS:=\@\(arm\|\|aarch64\)/g' "$X/Makefile"; \
  done
fi

# files文件夹删除LICENSE,README
[[ -d "${HOME_PATH}/files" ]] && sudo chmod +x ${HOME_PATH}/files
rm -rf ${HOME_PATH}/files/{LICENSE,README}
}

function Diy_definition() {
cd ${HOME_PATH}
source "${DIY_PT2_SH}"
# 获取源码文件的IP
lan="/set network.\$1.netmask/a"
ipadd="$(grep "ipaddr:-" "${GENE_PATH}" |grep -v 'addr_offset' |grep -Eo "[0-9]+\.[0-9]+\.[0-9]+\.[0-9]+")"
netmas="$(grep "netmask:-" "${GENE_PATH}" |grep -Eo "[0-9]+\.[0-9]+\.[0-9]+\.[0-9]+")"
opname="$(grep "hostname=" "${GENE_PATH}" |grep -v '\$hostname' |cut -d "'" -f2)"
if [[ -n "$(grep "set network.\${1}6.device" "${GENE_PATH}")" ]]; then
  ifnamee="uci set network.ipv6.device='@lan'"
  set_add="uci add_list firewall.@zone[0].network='ipv6'"
else
  ifnamee="uci set network.ipv6.ifname='@lan'"
  set_add="uci set firewall.@zone[0].network='lan ipv6'"
fi

if [[ "${SOURCE_CODE}" == "OFFICIAL" ]] && [[ "${REPO_BRANCH}" == "openwrt-19.07" ]]; then
  devicee="uci set network.ipv6.device='@lan'"
fi

if [[ "${Ipv4_ipaddr}" == "0" ]] || [[ -z "${Ipv4_ipaddr}" ]]; then
  echo "不进行,修改后台IP"
elif [[ -n "${Ipv4_ipaddr}" ]]; then
  Kernel_Pat="$(echo ${Ipv4_ipaddr} |grep -Eo "[0-9]+\.[0-9]+\.[0-9]+\.[0-9]+")"
  ipadd_Pat="$(echo ${ipadd} |grep -Eo "[0-9]+\.[0-9]+\.[0-9]+\.[0-9]+")"
  if [[ -n "${Kernel_Pat}" ]] && [[ -n "${ipadd_Pat}" ]]; then
     sed -i "s/${ipadd}/${Ipv4_ipaddr}/g" "${GENE_PATH}"
     echo "openwrt后台IP[${Ipv4_ipaddr}]修改完成"
   else
     TIME r "因IP获取有错误，后台IP更换不成功，请检查IP是否填写正确，如果填写正确，那就是获取不了源码内的IP了"
   fi
fi

if [[ "${Netmask_netm}" == "0" ]] || [[ -z "${Netmask_netm}" ]]; then
  echo "不进行,子网掩码修改"
elif [[ -n "${Netmask_netm}" ]]; then
  Kernel_netm="$(echo ${Netmask_netm} |grep -Eo "[0-9]+\.[0-9]+\.[0-9]+\.[0-9]+")"
  ipadd_mas="$(echo ${netmas} |grep -Eo "[0-9]+\.[0-9]+\.[0-9]+\.[0-9]+")"
  if [[ -n "${Kernel_netm}" ]] && [[ -n "${ipadd_mas}" ]]; then
     sed -i "s/${netmas}/${Netmask_netm}/g" "${GENE_PATH}"
     echo "子网掩码[${Netmask_netm}]修改完成"
   else
     TIME r "因子网掩码获取有错误，子网掩码设置失败，请检查IP是否填写正确，如果填写正确，那就是获取不了源码内的IP了"
  fi
fi

if [[ ! "${Default_theme}" == "0" ]] && [[ -n "${Default_theme}" ]]; then
  if [[ `grep -c "${Default_theme}=y" ${HOME_PATH}/.config` -eq '0' ]]; then
    TIME r "没有${Default_theme}此主题存在，默认主题设置失败"
  else
    echo "uci set luci.main.mediaurlbase='/luci-static/${Default_theme}'" >> "${DEFAULT_PATH}"
    echo "uci commit luci" >> "${DEFAULT_PATH}"
    echo "默认主题[${Default_theme}]设置完成"
  fi
else
  echo "不进行,默认主题设置"
fi

if [[ ! "${Mandatory_theme}" == "0" ]] && [[ -n "${Mandatory_theme}" ]]; then
  if [[ `grep -c "${Mandatory_theme}=y" ${HOME_PATH}/.config` -eq '1' ]]; then
    [[ -f "$HOME_PATH/feeds/luci/collections/luci/Makefile" ]] && sed -i -E "s/(\+luci-theme-)[^ \\]*/\1${Mandatory_theme}/g" "$HOME_PATH/feeds/luci/collections/luci/Makefile"
    [[ -f "$HOME_PATH/feeds/luci/collections/luci-light/Makefile" ]] && sed -i -E "s/(\+luci-theme-)[^ \\]*/\1${Mandatory_theme}/g" "$HOME_PATH/feeds/luci/collections/luci-light/Makefile"
    echo "替换系统默认主题完成,您现在的系统默认主题为：luci-theme-${Mandatory_theme}"
  else
    [[ -f "$HOME_PATH/feeds/luci/collections/luci/Makefile" ]] && sed -i -E "s/(\+luci-theme-)[^ \\]*/\1bootstrap/g" "$HOME_PATH/feeds/luci/collections/luci/Makefile"
    [[ -f "$HOME_PATH/feeds/luci/collections/luci-light/Makefile" ]] && sed -i -E "s/(\+luci-theme-)[^ \\]*/\1bootstrap/g" "$HOME_PATH/feeds/luci/collections/luci-light/Makefile"
    echo "CONFIG_PACKAGE_luci-theme-bootstrap=y" >>.config
    TIME r "没有${Mandatory_theme}此主题存在，替换失败，继续使用原默认主题"
  fi
else
  echo "不进行,系统默认主题替换"
fi

if [[ -n "${Kernel_partition_size}" ]] && [[ "${Kernel_partition_size}" != "0" ]]; then
  Kernel_partition_size=$(echo "${Kernel_partition_size}" | tr -d '[:space:]' | grep -o -E '[0-9]+')
  echo "CONFIG_TARGET_KERNEL_PARTSIZE=${Kernel_partition_size}" >> ${HOME_PATH}/.config
  echo "内核分区设置完成，大小为：${Kernel_partition_size}MB"
else
  echo "不进行,内核分区大小设置"
fi

if [[ -n "${Rootfs_partition_size}" ]] && [[ "${Rootfs_partition_size}" != "0" ]]; then
  Rootfs_partition_size=$(echo "${Rootfs_partition_size}" | tr -d '[:space:]' | grep -o -E '[0-9]+')
  echo "CONFIG_TARGET_ROOTFS_PARTSIZE=${Rootfs_partition_size}" >> ${HOME_PATH}/.config
  echo "系统分区设置完成，大小为：${Rootfs_partition_size}MB"
else
  echo "不进行,系统分区大小设置"
fi

if [[ "${Op_name}" == "0" ]] || [[ -z "${Op_name}" ]]; then
  echo "不进行,修改主机名称"
elif [[ -n "${Op_name}" ]] && [[ -n "${opname}" ]]; then
  sed -i "s/${opname}/${Op_name}/g" "${GENE_PATH}"
  echo "主机名[${Op_name}]修改完成"
fi

if [[ "${Gateway_Settings}" == "0" ]] || [[ -z "${Gateway_Settings}" ]]; then
  echo "不进行,网关设置"
elif [[ -n "${Gateway_Settings}" ]]; then
  Router_gat="$(echo ${Gateway_Settings} |grep -Eo "[0-9]+\.[0-9]+\.[0-9]+\.[0-9]+")"
  if [[ -n "${Router_gat}" ]]; then
    sed -i "$lan\set network.lan.gateway='${Gateway_Settings}'" "${GENE_PATH}"
    echo "网关[${Gateway_Settings}]修改完成"
  else
    TIME r "因子网关IP获取有错误，网关IP设置失败，请检查IP是否填写正确，如果填写正确，那就是获取不了源码内的IP了"
  fi
fi

if [[ "${DNS_Settings}" == "0" ]] || [[ -z "${DNS_Settings}" ]]; then
  echo "不进行,DNS设置"
elif [[ -n "${DNS_Settings}" ]]; then
  ipa_dns="$(echo ${DNS_Settings} |grep -Eo "[0-9]+\.[0-9]+\.[0-9]+\.[0-9]+")"
  if [[ -n "${ipa_dns}" ]]; then
     sed -i "$lan\set network.lan.dns='${DNS_Settings}'" "${GENE_PATH}"
     echo "DNS[${DNS_Settings}]设置完成"
  else
    TIME r "因DNS获取有错误，DNS设置失败，请检查DNS是否填写正确"
  fi
fi

if [[ "${Broadcast_Ipv4}" == "0" ]] || [[ -z "${Broadcast_Ipv4}" ]]; then
  echo "不进行,广播IP设置"
elif [[ -n "${Broadcast_Ipv4}" ]]; then
  IPv4_Bro="$(echo ${Broadcast_Ipv4} |grep -Eo "[0-9]+\.[0-9]+\.[0-9]+\.[0-9]+")"
  if [[ -n "${IPv4_Bro}" ]]; then
    sed -i "$lan\set network.lan.broadcast='${Broadcast_Ipv4}'" "${GENE_PATH}"
    echo "广播IP[${Broadcast_Ipv4}]设置完成"
  else
    TIME r "因IPv4 广播IP获取有错误，IPv4广播IP设置失败，请检查IPv4广播IP是否填写正确"
  fi
fi

if [[ "${Disable_DHCP}" == "1" ]]; then
   sed -i "$lan\set dhcp.lan.ignore='1'" "${GENE_PATH}"
   echo "关闭DHCP设置完成"
else
   echo "不进行,关闭DHCP设置"
fi

if [[ "${Disable_Bridge}" == "1" ]]; then
   sed -i "$lan\delete network.lan.type" "${GENE_PATH}"
   echo "去掉桥接设置完成"
else
   echo "不进行,去掉桥接设"
fi

if [[ "${Ttyd_account_free_login}" == "1" ]]; then
   sed -i "$lan\set ttyd.@ttyd[0].command='/bin/login -f root'" "${GENE_PATH}"
   echo "TTYD免账户登录完成"
else
   echo "不进行,TTYD免账户登录"
fi

if [[ "${Password_free_login}" == "1" ]]; then
   sed -i '/CYXluq4wUazHjmCDBCqXF/d' "${ZZZ_PATH}"
   echo "固件免密登录设置完成"
else
   echo "不进行,固件免密登录设置"
fi

if [[ "${Disable_53_redirection}" == "1" ]]; then
   sed -i '/to-ports 53/d' "${ZZZ_PATH}"
   echo "删除DNS重定向53端口完成"
else
   echo "不进行,删除DNS重定向53端"
fi

if [[ "${Cancel_running}" == "1" ]]; then
   echo "sed -i '/coremark/d' /etc/crontabs/root" >> "${DEFAULT_PATH}"
   echo "删除每天跑分任务完成"
else
   echo "不进行,删除每天跑分任务"
fi

if [[ "${OpenClash_branch}" =~ (1|2) ]]; then
  CLASH_BRANCH=$(grep -Po '^src-git(?:-full)?\s+OpenClash\s+[^;\s]+;\K[^\s]+' "${HOME_PATH}/feeds.conf.default" || echo "")
  echo -e "\nCONFIG_PACKAGE_luci-app-openclash=y" >> ${HOME_PATH}/.config
  echo "增加luci-app-openclash(${CLASH_BRANCH})完成"
else
  echo -e "\n# CONFIG_PACKAGE_luci-app-openclash is not set" >> ${HOME_PATH}/.config
  echo "去除luci-app-openclash完成"
fi


if [[ "${Disable_autosamba}" == "1" ]]; then
sed -i '/samba/d;/SAMBA/d' "${HOME_PATH}/.config"
echo '
# CONFIG_PACKAGE_autosamba is not set
# CONFIG_PACKAGE_luci-app-samba is not set
# CONFIG_PACKAGE_luci-app-samba4 is not set
# CONFIG_PACKAGE_samba36-server is not set
# CONFIG_PACKAGE_samba4-libs is not set
# CONFIG_PACKAGE_samba4-server is not set
' >> ${HOME_PATH}/.config
   echo "去掉samba完成"
else
   echo "不进行,去掉samba"
fi

if [[ "${Automatic_Mount_Settings}" == "1" ]]; then
echo '
CONFIG_PACKAGE_block-mount=y
CONFIG_PACKAGE_fdisk=y
CONFIG_PACKAGE_usbutils=y
CONFIG_PACKAGE_badblocks=y
CONFIG_PACKAGE_ntfs-3g=y
CONFIG_PACKAGE_kmod-scsi-core=y
CONFIG_PACKAGE_kmod-usb-core=y
CONFIG_PACKAGE_kmod-usb-ohci=y
CONFIG_PACKAGE_kmod-usb-uhci=y
CONFIG_PACKAGE_kmod-usb-storage=y
CONFIG_PACKAGE_kmod-usb-storage-extras=y
CONFIG_PACKAGE_kmod-usb2=y
CONFIG_PACKAGE_kmod-usb3=y
CONFIG_PACKAGE_kmod-fs-ext4=y
CONFIG_PACKAGE_kmod-fs-vfat=y
CONFIG_PACKAGE_kmod-fuse=y
# CONFIG_PACKAGE_kmod-fs-ntfs is not set
' >> ${HOME_PATH}/.config
[[ ! -d "${HOME_PATH}/files/etc/hotplug.d/block" ]] && mkdir -p "${HOME_PATH}/files/etc/hotplug.d/block"
cp -Rf "$LINSHI_COMMON/Share/block/10-mount" "${HOME_PATH}/files/etc/hotplug.d/block/10-mount"
fi

if [[ "${Enable_IPV6_function}" == "1" ]]; then
  echo "编译IPV6固件"
  echo "
    uci set network.lan.ip6assign='64'
    uci commit network
    uci set dhcp.lan.ra='server'
    uci set dhcp.lan.dhcpv6='server'
    uci set dhcp.lan.ra_management='1'
    uci set dhcp.lan.ra_default='1'
    uci set dhcp.@dnsmasq[0].localservice=0
    uci set dhcp.@dnsmasq[0].nonwildcard=0
    uci set dhcp.@dnsmasq[0].filter_aaaa='0'
    uci commit dhcp
  " >> "${DEFAULT_PATH}"
elif [[ "${Create_Ipv6_Lan}" == "1" ]]; then
  echo "爱快+OP双系统时,爱快接管IPV6,在OP创建IPV6的lan口接收IPV6信息"
  echo "
    uci delete network.lan.ip6assign
    uci set network.lan.delegate='0'
    uci commit network
    uci delete dhcp.lan.ra
    uci delete dhcp.lan.ra_management
    uci delete dhcp.lan.ra_default
    uci delete dhcp.lan.dhcpv6
    uci delete dhcp.lan.ndp
    uci set dhcp.@dnsmasq[0].filter_aaaa='0'
    uci commit dhcp
    uci set network.ipv6=interface
    uci set network.ipv6.proto='dhcpv6'
    ${devicee}
    ${ifnamee}
    uci set network.ipv6.reqaddress='try'
    uci set network.ipv6.reqprefix='auto'
    uci commit network
    ${set_add}
    uci commit firewall
  " >> "${DEFAULT_PATH}"
elif [[ "${Enable_IPV4_function}" == "1" ]]; then
  echo "编译IPV4固件"
  echo "
    uci delete network.globals.ula_prefix
    uci delete network.lan.ip6assign
    uci delete network.wan6
    uci set network.lan.delegate='0' 
    uci commit network
    uci delete dhcp.lan.ra
    uci delete dhcp.lan.ra_management
    uci delete dhcp.lan.ra_default
    uci delete dhcp.lan.dhcpv6
    uci delete dhcp.lan.ndp
    uci set dhcp.@dnsmasq[0].filter_aaaa='1'
    uci commit dhcp
  " >> "${DEFAULT_PATH}"
fi

if [[ "${Enable_IPV6_function}" == "1" ]]; then
echo '
CONFIG_PACKAGE_ipv6helper=y
CONFIG_PACKAGE_ip6tables=y
CONFIG_PACKAGE_dnsmasq_full_dhcpv6=y
CONFIG_PACKAGE_odhcp6c=y
CONFIG_PACKAGE_odhcpd-ipv6only=y
CONFIG_IPV6=y
CONFIG_PACKAGE_6rd=y
CONFIG_PACKAGE_6to4=y
' >> ${HOME_PATH}/.config
fi

if [[ "${Create_Ipv6_Lan}" == "1" ]]; then
echo '
CONFIG_PACKAGE_ipv6helper=y
CONFIG_PACKAGE_ip6tables=y
CONFIG_PACKAGE_dnsmasq_full_dhcpv6=y
CONFIG_PACKAGE_odhcp6c=y
CONFIG_PACKAGE_odhcpd-ipv6only=y
CONFIG_IPV6=y
CONFIG_PACKAGE_6rd=y
CONFIG_PACKAGE_6to4=y
' >> ${HOME_PATH}/.config
fi

if [[ "${Enable_IPV4_function}" == "1" ]] && \
[[ "${REPO_BRANCH}" =~ ^(main|master|2410|(openwrt-)?(19\.07|23\.05|24\.10))$ ]]; then
echo '
# CONFIG_PACKAGE_ipv6helper is not set
# CONFIG_PACKAGE_ip6tables is not set
# CONFIG_PACKAGE_dnsmasq_full_dhcpv6 is not set
# CONFIG_PACKAGE_odhcp6c is not set
# CONFIG_PACKAGE_odhcpd-ipv6only is not set
# CONFIG_IPV6 is not set
# CONFIG_PACKAGE_6rd is not set
# CONFIG_PACKAGE_6to4 is not set
' >> ${HOME_PATH}/.config
else
echo '
CONFIG_IPV6=y
CONFIG_PACKAGE_odhcp6c=y
CONFIG_PACKAGE_odhcpd-ipv6only=y
' >> ${HOME_PATH}/.config
fi


if [[ "${Delete_unnecessary_items}" == "1" ]]; then
  echo "删除其他机型的固件,只保留当前主机型固件完成"
  sed -i "s|^TARGET_|# TARGET_|g; s|# TARGET_DEVICES += ${TARGET_PROFILE}|TARGET_DEVICES += ${TARGET_PROFILE}|" ${HOME_PATH}/target/linux/${TARGET_BOARD}/image/Makefile
fi

variable patchverl="$(grep "KERNEL_PATCHVER" "${HOME_PATH}/target/linux/${TARGET_BOARD}/Makefile" |grep -Eo "[0-9]+\.[0-9]+")"
if [[ "${TARGET_BOARD}" == "armvirt" ]]; then
  variable KERNEL_patc="config-${Replace_Kernel}"
else
  variable KERNEL_patc="patches-${Replace_Kernel}"
fi
if [[ "${Replace_Kernel}" == "0" ]]; then
  echo "不进行,内核更换"
elif [[ -n "${Replace_Kernel}" ]] && [[ -n "${patchverl}" ]]; then
  if [[ `ls -1 "${HOME_PATH}/target/linux/${TARGET_BOARD}" |grep -c "${KERNEL_patc}"` -eq '1' ]]; then
    sed -i "s/${patchverl}/${Replace_Kernel}/g" ${HOME_PATH}/target/linux/${TARGET_BOARD}/Makefile
    echo "内核[${Replace_Kernel}]更换完成"
  else
    TIME r "${TARGET_PROFILE}机型源码没发现[ ${Replace_Kernel} ]内核存在，替换内核操作失败，保持默认内核[${patchverl}]继续编译"
  fi
fi

# 晶晨CPU机型自定义机型,内核,分区
[[ -n "${amlogic_model}" ]] && echo "amlogic_model=${amlogic_model}" >> ${GITHUB_ENV}
[[ -n "${amlogic_kernel}" ]] && echo "amlogic_kernel=${amlogic_kernel}" >> ${GITHUB_ENV}
[[ -n "${auto_kernel}" ]] && echo "auto_kernel=${auto_kernel}" >> ${GITHUB_ENV}
[[ -n "${rootfs_size}" ]] && echo "openwrt_size=${rootfs_size}" >> ${GITHUB_ENV}
[[ -n "${amlogic_model}" ]] && echo "kernel_repo=ophub/kernel" >> ${GITHUB_ENV}
[[ -n "${kernel_usage}" ]] && echo "kernel_usage=${kernel_usage}" >> ${GITHUB_ENV}
[[ -n "${amlogic_model}" ]] && echo "builder_name=ophub" >> ${GITHUB_ENV}

# 源码内核版本号
KERNEL_PATCH="$(awk -F'[:=]' '/KERNEL_PATCHVER/{print $NF; exit}' "${HOME_PATH}/target/linux/${TARGET_BOARD}/Makefile")"
KERNEL_VERSINO="kernel-${KERNEL_PATCH}"
if [[ -f "${HOME_PATH}/include/${KERNEL_VERSINO}" ]]; then
  variable LINUX_KERNEL="$(grep -oP "LINUX_KERNEL_HASH-\K${KERNEL_PATCH}\.[0-9]+" "${HOME_PATH}/include/${KERNEL_VERSINO}")"
  [[ -z ${LINUX_KERNEL} ]] && variable LINUX_KERNEL="$KERNEL_PATCH"
else
  variable LINUX_KERNEL="$(grep -oP "LINUX_KERNEL_HASH-\K${KERNEL_PATCH}\.[0-9]+" "${HOME_PATH}/include/kernel-version.mk")"
  [[ -z ${LINUX_KERNEL} ]] && variable LINUX_KERNEL="$KERNEL_PATCH"
fi
}


function Diy_prevent() {
TIME y "正在执行：检查并生成seed"
cd ${HOME_PATH}
make defconfig > /dev/null 2>&1

if [[ `grep -c "CONFIG_TARGET_ROOTFS_EXT4FS=y" ${HOME_PATH}/.config` -eq '1' ]]; then
  PARTSIZE=$(awk -F= '/^CONFIG_TARGET_ROOTFS_PARTSIZE=/{print $2}' ${HOME_PATH}/.config | tr -d '[:space:]')
  PARTSIZE=$(echo "${PARTSIZE}" | grep -o -E '[0-9]+')
  CONSIZE="950"
  if [[ "${PARTSIZE}" -lt "${CONSIZE}" ]]; then
    sed -i '/CONFIG_TARGET_ROOTFS_PARTSIZE/d' ${HOME_PATH}/.config
    echo -e "\nCONFIG_TARGET_ROOTFS_PARTSIZE=950" >> ${HOME_PATH}/.config
    TIME r "EXT4提示：分区大小${PARTSIZE}M小于推荐值950M"
    TIME r "已自动调整为950M"
  fi
fi

cd ${HOME_PATH}
make defconfig > /dev/null 2>&1
./scripts/diffconfig.sh > ${CONFIG_TXT}
}



function Diy_firmware() {
# 远程更新处理固件
if [ "${UPDATE_FIRMWARE_ONLINE}" == "true" ]; then
  cd ${HOME_PATH}
  source $UPGRADE_SH && Diy_Part3
fi
# 编译完毕后,整理固件
cd ${FIRMWARE_PATH}
# 打包所有ipk或者apk插件
if find "${HOME_PATH}/bin/packages/" -type f -name "*.ipk" | grep -q .; then
    mkdir -p ipk
    find "${HOME_PATH}/bin/packages/" -type f -name "*.ipk" -exec mv {} ipk/ \;
elif find "${HOME_PATH}/bin/packages/" -type f -name "*.apk" | grep -q .; then
    mkdir -p apk
    find "${HOME_PATH}/bin/packages/" -type f -name "*.apk" -exec mv {} apk/ \;
fi
if [ -d "ipk" ]; then
    sync
    tar -czf ipk.tar.gz ipk
    sync
    rm -rf ipk
elif [ -d "apk" ]; then
    sync
    tar -czf apk.tar.gz apk
    sync
    rm -rf apk
fi

if [[ -n "$(ls -1 |grep -E 'immortalwrt')" ]]; then
  rename "s/^immortalwrt/openwrt/" *
  sed -i 's/immortalwrt/openwrt/g' `egrep "immortalwrt" -rl ./`
fi
TIME g "整理前的全部文件"
ls -1
for X in $(cat ${CLEAR_PATH} |sed "s/.*${TARGET_BOARD}//g"); do
  rm -rf *"$X"*
done
TIME g "整理后的文件"
ls -1
if ! echo "$TARGET_BOARD" | grep -Eq 'armvirt|armsr'; then
  rename "s/^openwrt/${GUJIAN_DATE}-${SOURCE}-${LUCI_EDITION}-${LINUX_KERNEL}/" *
  TIME g "更改名称后的固件，也是最终上传使用的"
  ls -1
fi

echo "DATE=$(date "+%Y%m%d%H%M%S")" >> ${GITHUB_ENV}
echo "TONGZHI_DATE=$(date +%Y年%m月%d日)" >> ${GITHUB_ENV}
echo "FIRMWARE_DATE=$(date +%Y-%m%d-%H%M)" >> ${GITHUB_ENV}
}


gitsvn() {
    local url="${1%.git}"
    local route="$2"
    local home_dir="${HOME_PATH}"
    
    # 1. 变量初始化
    local tmpdir; tmpdir=$(mktemp -d)
    local base_url repo_name branch path_after_branch files_name store_away mode
    
    # 确保无论脚本如何退出，都会删除临时文件夹
    trap 'rm -rf "$tmpdir"' RETURN EXIT

    # 2. 解析 GitHub 链接 (使用 Bash 内置正则和修剪，减少 fork)
    if [[ "$url" =~ github\.com/([^/]+)/([^/]+)/tree/([^/]+)/(.*) ]]; then
        mode="tree"
        repo_name="${BASH_REMATCH[2]}"
        branch="${BASH_REMATCH[3]}"
        path_after_branch="${BASH_REMATCH[4]}"
        base_url="https://github.com/${BASH_REMATCH[1]}/${repo_name}"
        files_name="${path_after_branch##*/}"
    elif [[ "$url" =~ github\.com/([^/]+)/([^/]+)/blob/([^/]+)/(.*) ]]; then
        mode="blob"
        branch="${BASH_REMATCH[3]}"
        path_after_branch="${BASH_REMATCH[4]}"
        files_name="${path_after_branch##*/}"
        local download_url="https://raw.githubusercontent.com/${BASH_REMATCH[1]}/${BASH_REMATCH[2]}/$branch/$path_after_branch"
    elif [[ "$url" =~ github\.com/([^/]+)/([^/]+) ]]; then
        mode="repo"
        repo_name="${BASH_REMATCH[2]}"
        base_url="https://github.com/${BASH_REMATCH[1]}/${repo_name}"
        files_name="$repo_name"
    else
        echo "Error: 无效的 GitHub 链接"
        return 1
    fi

    # 3. 确定存储路径 (store_away)
    case "$route" in
        "all")      store_away="$home_dir" ;;
        openwrt/*)  store_away="$home_dir/${route#openwrt/}" ;;
        ./*)        store_away="$home_dir/${route#./}" ;;
        "")         store_away="$home_dir/$files_name" ;;
        *)          store_away="$route" ;;
    esac

    # 4. 执行下载逻辑
    echo "Processing: $files_name -> $store_away"

    if [[ "$mode" == "blob" ]]; then
        mkdir -p "$(dirname "$store_away")"
        curl -fsSL "$download_url" -o "$store_away" || { echo "Download failed"; return 1; }
    else
        # 处理 tree 或整个仓库
        git clone -q --depth=1 --filter=blob:none --sparse ${branch:+-b $branch} "$base_url" "$tmpdir" || return 1
        cd "$tmpdir" || return 1
        
        if [[ -n "$path_after_branch" ]]; then
            git sparse-checkout set "$path_after_branch" || return 1
        fi

        # OpenWrt 特殊处理：替换 Makefile 引用
        find . -maxdepth 4 -name "Makefile" -exec sed -i \
            -e 's#include ../../luci.mk#include $(TOPDIR)/feeds/luci/luci.mk#g' \
            -e 's#include ../../lang/#include $(TOPDIR)/feeds/packages/lang/#g' {} +

        # 移动文件
        local src_path="$tmpdir${path_after_branch:+/$path_after_branch}"
        if [[ "$route" == "all" ]]; then
            # 'all' 模式：合并到目标目录，冲突则覆盖
            cp -rf "$src_path"/* "$store_away/" 2>/dev/null
        else
            # 普通模式：替换目标目录
            rm -rf "$store_away"
            mkdir -p "$(dirname "$store_away")"
            cp -rf "$src_path" "$store_away"
        fi
    fi

    echo "Done: $files_name 已就绪"
}



function Diy_menu() {
cd $HOME_PATH
Diy_checkout
Diy_${SOURCE_CODE}
}

function Diy_menu2() {
cd $HOME_PATH
Diy_partsh
}

function Diy_menu3() {
cd $HOME_PATH
Diy_scripts
}

function Diy_menu4() {
cd $HOME_PATH
Diy_profile
}

function Diy_menu5() {
cd $HOME_PATH
Diy_management
Diy_definition
Diy_prevent
}

function Diy_menu6() {
Diy_variable
}

if [[ "${BENDI_VERSION}" == "2" ]]; then
  case "${1}" in
    "Diy_menu") Diy_menu ;;
    "Diy_menu2") Diy_menu2 ;;
    "Diy_menu3") Diy_menu3 ;;
    "Diy_menu4") Diy_menu4 ;;
    "Diy_menu5") Diy_menu5 ;;
    "Diy_menu6") Diy_menu6 ;;
    "Diy_firmware") Diy_firmware ;;
    "Diy_feedsconf") Diy_feedsconf ;;
    *) 
      echo "不支持${1}" ;;
  esac
fi
