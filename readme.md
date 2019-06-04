## centos一键前端环境搭建
## 实现功能
  1. 更新yum源为阿里云源
  2. nodejs10 lts 最新版本
  3. yarn 最新版本并使用淘宝源
  4. git 2.21.0 编译安装
  5. 卸载centos自带的 mariadb-libs 并安装mysql 8.0.15
  6. 打印mysql默认用户密码
  7. nginx 最新版本安装
  8. acme.sh 自动申请ssl证书
  9. 添加nginx，mysql服务为开机启动
## 准备
- centos 7.0 以上系统
- 将域名解析到本机ip
- 需要使用root权限执行该脚本

## 开始使用

```bash
bash <(curl -L -s https://raw.githubusercontent.com/fchengjin/fedEnv/master/install.sh) | tee fed.log
```

## TODO
- [x] 用户自己选择安装[#1](https://github.com/fchengjin/fedEnv/issues/1)