#!/bin/bash
PATH=/bin:/sbin:/usr/bin:/usr/sbin:/usr/local/bin:/usr/local/sbin:~/bin
export PATH
LANG=en_US.UTF-8

# ================= 安卓设备特殊适配 =================
# 检测安卓设备架构
ANDROID_ARCH=$(uname -m)
if [[ "$ANDROID_ARCH" != "aarch64" ]]; then
    echo "不支持的设备架构: $ANDROID_ARCH"
    exit 1
fi

# 使用 Termux 专用路径
setup_path="/data/data/com.termux/files/home/www"
mkdir -p $setup_path

# 降低资源要求
MIN_SPACE=200000  # 200MB
MIN_INODES=500    # 500 inodes

INSTALL_LOGFILE="/tmp/btpanel-install.log"
Btapi_Url='https://install.baota.sbs'
Check_Api=$(curl -Ss --connect-timeout 5 -m 2 $Btapi_Url/api/SetupCount)
if [ "$Check_Api" != 'ok' ];then
    echo "此宝塔第三方云端无法连接，因此安装过程已中止！";
    exit 1;
fi

if [ $(whoami) != "root" ];then
    echo "请使用root权限执行宝塔安装命令！"
    exit 1;
fi

is64bit=$(getconf LONG_BIT)
if [ "${is64bit}" != '64' ];then
    echo "抱歉, 当前面板版本不支持32位系统, 请使用64位系统或安装宝塔5.9!";
    exit 1
fi

Ready_Check(){
    WWW_DISK_SPACE=$(df |grep /data|awk '{print $4}')
    ROOT_DISK_SPACE=$(df |grep /$|awk '{print $4}')
 
   if [ "${ROOT_DISK_SPACE}" -le $MIN_SPACE ];then
        df -h
        echo -e "系统盘剩余空间不足 ${MIN_SPACE}KB 无法继续安装宝塔面板！"
        echo -e "请尝试清理磁盘空间后再重新进行安装"
        exit 1
    fi
    if [ "${WWW_DISK_SPACE}" ] && [ "${WWW_DISK_SPACE}" -le $MIN_SPACE ] ;then
        echo -e "/www盘剩余空间不足 ${MIN_SPACE}KB 无法继续安装宝塔面板！"
        echo -e "请尝试清理磁盘空间后再重新进行安装"
        exit 1
    fi

    ROOT_DISK_INODE=$(df -i|grep /$|awk '{print $2}')
    if [ "${ROOT_DISK_INODE}" != "0" ];then
        ROOT_DISK_INODE_FREE=$(df -i|grep /$|awk '{print $4}')
        if [ "${ROOT_DISK_INODE_FREE}" -le $MIN_INODES ];then
            echo -e "系统盘剩余inodes空间不足 ${MIN_INODES},无法继续安装！"
            echo -e "请尝试清理磁盘空间后再重新进行安装"
            exit 1
        fi
    fi

    WWW_DISK_INODE=$(df -i|grep /data|awk '{print $2}')
    if [ "${WWW_DISK_INODE}" ] && [ "${WWW_DISK_INODE}" != "0" ] ;then
        WWW_DISK_INODE_FREE=$(df -i|grep /data|awk '{print $4}')
        if [ "${WWW_DISK_INODE_FREE}" ] && [ "${WWW_DISK_INODE_FREE}" -le $MIN_INODES ] ;then
            echo -e "/www盘剩余inodes空间不足 ${MIN_INODES}, 无法继续安装！"
            echo -e "请尝试清理磁盘空间后再重新进行安装"
            exit 1
        fi
    fi
}

# ================= 服务管理适配 =================
start_bt() {
    cd $setup_path/server/panel
    python tools.py start
}

stop_bt() {
    cd $setup_path/server/panel
    python tools.py stop
}

# ================= 安装流程适配 =================
Install_Deb_Pack(){
    # 简化的依赖列表
    debPacks="python3 python3-pip python3-venv wget curl git"
    apt-get install -y $debPacks
}

Install_Python_Lib(){
    # 使用系统自带Python
    python_bin="/usr/bin/python3"
    pip_bin="/usr/bin/pip3"
    
    # 安装必要库
    $pip_bin install -U pip
    $pip_bin install psutil gevent flask
}

Install_Bt(){
    panelPort=5701  # 固定端口
    
    mkdir -p $setup_path/server/panel
    cd $setup_path/server/panel
    
    echo "正在下载面板文件..."
    wget -O panel.zip ${Btapi_Url}/install/src/panel6.zip
    unzip -o panel.zip
    rm panel.zip
    
    # 创建启动脚本
    cat > start_bt.sh <<EOF
#!/bin/bash
cd $setup_path/server/panel
python tools.py start
EOF
    chmod +x start_bt.sh
}

# ================= 主安装流程 =================
echo "开始适配安卓设备安装..."
Ready_Check
Install_Deb_Pack
Install_Python_Lib
Install_Bt

# 创建快捷命令
echo "alias btstart='cd $setup_path/server/panel && ./start_bt.sh'" >> ~/.bashrc
echo "alias btstop='pkill -f \"python tools.py\"'" >> ~/.bashrc

echo "安装完成！"
echo "启动命令: btstart"
echo "停止命令: btstop"
echo "访问地址: http://127.0.0.1:8888"
