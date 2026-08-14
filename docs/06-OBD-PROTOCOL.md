# 06 · OBD2 协议实现规范

> 版本：v1.1 · 读者：Codex（实现 `app/lib/obd/` 模块的依据）
> 应用层标准：SAE J1979；车载链路由 ELM327 处理

---

## 1. 范围、分层与接口

```
OBDClient
├── ProtocolParser       # ELM 文本归一化、多 ECU/多帧聚合、SAE J1979 解析
└── ELM327Transport      # AT/OBD 命令、提示符、串行队列、分命令超时/重试
     └── OBDConnection   # WiFi / BLE / Android SPP / Mock 字节通道
          └── ELM327     # 车辆协议选择、总线访问、物理/链路层时序与流控
               └── CAN / ISO 9141 / KWP / J1850
```

App **不实现** CAN、ISO 9141、KWP 或 J1850 的物理/链路层编解码。ELM327 与车辆总线交互；App 的 `ProtocolParser` 负责把 ELM 返回的文本归一化，保留 ECU 来源，重组其呈现的多帧载荷，再解释 SAE J1979 service、PID、DTC、VIN 和冻结帧。

**高层接口（契约示意）：**

```dart
class OBDClient {
  Future<List<DTC>> readDtc();                         // Mode 03
  Future<List<DTC>> readPendingDtc();                  // Mode 07
  Future<List<DTC>> readPermanentDtc();                // Mode 0A
  Future<void> clearDtc();                             // Mode 04；不自动重试
  Future<PidReadResult<T>> readPid<T>(PID<T> pid);     // Mode 01；按 ECU 返回
  Future<SupportedPidSet> readSupportedPids();         // 00 / 20 / 40 / 60
  Future<ReadinessStatus> readReadiness();             // Mode 01 PID 01
  Future<FreezeFrameReadResult> readFreezeFrame({
    required int frameNumber,
    Set<PID<dynamic>>? pids,
  });                                                  // Mode 02
  Future<VinReadResult> readVin();                     // Mode 09 PID 02
  Stream<PidBatch> samplePids(
    Set<PID<dynamic>> pids, {
    Duration interval = const Duration(milliseconds: 500),
  });
}
```

职责约束：

- `OBDConnection` 只传输字节；BLE 分包/合包属于连接实现，不能把 BLE notification 当成一条完整 ELM 响应。
- `ELM327Transport` 同一时刻只运行一个命令，跨任意数量的输入分片收集到 `>`，返回原始响应和命令元数据。
- `ProtocolParser` 不持有 Socket/GATT，输入为完整原始 ELM 响应，输出为 typed result 或 typed error。
- `OBDClient` 编排命令、能力探测和采样，不让 UI 拼 AT/SAE 请求字符串。

平台范围：WiFi 与 BLE 支持 Android/iOS；蓝牙经典 SPP **仅支持 Android**。iOS 不创建 `SppConnection`，连接页也不得展示 SPP 选项。

---

## 2. ELM327 AT 命令集（首发必须实现）

| 命令 | 作用 | 首发策略 |
|---|---|---|
| `AT Z` | 复位 | 连接后首个命令；使用复位专用长超时 |
| `AT E0` | 关闭回显 | 首选；解析器仍容忍克隆设备继续回显 |
| `AT L0` | 关闭额外 LF | 首选；解析器同时接受 `\r` 和 `\r\n` |
| `AT S0` | 关闭空格 | 首选紧凑十六进制；解析器也接受带空格响应 |
| `AT H1` | 开启报文头 | 诊断读取保持开启，以保留 ECU 来源和多 ECU 响应 |
| `AT SP 0` | 自动协议检测 | 首次连接默认；真正搜索可能发生在随后首条 SAE 请求 |
| `AT SP n` | 指定协议 | 用户/适配器配置明确要求时使用 |
| `AT DP` / `AT DPN` | 查询当前协议 | 记录协议名/编号，供报头解析与诊断日志使用 |
| `AT ST hh` | ELM 车辆响应等待时间 | `hh` 为十六进制，单位约 4ms；`AT ST 64` = `0x64 × 4ms` = **400ms** |
| `AT RV` | 读取适配器供电电压 | 与 SAE PID 42 分开建模 |
| `AT I` | 设备信息 | 识别固件/克隆设备，用于兼容性日志 |
| `AT AL` | 允许长消息 | VIN 和可能的多帧 SAE 响应前启用 |

**`AT SP n` 协议映射：**

