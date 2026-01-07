先说结论：
你要改两块东西：

1. USB 描述符（`dscr.a51`）——把 EP4 IN 端点描述出来，并把接口的端点个数改成 3 个。
2. 固件配置（`slave.c`）——改 EP2 为 2×512，新增 EP4 为 IN、2×512，并给 EP4 配 FIFO / AUTOIN 长度。

下面分文件说具体改哪里。

---

## 一、`dscr.a51`：High-Speed 配置里加 EP4 IN

现在的 HighSpeed 配置大致是这样（关键部分）：

```asm
HighSpeedConfigDscr:   
      db   DSCR_CONFIG_LEN
      db   DSCR_CONFIG
      db   (HighSpeedConfigDscrEnd-HighSpeedConfigDscr) mod 256
      db   (HighSpeedConfigDscrEnd-HighSpeedConfigDscr)  /  256
      db   1                    ;; Number of interfaces
      db   1                    ;; Configuration number
      ...

;; Interface Descriptor
      db   DSCR_INTRFC_LEN
      db   DSCR_INTRFC
      db   0                    ;; Interface index
      db   0                    ;; Alternate setting
      db   2                    ;; Number of end points   <== 这里现在是 2
      db   0ffH
      db   00H
      db   00H
      db   0

;; EP2 OUT, bulk, 512
      db   DSCR_ENDPNT_LEN
      db   DSCR_ENDPNT
      db   02H                  ;; Endpoint number, and direction
      db   ET_BULK
      db   00H
      db   02H
      db   00H

;; EP6 IN, bulk, 512
      db   DSCR_ENDPNT_LEN
      db   DSCR_ENDPNT
      db   86H
      db   ET_BULK
      db   00H
      db   02H
      db   00H

HighSpeedConfigDscrEnd:
```

你要在这里加 EP4 IN，步骤：

### 1.1 接口端点个数：2 → 3

把接口描述符里的：

```asm
      db   2                    ;; Number of end points
```

改成：

```asm
      db   3                    ;; Number of end points
```

### 1.2 插入 EP4 IN 端点描述符

在 EP2 和 EP6 中间插入一段 EP4 IN（地址 0x84），Bulk，最大包长 512（0x0200）：

修改后建议写成：

```asm
;; EP2 OUT, bulk, 512
      db   DSCR_ENDPNT_LEN
      db   DSCR_ENDPNT
      db   02H                  ;; EP2 OUT
      db   ET_BULK
      db   00H                  ;; wMaxPacketSize LSB
      db   02H                  ;; wMaxPacketSize MSB (512)
      db   00H                  ;; bInterval

;; EP4 IN, bulk, 512  <== 新增
      db   DSCR_ENDPNT_LEN
      db   DSCR_ENDPNT
      db   84H                  ;; EP4 IN
      db   ET_BULK
      db   00H
      db   02H
      db   00H

;; EP6 IN, bulk, 512
      db   DSCR_ENDPNT_LEN
      db   DSCR_ENDPNT
      db   86H                  ;; EP6 IN
      db   ET_BULK
      db   00H
      db   02H
      db   00H
```

`(HighSpeedConfigDscrEnd-HighSpeedConfigDscr)` 是用标签差值算总长度的，不用你手动改。

> **Full-Speed 描述符提醒**：
> 你现在的 FullSpeedConfigDscr 只描述了 EP4/EP8 两个 64B 端点。如果你希望在 Full-Speed 下也让主机看到 EP2/EP4/EP6，那么需要用同样的方法，把 FS 的接口 `bNumEndpoints` 改成 3，并加上 EP2/EP4/EP6 的 64 字节端点描述符。
> 如果设备只在 HS 模式工作（或者你不在意 FS），可以先只改 HS 部分。

---

## 二、`slave.c`：端点配置和 FIFO 配置

### 2.1 TD_Init 里面的 EPxCFG

你现在 `TD_Init` 里大概是这样（你文件里的原始注释就是这个意思）：

```c
//EP2 设置为 BULK-OUT，4x，512
EP2CFG = 0xA0;                // out 512 bytes, 4x, bulk
SYNCDELAY;
//EP6 为 BULK-IN，4x
EP6CFG = 0xE0;                // in 512 bytes, 4x, bulk
SYNCDELAY;              
EP4CFG = 0x02;                // clear valid bit
SYNCDELAY;                     
EP8CFG = 0x02;                // clear valid bit
SYNCDELAY;
```

根据 FX2 的 EPxCFG 定义：

* `0xA0` = EP2, OUT, BULK, 512, **4x 缓冲**
* `0xA2` = EP2, OUT, BULK, 512, **2x 缓冲**
* `0xE0` = IN, BULK, 512, 4x 缓冲
* `0xE2` = IN, BULK, 512, 2x 缓冲

所以你要改成 **EP2：2×512；EP4：IN、2×512**，可以这样写，并顺手按端点号顺序配置（2 → 4 → 6 → 8，TRM 建议从低号往高号配置 EPxCFG，避免 buffer 分配混乱）：

```c
// EP2: BULK OUT, 512, 2x buffer
EP2CFG = 0xA2;                // out 512 bytes, 2x, bulk
SYNCDELAY;

// EP4: BULK IN, 512, 2x buffer  (新增)
EP4CFG = 0xE2;                // in 512 bytes, 2x, bulk
SYNCDELAY;

// EP6: BULK IN, 512, 4x buffer（看你需求，可保持 4x，也可同样改成 0xE2）
EP6CFG = 0xE0;                // in 512 bytes, 4x, bulk
SYNCDELAY;

// EP8 仍然不用
EP8CFG = 0x02;                // clear valid bit
SYNCDELAY;
```

