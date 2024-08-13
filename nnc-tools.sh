#!/usr/bin/env bash

# Color definitions for output
Green_font_prefix="\033[32m"
Red_font_prefix="\033[31m"
Font_color_suffix="\033[0m"
Info="${Green_font_prefix}[信息]${Font_color_suffix}"
Error="${Red_font_prefix}[错误]${Font_color_suffix}"
Tip="${Green_font_prefix}[注意]${Font_color_suffix}"

# Function to display copyright and script information
copyright() {
    clear
    echo "\
############################################################

Linux 网络优化脚本
Powered by NNC.SH

############################################################
"
}

# Function to optimize TCP settings
tcp_tune() {
    local conf_file="/etc/sysctl.conf"
    local keys=(
        "net.ipv4.tcp_no_metrics_save"
        "net.ipv4.tcp_ecn"
        "net.ipv4.tcp_frto"
        "net.ipv4.tcp_mtu_probing"
        "net.ipv4.tcp_rfc1337"
        "net.ipv4.tcp_sack"
        "net.ipv4.tcp_fack"
        "net.ipv4.tcp_window_scaling"
        "net.ipv4.tcp_adv_win_scale"
        "net.ipv4.tcp_moderate_rcvbuf"
        "net.ipv4.tcp_rmem"
        "net.ipv4.tcp_wmem"
        "net.core.rmem_max"
        "net.core.wmem_max"
        "net.ipv4.udp_rmem_min"
        "net.ipv4.udp_wmem_min"
        "net.core.default_qdisc"
        "net.ipv4.tcp_congestion_control"
    )

    for key in "${keys[@]}"; do
        sed -i "/$key/d" "$conf_file"
    done

    cat >> "$conf_file" << EOF
net.ipv4.tcp_no_metrics_save=1
net.ipv4.tcp_ecn=0
net.ipv4.tcp_frto=0
net.ipv4.tcp_mtu_probing=0
net.ipv4.tcp_rfc1337=0
net.ipv4.tcp_sack=1
net.ipv4.tcp_fack=1
net.ipv4.tcp_window_scaling=1
net.ipv4.tcp_adv_win_scale=1
net.ipv4.tcp_moderate_rcvbuf=1
net.core.rmem_max=67108848 
net.core.wmem_max=67108848
net.ipv4.tcp_rmem=10240000 16777216 536870912
net.ipv4.tcp_wmem=10240000 16777216 536870912
net.ipv4.udp_rmem_min=8192
net.ipv4.udp_wmem_min=8192
net.core.default_qdisc=fq
net.ipv4.tcp_congestion_control=bbr
EOF
    sysctl -p && sysctl --system
}

# Function to enable kernel forwarding
enable_forwarding() {
    local conf_file="/etc/sysctl.conf"
    local keys=(
        "net.ipv4.conf.all.route_localnet"
        "net.ipv4.ip_forward"
        "net.ipv4.conf.all.forwarding"
        "net.ipv4.conf.default.forwarding"
        "net.ipv6.conf.all.forwarding"
        "net.ipv6.conf.default.forwarding"
    )

    for key in "${keys[@]}"; do
        sed -i "/$key/d" "$conf_file"
    done

    cat >> "$conf_file" << EOF
net.ipv4.conf.all.route_localnet=1
net.ipv4.ip_forward=1
net.ipv4.conf.all.forwarding=1
net.ipv4.conf.default.forwarding=1
net.ipv6.conf.all.forwarding=1
net.ipv6.conf.default.forwarding=1
EOF
    sysctl -p && sysctl --system
}

# Function to disable ICMP ping
banping() {
    local conf_file="/etc/sysctl.conf"
    sed -i '/net.ipv4.icmp_echo_ignore_all/d' "$conf_file"
    sed -i '/net.ipv4.icmp_echo_ignore_broadcasts/d' "$conf_file"

    cat >> "$conf_file" << EOF
net.ipv4.icmp_echo_ignore_all=1
net.ipv4.icmp_echo_ignore_broadcasts=1
EOF
    sysctl -p && sysctl --system
}

# Function to enable ICMP ping
unbanping() {
    sed -i 's/net.ipv4.icmp_echo_ignore_all=1/net.ipv4.icmp_echo_ignore_all=0/' /etc/sysctl.conf
    sed -i 's/net.ipv4.icmp_echo_ignore_broadcasts=1/net.ipv4.icmp_echo_ignore_broadcasts=0/' /etc/sysctl.conf
    sysctl -p && sysctl --system
}