| n | ELM327 选择的车载协议 |
|---|---|
| 0 | 自动 |
| 1 | SAE J1850 PWM（Ford）|
| 2 | SAE J1850 VPW（GM）|
| 3 | ISO 9141-2 |
| 4 | ISO 14230-4 KWP（5 baud init）|
| 5 | ISO 14230-4 KWP（fast init）|
| 6 | ISO 15765-4 CAN（11-bit 500k）|
| 7 | ISO 15765-4 CAN（29-bit 500k）|
| 8 | ISO 15765-4 CAN（11-bit 250k）|
| 9 | ISO 15765-4 CAN（29-bit 250k）|

该映射用于配置 ELM327，不表示 App 分别实现九套底层协议。

---

## 3. 握手、超时与重试

**握手顺序：**

```text
connect
→ AT Z
→ AT E0
→ AT L0
→ AT S0
→ AT H1
→ AT SP 0
→ AT ST 64
→ 01 00      # 首条 SAE 请求，同时触发自动协议搜索
→ AT DP/DPN  # 记录实际协议
```

`AT SP 0` 返回 `OK` 不等于已找到车辆协议；必须以首条合法 SAE J1979 响应作为握手成功条件。

### 3.1 分命令宿主超时

`AT ST` 是 ELM 内部等待车辆响应的时间；App 宿主超时还包含连接分片、ELM 处理与提示符返回，必须更长。首发默认值：

| 命令类别 | 宿主超时 | 自动重试 |
|---|---:|---:|
| `AT Z` | 3s | 连接重建后最多 1 次 |
| 普通 AT 配置 / `AT I` / `AT DP` | 1.5s | 最多 1 次 |
| `AT SP 0` | 2s | 最多 1 次 |
| 自动协议下的首条 `01 00` | 12s | 最多 1 次；重试前重新 `AT SP 0` |
| 常规 Mode 01 PID | 1.5s | 只读命令最多 2 次 |
| Mode 03 / 07 / 0A / 02 | 3s | 只读命令最多 1 次 |
| Mode 09 VIN | 5s | 最多 1 次 |
| Mode 04 清码 | 3s | **不自动重试**，结果不明时要求用户重新读取确认 |

连接类型或真机测试证明需要更长时间时，可由适配器 profile 覆盖这些默认值；不得退回“所有命令统一 300ms”。`NO DATA` 是有效响应，不按超时重试。连续 3 个独立命令发生传输超时或连接错误时，标记连接断开并进入受控重连。

### 3.2 原始响应与归一化

在 `AT L0 S0 H1` 下，一台 11-bit CAN 适配器可能返回：

```text
010C\r
SEARCHING...\r
7E804410C1AF8\r
7E904410C1AF8\r
>
```

其中 `7E8` / `7E9` 是 ECU 来源，`04` 是该示例的载荷长度，`410C1AF8` 是 SAE 响应。克隆设备可能忽略 E0/L0/S0，返回 echo、空格或 `\r\n`；因此不能以字符串固定下标解析。

`ProtocolParser` 必须按以下顺序处理：

1. `ELM327Transport` 跨 TCP/BLE 分片收集到 `>`；`>` 只表示本次 ELM 命令结束，不是 SAE 数据。
2. 按 `\r` / `\n` 拆行，去空行；移除与请求等价的 echo，但保留原始响应用于脱敏调试日志。
3. 将 `SEARCHING...`、`NO DATA`、`STOPPED`、`?`、`CAN ERROR`、`UNABLE TO CONNECT`、`BUS INIT...ERROR` 等识别为 typed status/error，不当作十六进制。
4. 对数据行移除任意空白并转大写，拒绝奇数长度或非十六进制字符。
5. 根据 `AT DP/DPN` 和实际行形态解析可变长度报头；**保留 ECU/source address**，不能统一丢头后混在一起。
6. 按 ECU 分组；对多帧载荷校验声明长度与连续帧序号，去除 transport metadata/padding 后再交给 SAE J1979 解析。
7. 校验响应 service（请求 Mode + `0x40`）、PID/frame number；无法匹配的 ECU 响应作为独立诊断信息，不冒充成功结果。

带空格的 `7E8 04 41 0C 1A F8` 与紧凑的 `7E804410C1AF8` 必须归一化为同一结构：`sourceEcu=7E8`、`payload=[41, 0C, 1A, F8]`。

---

## 4. SAE J1979 模式（首发）

