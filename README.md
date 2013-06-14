hincubator使用指南
                                                        (c) HANBORQ INC
                                                            Willis Gong
                                                            2013-04

1) 什么是hincubator
   hIncubator用于生成PXE/KS安装母机。
   安装母机包含一个TFTP服务器（BOOT SERVER），一个NFS服务器(INSTALL SERVER)，
   以及相关的配置脚本，用来支持批量无人值守的CENTOS安装（其他LINUX版本安装，需验证）。

2) 使用方法
   a) 检查安装了tftp服务和nfs服务。

   b) 定义如下hIncubator配置文件
      <SRC_CONFIG_DIR>/ALLMACS   定义所有的待安装的客户机的MAC地址
      <SRC_CONFIG_DIR>/ALLIPS    定义拟配置给待安装的客户机的IP地址
      <SRC_CONFIG_DIR>/ALLHOSTS  定义拟配置给待安装的客户机的hostname
      上述文件为简单的文本行文件；上述3个文件同一行对应客户机；3个文件行数需一致。

   c) 准备KS/PXE配置模板文件
      <SRC_CONFIG_DIR>/IP.template   KS配置模板文件
      <SRC_CONFIG_DIR>/MAC.template  PXE配置模板文件

   d) 在<SRC_CONFIG_DIR>/BOOT_SERVER目录下准备BOOT SERVER需要的文件。
      对于CENTOS安装，需要准备下列文件（从CENTOS光盘拷入）

        <SRC_CONFIG_DIR>/BOOT_SERVER
                             ├── initrd.img
                             ├── pxelinux.0
                             └── vmlinuz

   e) 在<SRC_CONFIG_DIR>/INSTALL_SERVER目录下准备INSTALL SERVER需要的文件。

        <SRC_CONFIG_DIR>/INSTALL_SERVER
                             ├── CentOS-6.2-x86_64-bin-DVD1.iso
                             └── images
                                 ├── efiboot.img
                                 ├── efidisk.img
                                 ├── install.img
                                 ├── pxeboot
                                 │   ├── initrd.img
                                 │   ├── TRANS.TBL
                                 │   └── vmlinuz
                                 └── TRANS.TBL

   f) 运行./hincubator [-c <SRC_CONFIG_DIR>] [-o <OUTPUT_DIR>] [-overwrite]
      其中，
      SRC_CONFIG_DIR是上述配置目录；
      OUTPUT_DIR是用于BOOT_SERVER和INSTALL_SERVER的文件存放目录，一般指定于根
      目录/下，如/pxeroot。

   g) 根据上述运行给出的屏幕提示完成系统修改（要求root权限）

   h) 至此，母机已经配置完成，在完成必要的系统服务重启后母机即可对客户机服务：
         service xinetd restart    重启tftp服务
         service nfs restart       重启nfs服务
         service dhcpd restart     重启dhcp服务

3) 高级tunning
   需要自定义KS安装，可以调整<SRC_CONFIG_DIR>/IP.template。