> 如果你也希望 EP6 变成 2×512，把那行改成：
> `EP6CFG = 0xE2;  // in 512 bytes, 2x, bulk`

### 2.2 FIFO RESET 部分

你现在已经把 2/4/6/8 都 reset 了：

```c
FIFORESET = 0x80; // NAK-ALL
SYNCDELAY;
FIFORESET = 0x02; // reset, FIFO 2
SYNCDELAY;
FIFORESET = 0x04; // reset, FIFO 4
SYNCDELAY;
FIFORESET = 0x06; // reset, FIFO 6
SYNCDELAY;
FIFORESET = 0x08; // reset, FIFO 8
SYNCDELAY;
FIFORESET = 0x00; // clear NAK-ALL
```

这里已经包括 EP4 了，不需要再改。

### 2.3 EPxFIFOCFG：给 EP4 配 AUTOIN / WORDWIDE

你现在只配置了 EP2 / EP6 的 FIFO：

```c
// 处理已经在 AUTO 模式的情况...
SYNCDELAY;
EP2FIFOCFG = 0x00;            // AUTOOUT=0, WORDWIDE=1
SYNCDELAY;                    
EP2FIFOCFG = 0x11;            // AUTOOUT=1, WORDWIDE=1

SYNCDELAY;
EP6FIFOCFG = 0x0D;            // AUTOIN=1, ZEROLENIN=1, WORDWIDE=1
SYNCDELAY;
```

如果你要像 EP6 一样让 EP4 做自动 IN（Slave FIFO + AUTOIN），建议加上：

```c
SYNCDELAY;
EP4FIFOCFG = 0x0D;            // AUTOIN=1, ZEROLENIN=1, WORDWIDE=1
SYNCDELAY;
```

位置就放在 `EP6FIFOCFG` 前后都可以，习惯上按端点号顺序写好看一点：

```c
SYNCDELAY;
EP2FIFOCFG = 0x00;
SYNCDELAY;
EP2FIFOCFG = 0x11;

SYNCDELAY;
EP4FIFOCFG = 0x0D;            // 新增 EP4 IN FIFO 配置
SYNCDELAY;

SYNCDELAY;
EP6FIFOCFG = 0x0D;
SYNCDELAY;
```

> 如果你不打算让 EP4 用 AUTOIN，而是由 CPU/外部逻辑手动 `INPKTEND` 提交包，那 EP4FIFOCFG 可以不用设 AUTOIN，对应的主控逻辑也要配合改。

### 2.4 AUTOIN 长度：给 EP4 也设 512

在 `DR_SetConfiguration` 里，现在只给 EP6 / EP8 设置了 AUTOIN 长度：

```c
if( EZUSB_HIGHSPEED() )
{
    EP6AUTOINLENH = 0x02;
    SYNCDELAY;
    EP8AUTOINLENH = 0x02;   // 512 bytes
    SYNCDELAY;
    EP6AUTOINLENL = 0x00;
    SYNCDELAY;
    EP8AUTOINLENL = 0x00;
}
else
{
    EP6AUTOINLENH = 0x00;
    ...
}
```

如果你让 EP4 也用 AUTOIN，建议在 HS 分支里加上 EP4 的 512 字节：

```c
if( EZUSB_HIGHSPEED() )
{
    // EP4 IN: 512 bytes AUTOIN
    EP4AUTOINLENH = 0x02;
    SYNCDELAY;
    EP4AUTOINLENL = 0x00;
    SYNCDELAY;

    // EP6 IN: 512 bytes AUTOIN（已有）
    EP6AUTOINLENH = 0x02;
    SYNCDELAY;
    EP6AUTOINLENL = 0x00;
    SYNCDELAY;

    // 如果 EP8 不用，可以删掉 EP8AUTOIN* 这些行
}
else
{
    // Full-Speed 时如果你不打算用 EP4，可以不设；
    // 要用的话，把 EP4AUTOINLENH/L 改成 0x00 / 0x40 （64 字节）
}
```

---

## 三、主机侧小提示（不是固件代码）

* 主机程序 / 驱动里要新增访问 `0x84` 端点（EP4 IN）。
* EP2 还是 `0x02`，只是从 4×512 改成 2×512，对主机是透明的，但吞吐和延时会稍有不同。
* 如果你在 PC 端用 Cypress Control Center 之类工具测试，要注意在“Endpoint”列表里新出现的 `EP4IN`。

---

## 小结（你要动的地方）

**必须改的：**

1. `dscr.a51`

   * HighSpeed 接口描述符：`bNumEndpoints` 改成 `3`。
   * HighSpeed 配置中插入一个 EP4 IN 的端点描述符（地址 0x84，Bulk，wMaxPacketSize=512）。

2. `slave.c`

   * `TD_Init` 中：

     * `EP2CFG = 0xA0;` → `EP2CFG = 0xA2;`（EP2：2×512 OUT）
     * `EP4CFG = 0x02;` → `EP4CFG = 0xE2;`（EP4：IN、Bulk、512、2×缓冲）
     * 保持 `EP6CFG` 或按需改成 0xE2。
   * `EPxFIFOCFG`：新增一行 `EP4FIFOCFG = 0x0D;`（如果 EP4 用 AUTOIN）。
   * `DR_SetConfiguration`：新增 `EP4AUTOINLENH/L` 的 512 字节配置（如果 EP4 用 AUTOIN）。

如果你愿意，我也可以帮你把这几块代码直接改成完整的补丁（diff 形式），你只要拷进去对比一下就行。