| Mode | 请求示例 | 响应 service | 用途 |
|---|---|---|---|
| 01 | `01 00` | `41` | 当前数据（PID）|
| 02 | `02 {PID} {frame}` | `42` | 冻结帧 |
| 03 | `03` | `43` | 已确认故障码 |
| 04 | `04` | `44` | 清除排放相关信息 |
| 07 | `07` | `47` | 待定故障码 |
| 09 | `09 02` | `49` | VIN |
| 0A | `0A` | `4A` | 永久故障码 |

Mode 04 会清除已确认排放 DTC、冻结帧及部分 readiness 信息。UI 二次确认后才能调用；返回超时不能自动重发，应提示重新读取状态。永久 DTC 通常不由 Mode 04 直接清除。

---

## 5. 标准 PID（Mode 01）

**逻辑载荷格式：** 请求 `01 {PID}`，归一化后的响应为 `41 {PID} {A} {B} {C} {D}`；报头、长度、分帧信息已由 `ProtocolParser` 去除。

| PID | 名称 | 数据字节 | 解析公式 | 基础单位 |
|---|---|---:|---|---|
| 00 | 支持的 PID 01–20 | 4 | 位掩码 | — |
| 01 | 监测状态 | 4 | 位掩码（见 5.2）| — |
| 04 | 发动机负荷 | 1 | `A * 100 / 255` | % |
| 05 | 冷却液温度 | 1 | `A - 40` | °C |
| 0A | 燃油压力（表压） | 1 | `A * 3` | kPa |
| 0B | 进气歧管压力 | 1 | `A` | kPa |
| 0C | 转速 | 2 | `(A*256+B)/4` | RPM |
| 0D | 车速 | 1 | `A` | km/h |
| 0F | 进气温度 | 1 | `A - 40` | °C |
| 10 | 空气流量 | 2 | `(A*256+B)/100` | g/s |
| 11 | 节气门位置 | 1 | `A * 100 / 255` | % |
| 1C | OBD 标准 | 1 | 枚举 | — |
| 1F | 发动机启动后运行时间 | 2 | `A*256+B` | s |
| 20 | 支持的 PID 21–40 | 4 | 位掩码 | — |
| 21 | MIL 亮起期间行驶距离 | 2 | `A*256+B` | km |
| 2F | 燃油液位 | 1 | `A * 100 / 255` | % |
| 33 | 大气压 | 1 | `A` | kPa |
| 40 | 支持的 PID 41–60 | 4 | 位掩码 | — |
| 42 | 控制模块电压 | 2 | `(A*256+B)/1000` | V |
| 46 | 环境温度 | 1 | `A - 40` | °C |
| 4D | MIL 亮起后运行时间 | 2 | `A*256+B` | min |
| 5C | 机油温度 | 1 | `A - 40` | °C |
| 60 | 支持的 PID 61–80 | 4 | 位掩码 | — |

单位换算只在展示层进行，持久化和 Domain 值统一使用表中的基础单位。所有公式先校验字节数；超长、过短或超物理范围的数据返回解析错误，不能静默补零。

**V1 权益分组：** Free 基础组为 04/05/0A/0C/0D/0F/11/42；Pro 高级组为本表其余可展示的标准 PID。00/20/40/60 是能力探测、01 是 Readiness，二者不作为“高级数据”单独收费。两组都必须先通过支持位图确认；Pro 不代表车辆一定支持某 PID。

**里程边界：** PID 21 表示 MIL 亮起期间的距离，不是车辆总里程。标准 SAE J1979 首发不提供可靠 odometer；App 不从 PID 推断或承诺自动读取车辆总里程。

### 5.1 支持 PID 探测

按 `00 → 20 → 40 → 60` 顺序查询位掩码：只有上一段位掩码声明下一段支持 PID 可用时才继续。结果保存为 `SupportedPidSet`，每次新连接/新车辆会话重新确认；未声明支持的 PID 不进入实时轮询。

多 ECU 分别保留支持集合。高层可展示并集，但实际读取结果仍保留 `sourceEcu`，避免把两个 ECU 的数值覆盖。

### 5.2 PID 01 监测状态（Readiness）

4 字节位掩码中，第 1 字节 bit7 是 MIL 状态，其余位包含 DTC 数量和不同点火类型下的监测支持/完成状态。`ReadinessStatus` 必须区分“该监测项不支持”与“支持但未完成”，不能只保留一个布尔值。

### 5.3 Typed PID value

PID 定义必须携带值类型、基础单位、字节数和解析函数，不统一降级为 `double?`：

