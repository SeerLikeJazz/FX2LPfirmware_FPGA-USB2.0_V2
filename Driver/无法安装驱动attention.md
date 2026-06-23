先按这个顺序处理
1. 在设备管理器彻底卸载错误驱动

设备管理器 → 右键 EZ-USB FX2 → 卸载设备。
如果出现复选框：

删除此设备的驱动程序软件

一定要勾选，然后卸载。

然后拔掉 USB，不要马上插回。

2. 用命令删除 Windows 已缓存的错误 INF

以管理员打开 CMD 或 PowerShell，执行：

pnputil /enum-drivers | findstr /i "0547 2001 intraoral ez-usb cypress cyusb"

如果能看到类似 oemXX.inf，继续查看：

pnputil /enum-drivers

找到和 0547/2001、Intraoral、Anchor Chips、EZ-USB 相关的 oemXX.inf 后删除：

pnputil /delete-driver oemXX.inf /uninstall /force

把 oemXX.inf 换成你实际看到的编号。

3. 重新插入，看硬件 ID 是否恢复

重新插板子，查看：

设备管理器 → EZ-USB FX2 → 属性 → 详细信息 → 硬件 ID。

如果仍然是：

USB\VID_0547&PID_2001

那就不要直接指向 Cypress Suite USB 3.4.7\Driver 安装了，因为官方 cyusb3.inf 通常不一定包含这个 VID/PID，所以 Windows 会说“不兼容”或安装失败。