# Function to optimize system limits
ulimit_tune() {
    echo "1000000" > /proc/sys/fs/file-max
    sed -i '/fs.file-max/d' /etc/sysctl.conf
    cat >> '/etc/sysctl.conf' << EOF
fs.file-max=1000000
EOF

    ulimit -SHn 1000000 && ulimit -c unlimited
    echo "root     soft   nofile    1000000
root     hard   nofile    1000000
root     soft   nproc     1000000
root     hard   nproc     1000000
root     soft   core      1000000
root     hard   core      1000000
root     hard   memlock   unlimited
root     soft   memlock   unlimited

*     soft   nofile    1000000
*     hard   nofile    1000000
*     soft   nproc     1000000
*     hard   nproc     1000000
*     soft   core      1000000
*     hard   core      1000000
*     hard   memlock   unlimited
*     soft   memlock   unlimited
">/etc/security/limits.conf

if grep -q "ulimit" /etc/profile; then
  :
else
  sed -i '/ulimit -SHn/d' /etc/profile
  echo "ulimit -SHn 1000000" >>/etc/profile
fi
if grep -q "pam_limits.so" /etc/pam.d/common-session; then
  :
else
  sed -i '/required pam_limits.so/d' /etc/pam.d/common-session
  echo "session required pam_limits.so" >>/etc/pam.d/common-session
fi

    sed -i '/DefaultTimeoutStartSec/d' /etc/systemd/system.conf
    sed -i '/DefaultTimeoutStopSec/d' /etc/systemd/system.conf
    sed -i '/DefaultRestartSec/d' /etc/systemd/system.conf
    sed -i '/DefaultLimitCORE/d' /etc/systemd/system.conf
    sed -i '/DefaultLimitNOFILE/d' /etc/systemd/system.conf
    sed -i '/DefaultLimitNPROC/d' /etc/systemd/system.conf

    cat >>'/etc/systemd/system.conf' <<EOF
[Manager]
DefaultTimeoutStopSec=30s
DefaultLimitCORE=infinity
DefaultLimitNOFILE=65535
DefaultLimitNPROC=65535
EOF

    systemctl daemon-reload
}

# Function to install BBR and optimize TCP
bbr() {
    if uname -r | grep -q "^5."; then
        echo "已经是 5.x 内核，不需要更新"
    else
        wget -N "http://sh.nekoneko.cloud/bbr/bbr.sh" -O bbr.sh && bash bbr.sh
    fi
}

Update_Shell(){
  wget -N "http://sh.nekoneko.cloud/tools.sh" -O tools.sh && chmod +x tools.sh && ./tools.sh
}