```dart
class PID<T> {
  final int code;
  final PidUnit unit;
  final T Function(List<int> bytes) decode;
}

class PidSample<T> {
  final PID<T> pid;
  final T value;                 // num / bool / enum / bitmask 等
  final String sourceEcu;
  final DateTime sampledAt;
  final List<int> rawData;
}
```

`PidReadResult<T>` 包含一个或多个 ECU 的 `PidSample<T>`、unsupported 状态或 typed error。数值、枚举和 readiness 位掩码不得用同一种 `double?` 表达。

### 5.4 实时采样契约

- `samplePids` 只接受当前会话已确认支持的 PID；默认目标周期 500ms，由适配器 profile 可调。
- ELM327 是串行命令设备：采样器按轮询计划逐条读取，同一时刻最多一个命令在途，不承诺每个 PID 都达到目标周期。
- 每个 sample 带 ECU、实际采样时间和原始数据；`PidBatch` 还带会话 ID，供录制和断线后分段。
- 慢消费者使用有界最新值缓冲，不允许无限堆积；取消订阅后停止安排新命令，让在途命令正常完成。
- 诊断读码、清码、VIN 与实时采样共享同一命令调度器。清码等独占操作开始前暂停采样，结束后重新探测连接状态再恢复。
- 断连时 Stream 发出 typed connection error 并结束当前会话；重连创建新会话，不把重连前后的数据伪装成连续采样。

---

## 6. DTC 解析与多 ECU 聚合

### 6.1 Mode 03/07/0A 响应

保持 `AT H1`，一次请求可能收到多个 ECU 的单帧或多帧响应。处理流程：

1. 按 ECU 分组并完成多帧重组。
2. 分别验证 `43` / `47` / `4A` service。
3. service 后每两个字节解码一个 DTC；`00 00` 和尾部 padding 忽略。
4. 每条 DTC 保存 `sourceEcu` 和 `confirmed/pending/permanent` 状态。
5. 原始结果按 `(sourceEcu, code, status)` 去重；UI 若按 code 合并，仍须保留来源列表。

Mode 03 **没有“每次最多三个、重复发送即可翻页”的分页语义**。超过单帧容量的数据必须从同一次命令的多帧/多 ECU 响应完整聚合；不能重复发送 `03` 并期待下一页。

### 6.2 DTC 两字节解码

```dart
String decodeDtc(int b1, int b2) {
  const firstChar = ['P', 'C', 'B', 'U'];
  String hexNibble(int value) =>
      value.toRadixString(16).toUpperCase();

  final system = firstChar[(b1 >> 6) & 0x03];
  final d1 = (b1 >> 4) & 0x03;
  final d2 = b1 & 0x0F;
  final d3 = (b2 >> 4) & 0x0F;
  final d4 = b2 & 0x0F;
  return '$system$d1${hexNibble(d2)}${hexNibble(d3)}${hexNibble(d4)}';
}
```

测试至少覆盖：`01 33 → P0133`、`04 20 → P0420`，以及含 A–F nibble 的输入，确保不会错误输出十进制 `10`–`15`。

### 6.3 分类与首发覆盖边界

| 首字符 | 系统类别 |
|---|---|
| P | 动力总成 |
| C | 底盘 |
| B | 车身 |
| U | 网络通信 |

首字符只表示代码类别；通用/厂商特定属性还依赖后续位和适用标准，不能仅凭 `P3xxx` 等前缀一概而论。

更重要的是，能解码 C/B/U 字符串不等于标准 OBD 会话能扫描对应模块。首发仅承诺 SAE J1979 排放相关 ECU/DTC，**不承诺 ABS、SRS/安全气囊、转向、车身控制器或任何 OEM 增强诊断**。UI 和 AI 诊断不得暗示已检查这些安全系统；后续能力必须另立 OEM 模块寻址与数据规范。

---

## 7. VIN 读取（Mode 09 PID 02）

```text
AT AL
09 02
```

VIN 可能由一个或多个 ECU 以多行/多帧形式返回。不得使用“固定跳过 4 字节后取 17 字节”的解析：

1. 保持 H1，按 ECU 分组并验证 `49 02`。
2. 根据当前协议解析帧长度/序号，校验连续帧顺序，去除 transport metadata。
3. 按 Mode 09 消息序号拼接数据，去除 padding/NUL。
4. 校验最终 VIN 为 17 个允许的 ASCII 字符；非法长度或字符返回 typed parse error。
5. 多 ECU 返回相同 VIN 时合并来源；返回冲突 VIN 时保留各来源并报告冲突，不能任取第一条。

