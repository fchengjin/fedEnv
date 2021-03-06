#!/bin/bash
#====================================================
#	System Request: Centos 7+
#	Author:	fcheng
#   Email: fchengjin@126.com
#	Dscription: 前端一键环境搭建，nginx，git，mysql，node，yarn， 更换yum源，acme自动申请ssl证书
#	Version: 0.0.3
#====================================================

#fonts color
Green="\033[32m" 
Red="\033[31m" 
Yellow="\033[33m"
GreenBG="\033[42;37m"
RedBG="\033[41;37m"
Font="\033[0m"

#notification information
Info="${Green}[信息]${Font}"
OK="${Green}[OK]${Font}"
Error="${Red}[错误]${Font}"

nginx_conf_dir="/etc/nginx/conf.d"
nginx_cert_dir="/etc/nginx/cert"

current_time=`date "+%Y%m%d%H%M%S"`
lastest_git_version="2.21.0"
lastest_mysql_version="8.0.15"

INS="yum"

softewares=(更换aliyun源 nginx yarn git mysql acme.sh)

source /etc/os-release

#从VERSION中提取发行版系统的英文名称，为了在debian/ubuntu下添加相对应的Nginx apt源
VERSION=`echo ${VERSION} | awk -F "[()]" '{print $2}'`


