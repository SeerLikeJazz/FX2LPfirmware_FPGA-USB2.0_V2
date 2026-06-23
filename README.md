# FX2LPfirmware\_FPGA-USB2.0\_V2

CY7C68013固件修改为3个端点

### 06232026
-  已修改，上一个commit最可能的问题点：你只把某个 endpoint 数量从 2 改成 3，但没有同步补齐对应的 endpoint descriptor，或者 Full-Speed/High-Speed/固件寄存器三者不一致。 Zadig 读取配置描述符失败时，就可能显示不了设备名。
- 添加了重枚举
- iSense-C的VID & PID = 8001 & 0001；  
  iSensys-X64  = 8001 & 0002；  
  iSensys-X32  = 8001 & 0003；   
  iSensys-X16  = 8001 & 0004；   