`VinReadResult` 至少包含 VIN、来源 ECU 集合、原始响应和验证状态。ELM327 负责车辆总线流控；`ProtocolParser` 负责对 ELM 呈现的多帧文本进行校验和载荷重组。

---

## 8. 冻结帧（Mode 02）

Mode 02 请求必须携带 **frame number**：

```text
02 00 {frameNumber}          # 该冻结帧支持的 PID
02 02 {frameNumber}          # 触发该冻结帧的 DTC（若 ECU 支持）
02 {PID} {frameNumber}       # 具体 PID
响应：42 {PID} {frameNumber} {A} {B} ...
```

- `frameNumber` 的首发默认入口可从 0 开始，但必须显式保存在 `FreezeFrame`，不能假设车辆永远只有一个冻结帧。
- 每个 frame 先探测支持 PID，再读取所需字段；解析公式复用 Mode 01 的 typed PID 定义。
- 响应必须同时匹配 PID 和 frame number；不同 ECU 的同号 frame 分开保存。
- 不支持 PID 02 或额外 frame 时返回 unsupported，而不是伪造 DTC 关联。

`FreezeFrameReadResult` 可包含多个 `FreezeFrame`；每项至少带 `sourceEcu`、`frameNumber`、可选触发 DTC、已解析 PID values 和采集时间。调用方与持久化层不能只取第一项覆盖其他 ECU/帧。

---

## 9. 错误模型

| 原始响应/情况 | typed 结果 | 处理 |
|---|---|---|
| `NO DATA` | `UnsupportedResponse` | 对单 PID 标记 unsupported；不自动重试 |
| `CAN ERROR` | `VehicleBusError` | 只读命令最多重试 1 次，保留原始响应 |
| `UNABLE TO CONNECT` | `VehicleConnectionError` | 提示检查点火、适配器与车辆接口 |
| `BUS INIT...ERROR` | `ProtocolDetectionError` | 受控执行 `AT SP 0` 并用长超时重新探测一次 |
| `STOPPED` | `CommandInterrupted` | 不当作无数据；由调度器决定是否重发只读命令 |
| `?` | `ElmCommandError` | 命令/克隆兼容性错误，不盲目重试 |
| 收到 `>` 前宿主超时 | `TransportTimeout` | 按命令类别策略处理；连续失败触发断连 |
| 非十六进制、奇数长度、帧序错误 | `MalformedResponse` | 不进入 PID/DTC 公式，记录脱敏 fixture |
| 多 ECU VIN 冲突 | `ConflictingVehicleIdentity` | 不自动选择 VIN，要求用户确认/手动输入 |

错误对象至少包含命令类别、适配器信息、当前协议、是否可重试和脱敏后的原始响应。VIN 等识别信息写日志前必须遮罩。

---

## 10. 实现顺序与验收

1. typed error、`DTC`、`PID<T>`、`PidSample<T>`、`FreezeFrame` 模型。
2. `decodeDtc()` 与 PID 公式纯函数测试，包括 A–F nibble、字节长度和边界值。
3. `ProtocolParser` 归一化：echo、`>`、CR/LF、S0/S1、H1、状态行。
4. 按 ECU 分组、多帧重组及 Mode 03/07/0A、Mode 09、Mode 02 fixtures。
5. `ELM327Transport`：分片收集、串行队列、分命令超时、安全重试。
6. `MockConnection` 与 `OBDClient`；完成 00/20/40/60 能力探测。
7. 实时 PID 调度、暂停/恢复、背压、会话分段测试。
8. WiFi / BLE / Android SPP 真实连接实现。
9. Android 真机验证 WiFi/BLE/SPP；iOS 真机只验证 WiFi/BLE。

每步先写测试再实现。模拟器必须覆盖：带/不带 echo、S0/S1、H1 多 ECU、TCP/BLE 任意分片、慢复位、自动协议搜索、多帧 VIN/DTC、frame number、断连与 malformed response。标准 OBD 首发验收不得写成 ABS/SRS/OEM 增强诊断或自动读取车辆总里程。

发布门：CAN 11/29 bit、ISO 9141、KWP2000、J1850 PWM/VPW 的版本化 fixture 与模拟器回归必须全部通过；真车验收覆盖能获得的协议/适配器组合，并在发布记录中明确未取得的非 CAN 真车证据。缺少真车样本不能被描述成“已实车验证”，但不会替代或跳过全协议自动化阻断测试。