# 选择需要安装的软件
choose() {
    echo -e "${Green}请选择需要安装的软件: 多选用,分割，默认全部安装，acme.sh 需要搭配 nginx，示例:2,3 ${Font}"
    selected=""
    #${#array[@]}获取数组长度用于循环
    local softwares_length=${#softewares[@]}
    for(( i=0;i<$softwares_length;i++)) do
        echo "$[$i+1]) ${softewares[i]}";
    done;

    read -p "请选择(示例：2,3；不填默认全部)：" user_input
    str_arr=(${user_input//,/ })
    [[  ${#str_arr[*]} == 0 ]] && str_arr=(1 2 3 4 5)
    for(( i=0;i<$softwares_length;i++)) do
        tmp=`if echo "${str_arr[@]}" | grep -w $[$i+1] &>/dev/null; then  
                echo 1
            fi`
        if [ "$tmp" == "1" ];then
            selected="$selected ${softewares[i]}"
        fi
    done
    echo -e "${Green}你已选择安装${Font}${selected}"
}

is_root(){
    if [ `id -u` == 0 ]
        then echo -e "${OK} ${GreenBG} 当前用户是root用户，进入安装流程 ${Font} "
        sleep 3
    else
        echo -e "${Error} ${RedBG} 当前用户不是root用户，请切换到root用户后重新执行脚本 ${Font}" 
        exit 1
    fi
}


check_system(){
    if [[ "${ID}" == "centos" && ${VERSION_ID} -ge 7 ]];then
      echo -e "${OK} ${GreenBG} 当前系统为 Centos ${VERSION_ID} ${VERSION} ${Font} "
      echo -e "${OK} ${GreenBG} SElinux 设置中，请耐心等待，不要进行其他操作${Font} "
      setsebool -P httpd_can_network_connect 1
      echo -e "${OK} ${GreenBG} SElinux 设置完成 ${Font} "

    else
      echo -e "${Error} ${RedBG} 当前系统为 ${ID} ${VERSION_ID} 不在支持的系统列表内，需要centos 7.0以上版本，安装中断 ${Font} "
      exit 1
    fi
}

set_yum_origin() {
# 更改yum源为阿里云源
          mv /etc/yum.repos.d/CentOS-Base.repo /etc/yum.repos.d/CentOS-Base.repo.${current_time}.bak
          echo -e "${OK} ${GreenBG} yum 初始配置备份完成 ${Font}"
          wget -O /etc/yum.repos.d/CentOS-Base.repo http://mirrors.aliyun.com/repo/Centos-7.repo
          yum clean all
          yum makecache
          echo -e "${OK} ${GreenBG} yum 设置为阿里云源 ${Font}"
          sleep 1
}

set_nginx_origin() {
    # 添加nginx源
    cat>/etc/yum.repos.d/nginx.repo<<EOF
[nginx]
name=nginx repo
baseurl=http://nginx.org/packages/mainline/centos/7/\$basearch/
gpgcheck=0
enabled=1
EOF
    echo -e "${OK} ${GreenBG} Nginx 源 安装完成 ${Font}" 

}

set_yarn_origin() {
    # 添加yarn源
    cat>/etc/yum.repos.d/yarn.repo<<EOF
[yarn]
name=Yarn Repository
baseurl=https://dl.yarnpkg.com/rpm/
enabled=1
gpgcheck=1
gpgkey=https://dl.yarnpkg.com/rpm/pubkey.gpg
EOF
      echo -e "${OK} ${GreenBG} Yarn 源 安装完成 ${Font}" 
}

judge(){
    if [[ $? -eq 0 ]];then
        echo -e "${OK} ${GreenBG} $1 完成 ${Font}"
        sleep 1
    else
        echo -e "${Error} ${RedBG} $1 失败${Font}"
        return
    fi
}

is_cmd_exists() {
    local cmd="$1"
    command -v "$cmd">/dev/null 2>&1
    judge $1
}

port_exist_check(){
    if [[ 0 -eq `lsof -i:"$1" | wc -l` ]];then
        echo -e "${OK} ${GreenBG} $1 端口未被占用 ${Font}"
        sleep 1
    else
        echo -e "${Error} ${RedBG} 检测到 $1 端口被占用，以下为 $1 端口占用信息 ${Font}"
        lsof -i:"$1"
        echo -e "${OK} ${GreenBG} 5s 后将尝试自动 kill 占用进程 ${Font}"
        sleep 5
        lsof -i:"$1" | awk '{print $2}'| grep -v "PID" | xargs kill -9
        echo -e "${OK} ${GreenBG} kill 完成 ${Font}"
        sleep 1
    fi
}



# 安装nginx
install_nginx(){
    ${INS} install nginx -y
    if [[ -d /etc/nginx ]];then
        echo -e "${OK} ${GreenBG} nginx 安装完成 ${Font}"
        sleep 2
    else
        echo -e "${Error} ${RedBG} nginx 安装失败 ${Font}"
        return
    fi
    if [[ ! -f /etc/nginx/nginx.conf.bak ]];then
        cp /etc/nginx/nginx.conf /etc/nginx/nginx.conf.bak
        echo -e "${OK} ${GreenBG} nginx 初始配置备份完成 ${Font}"
        sleep 1
    fi
}
# 安装nodejs
install_nodejs() {
    curl -sL https://rpm.nodesource.com/setup_10.x | sudo bash -
    ${INS} install nodejs -y
}
# 安装yarn
install_yarn(){
    ${INS} install yarn -y
    is_cmd_exists yarn
    yarn config set registry "https://registry.npm.taobao.org"
    judge "更改yarn源为淘宝源"
}

#安装git
install_git() {
    ${INS} install curl-devel expat-devel gettext-devel openssl-devel zlib-devel -y
    ${INS} install gcc perl-ExtUtils-MakeMaker wget -y
    cd ~
    wget https://github.com/git/git/archive/v$lastest_git_version.tar.gz -O git-$lastest_git_version.tar.gz
    tar -zxvf git-$lastest_git_version.tar.gz > /dev/null
    cd git-$lastest_git_version
    make prefix=/usr/local/git all > /dev/null
    make prefix=/usr/local/git install > /dev/null
    echo "export PATH=$PATH:/usr/local/git/bin" >> /etc/bashrc
    yum remove git -y
    sleep 1
    source /etc/bashrc

}

# 安装mysql
install_mysql() {
    cd ~
    wget http://mirrors.ustc.edu.cn/mysql-ftp/Downloads/MySQL-8.0/mysql-$lastest_mysql_version-1.el7.x86_64.rpm-bundle.tar
    tar -xvf mysql-$lastest_mysql_version-1.el7.x86_64.rpm-bundle.tar
    # 卸载centos自带的 mariadb-libs
    mariadbVersion=`rpm -qa | grep mariadb`
    rpm -e --nodeps $mariadbVersion
    # 安装依赖包
    yum install libaio numactl -y
    rpm -ivh ./mysql-community-common-$lastest_mysql_version-1.el7.x86_64.rpm
    rpm -ivh ./mysql-community-libs-$lastest_mysql_version-1.el7.x86_64.rpm
    rpm -ivh ./mysql-community-libs-compat-$lastest_mysql_version-1.el7.x86_64.rpm
    rpm -ivh ./mysql-community-client-$lastest_mysql_version-1.el7.x86_64.rpm
    rpm -ivh ./mysql-community-embedded-compat-$lastest_mysql_version-1.el7.x86_64.rpm
    rpm -ivh ./mysql-community-server-$lastest_mysql_version-1.el7.x86_64.rpm
    sleep 1
}

install_ssl() {
  if [[ "${ID}" == "centos" ]];then
        ${INS} install socat nc -y        
    else
        ${INS} install socat netcat -y
    fi
    judge "安装 SSL 证书生成脚本依赖"

    curl  https://get.acme.sh | sh
    judge "安装 SSL 证书生成脚本" 
    acme
}

domain_check(){
    read -p "请输入你的域名信息(eg:www.baidu.com):" domain
    domain_ip=`ping ${domain} -c 1 | sed '1{s/[^(]*(//;s/).*//;q}'`
    echo -e "${OK} ${GreenBG} 正在获取 公网ip 信息，请耐心等待 ${Font}"
    local_ip=`curl -4 ip.sb`
    echo -e "域名dns解析IP：${domain_ip}"
    echo -e "本机IP: ${local_ip}"
    sleep 2
    if [[ $(echo ${local_ip}|tr '.' '+'|bc) -eq $(echo ${domain_ip}|tr '.' '+'|bc) ]];then
        echo -e "${OK} ${GreenBG} 域名dns解析IP  与 本机IP 匹配 ${Font}"
        sleep 2
    else
        echo -e "${Error} ${RedBG} 域名dns解析IP 与 本机IP 不匹配 是否继续安装？（y/n）${Font}" && read install
        case $install in
        [yY][eE][sS]|[yY])
            echo -e "${GreenBG} 继续安装 ${Font}" 
            sleep 2
            ;;
        *)
            echo -e "${RedBG} 安装终止 ${Font}"
            exit 2
            ;;
        esac
    fi
}

acme(){
    ## standalone 模式需要安装socat
    yum install socat -y
    ~/.acme.sh/acme.sh --issue -d ${domain} --standalone -k ec-256 --force
    if [[ $? -eq 0 ]];then
        echo -e "${OK} ${GreenBG} SSL 证书生成成功 ${Font}"
        sleep 2
        ~/.acme.sh/acme.sh --installcert -d ${domain} --fullchainpath ${nginx_cert_dir}/${domain}.crt --keypath ${nginx_cert_dir}/${domain}.key --ecc --reloadcmd "service nginx reload"
        if [[ $? -eq 0 ]];then
        echo -e "${OK} ${GreenBG} 证书配置成功 ${Font}"
        sleep 2
        fi
    else
        echo -e "${Error} ${RedBG} SSL 证书生成失败 ${Font}"
    fi
}

modify_nginx(){
    sed -i "/server_name/c \\\tserver_name ${domain};" ${nginx_conf_dir}/$domain.conf
    sed -i "/ssl_certificate_key /c \\\tssl_certificate_key ${nginx_cert_dir}/${domain}.key;" ${nginx_conf_dir}/$domain.conf
    sed -i "/ssl_certificate /c \\\tssl_certificate ${nginx_cert_dir}/${domain}.crt;" ${nginx_conf_dir}/$domain.conf
    sed -i "/access_log/c \\\taccess_log /var/log/nginx/${domain}.log;" ${nginx_conf_dir}/$domain.conf
    sed -i "/error_log/c \\\terror_log /var/log/nginx/${domain}.error.log;" ${nginx_conf_dir}/$domain.conf
    sed -i "/return/c \\\treturn 301 https://${domain}\$request_uri;" ${nginx_conf_dir}/$domain.conf
}


nginx_conf_add(){
    mkdir $nginx_cert_dir
    mv ${nginx_conf_dir}/$domain.conf  ${nginx_conf_dir}/$domain.conf.${current_time}.bak
    touch ${nginx_conf_dir}/$domain.conf
    cat>${nginx_conf_dir}/$domain.conf<<EOF
    server {
        listen 443 ssl;
        ssl_certificate       /etc/nginx/cert/domain.crt;
        ssl_certificate_key   /etc/nginx/cert/domain.key;
        ssl_protocols         TLSv1 TLSv1.1 TLSv1.2;
        ssl_ciphers           HIGH:!aNULL:!MD5;
        server_name           serveraddr.com;
        index index.html index.htm;
        root   /usr/share/nginx/html;
        error_page 400 = /400.html;
        add_header Access-Control-Allow-Methods GET,POST,OPTIONS,PUT,DELETE;
        location / {
            root   /usr/share/nginx/html;
            index  index.html index.htm;
        }
        access_log  /var/log/nginx/domain.log;
        error_log  /var/log/nginx/domain.error.log;
    }
    server {
        listen 80;
        server_name serveraddr.com;
        return 301 https://use.shadowsocksr.win\$request_uri;
    }
    
EOF

modify_nginx
judge "域名配置修改"
}



# 添加开机启动并启动
start_process_systemd(){
    ### nginx服务在安装完成后会自动启动。需要通过restart或reload重新加载配置
    systemctl enable nginx
    judge "Nginx 添加为开机启动"
    sleep 1
    systemctl start nginx
    judge "Nginx 启动"

    if [[ "$selected" =~ "mysql" ]];then
        # mysql 添加为开机启动
        systemctl enable mysqld
        judge "Mysqld 添加为开机启动"
        systemctl start mysqld
        judge "mysqld 启动"
        # 抓取mysql默认生成的随机密码
        mysql_default_pwd=`grep -E -i 'root.*?' /var/log/mysqld.log -o`
    fi
}

show_information(){
    nginx_version_full=`rpm -qa | grep nginx`
    nginx_version=`echo $nginx_version_full | grep -P '(\d+\.){2}\d+' -o`
    git_version=`git --version`
    yarn_version=`yarn -v`
    node_version=`node -v`
    mysql_version_full=`mysql --version`
    mysql_version=`$mysql_version_full | grep -P '(\d+\.){2}\d+' -o`
    
    clear
    echo -e "${ok} ${Green} 一键环境配置安装成功${Font}"
    [[ "$selected" =~ "nginx" ]] && echo -e "${Green} nginx版本为:${Font} ${nginx_version}"
    [[ "$selected" =~ "yarn" ]] && echo -e "${Green} nodejs版本为:${Font} ${node_version:1}" && echo -e "${Green} yarn版本为:${Font} $yarn_version"
    [[ "$selected" =~ "git" ]] && echo -e "${Green} git版本为:${Font} ${git_version:12}"
    [[ "$selected" =~ "mysql" ]] &&  echo -e "${Green} mysql版本为:${Font} $mysql_version" && echo -e "${red} mysql 默认账号密码为:${Font} ${mysql_default_pwd}"
}

clean() {
    # 执行安装之后的清理工作
    cd ~
    rm -f mysql*
    rm -rf git*
    source /etc/bashrc
    judge "清理安装文件"
}

main() {
    # is_root
    choose
    [[ "$selected" =~ "acme.sh" ]] && domain_check
    check_system
    [[ "$selected" =~ "更换aliyun源" ]] && set_yum_origin
    [[ "$selected" =~ "nginx" ]] && set_nginx_origin && install_nginx
    [[ "$selected" =~ "yarn" ]] && install_nodejs && set_yarn_origin && install_yarn
    [[ "$selected" =~ "git" ]] && install_git
    [[ "$selected" =~ "mysql" ]] && install_mysql

    # # 安装ssl 证书
    [[ "$selected" =~ "acme.sh" ]] && nginx_conf_add
    port_exist_check 80
    [[ "$selected" =~ "acme.sh" ]] && install_ssl
    start_process_systemd
    clean
    show_information
}
main