get_opsy() {
  [ -f /etc/redhat-release ] && awk '{print ($1,$3~/^[0-9]/?$3:$4)}' /etc/redhat-release && return
  [ -f /etc/os-release ] && awk -F'[= "]' '/PRETTY_NAME/{print $3,$4,$5}' /etc/os-release && return
  [ -f /etc/lsb-release ] && awk -F'[="]+' '/DESCRIPTION/{print $2}' /etc/lsb-release && return
}
virt_check() {
  # if hash ifconfig 2>/dev/null; then
  # eth=$(ifconfig)
  # fi

  virtualx=$(dmesg) 2>/dev/null

  if [[ $(which dmidecode) ]]; then
    sys_manu=$(dmidecode -s system-manufacturer) 2>/dev/null
    sys_product=$(dmidecode -s system-product-name) 2>/dev/null
    sys_ver=$(dmidecode -s system-version) 2>/dev/null
  else
    sys_manu=""
    sys_product=""
    sys_ver=""
  fi

  if grep docker /proc/1/cgroup -qa; then
    virtual="Docker"
  elif grep lxc /proc/1/cgroup -qa; then
    virtual="Lxc"
  elif grep -qa container=lxc /proc/1/environ; then
    virtual="Lxc"
  elif [[ -f /proc/user_beancounters ]]; then
    virtual="OpenVZ"
  elif [[ "$virtualx" == *kvm-clock* ]]; then
    virtual="KVM"
  elif [[ "$cname" == *KVM* ]]; then
    virtual="KVM"
  elif [[ "$cname" == *QEMU* ]]; then
    virtual="KVM"
  elif [[ "$virtualx" == *"VMware Virtual Platform"* ]]; then
    virtual="VMware"
  elif [[ "$virtualx" == *"Parallels Software International"* ]]; then
    virtual="Parallels"
  elif [[ "$virtualx" == *VirtualBox* ]]; then
    virtual="VirtualBox"
  elif [[ -e /proc/xen ]]; then
    virtual="Xen"
  elif [[ "$sys_manu" == *"Microsoft Corporation"* ]]; then
    if [[ "$sys_product" == *"Virtual Machine"* ]]; then
      if [[ "$sys_ver" == *"7.0"* || "$sys_ver" == *"Hyper-V" ]]; then
        virtual="Hyper-V"
      else
        virtual="Microsoft Virtual Machine"
      fi
    fi
  else
    virtual="Dedicated母鸡"
  fi
}
get_system_info() {
  cname=$(awk -F: '/model name/ {name=$2} END {print name}' /proc/cpuinfo | sed 's/^[ \t]*//;s/[ \t]*$//')
  #cores=$(awk -F: '/model name/ {core++} END {print core}' /proc/cpuinfo)
  #freq=$(awk -F: '/cpu MHz/ {freq=$2} END {print freq}' /proc/cpuinfo | sed 's/^[ \t]*//;s/[ \t]*$//')
  #corescache=$(awk -F: '/cache size/ {cache=$2} END {print cache}' /proc/cpuinfo | sed 's/^[ \t]*//;s/[ \t]*$//')
  #tram=$(free -m | awk '/Mem/ {print $2}')
  #uram=$(free -m | awk '/Mem/ {print $3}')
  #bram=$(free -m | awk '/Mem/ {print $6}')
  #swap=$(free -m | awk '/Swap/ {print $2}')
  #uswap=$(free -m | awk '/Swap/ {print $3}')
  #up=$(awk '{a=$1/86400;b=($1%86400)/3600;c=($1%3600)/60} {printf("%d days %d hour %d min\n",a,b,c)}' /proc/uptime)
  #load=$(w | head -1 | awk -F'load average:' '{print $2}' | sed 's/^[ \t]*//;s/[ \t]*$//')
  opsy=$(get_opsy)
  arch=$(uname -m)
  #lbit=$(getconf LONG_BIT)
  kern=$(uname -r)
  # disk_size1=$( LANG=C df -hPl | grep -wvE '\-|none|tmpfs|overlay|shm|udev|devtmpfs|by-uuid|chroot|Filesystem' | awk '{print $2}' )
  # disk_size2=$( LANG=C df -hPl | grep -wvE '\-|none|tmpfs|overlay|shm|udev|devtmpfs|by-uuid|chroot|Filesystem' | awk '{print $3}' )
  # disk_total_size=$( calc_disk ${disk_size1[@]} )
  # disk_used_size=$( calc_disk ${disk_size2[@]} )
  #tcpctrl=$(sysctl net.ipv4.tcp_congestion_control | awk -F ' ' '{print $3}')
  virt_check
}

# Main menu function
menu() {
    echo -e "\
${Green_font_prefix}0.${Font_color_suffix} 安装 BBR + TCP 窗口调优 + 开启内核转发 + 系统资源限制调优
${Green_font_prefix}1.${Font_color_suffix} 安装BBR原版内核(已经是5.x的不需要)
${Green_font_prefix}2.${Font_color_suffix} TCP窗口调优
${Green_font_prefix}3.${Font_color_suffix} 开启内核转发
${Green_font_prefix}4.${Font_color_suffix} 系统资源限制调优
${Green_font_prefix}5.${Font_color_suffix} 屏蔽ICMP
${Green_font_prefix}6.${Font_color_suffix} 开放ICMP
"
    get_system_info
    echo -e "当前系统信息: ${Font_color_suffix}$opsy ${Green_font_prefix}$virtual${Font_color_suffix} $arch ${Green_font_prefix}$kern${Font_color_suffix}"

    read -p "请输入数字: " num
    case "$num" in
        0)
            bbr
            tcp_tune
            enable_forwarding
            ulimit_tune
            ;;
        1)
            bbr
            ;;
        2)
            tcp_tune
            ;;
        3)
            enable_forwarding
            ;;
        4)
            ulimit_tune
            ;;
        5)
            banping
            ;;
        6)
            unbanping
            ;;
        *)
            clear
            echo -e "${Error}:请输入正确数字 [0-99]"
            sleep 5s
            menu
            ;;
    esac
}

# Startup
copyright
menu
