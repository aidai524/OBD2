# 02 · 技术架构设计

> 文档版本：v1.1 · 产品范围：V1 = P0 · 读者：Codex（开发实现依据）
> 原则：双平台一套代码、模块解耦、离线优先、模拟器优先

---

## 1. 技术栈（锁定项）

| 层 | 选型 | 版本/说明 |
|---|---|---|
| 客户端框架 | Flutter | T-00-01 选择当前 stable，并在仓库记录精确 SDK 版本 |
| 语言 | Dart | 使用所选 Flutter stable 自带的兼容版本 |
| 状态管理 | Riverpod | 当前稳定版，负责依赖注入与应用状态 |
| 路由 | go_router | 声明式路由 |
| BLE 连接 | flutter_blue_plus | iOS / Android BLE |
| 蓝牙经典 | platform channel + Android `BluetoothSocket` / RFCOMM | **仅 Android**；T-00-02 锁定为自有平台通道，不引入第三方 SPP Flutter 包；iOS 不支持通用 SPP，不展示该入口 |
| WiFi 连接 | `dart:io` Socket（TCP）| ELM327 WiFi 版，端口由连接配置提供（常见默认值 35000）|
| 支付 | RevenueCat Flutter SDK | `purchases_flutter` |
| 后端平台 | Supabase | Auth、Postgres、Storage、Flutter SDK |
| 后端逻辑 | **Supabase Edge Functions（Deno / TypeScript）** | AI 诊断、订阅复核、VIN 服务；不另设 Node/Python 业务后端 |
| AI | OpenAI / Anthropic LLM API | 仅由 Edge Function 调用，密钥不下发客户端 |
| 本地数据库 | **Drift / SQLite** | 锁定为唯一客户端结构化数据库；支持关系、事务、迁移、离线查询与同步队列 |
| 埋点 | 自研事件接口 + PostHog 或 Mixpanel | 供应商通过适配器接入，业务层不直接依赖 SDK |
| 图表 | fl_chart | V1.1 图表模式需要时再引入，V1 不预装未使用依赖 |

---

## 2. 项目结构

采用“业务功能内分层 + 基础设施模块独立”的目录。每个 `features/<feature>/` 可按需要包含 `presentation / application / domain / data` 四层；不得把 Supabase、Drift、RevenueCat 或 OBD 具体实现放进 Domain。

```
app/
├── lib/
│   ├── main.dart
│   ├── app/                         # 应用壳：路由、主题、顶层 Provider
│   ├── core/
│   │   ├── config/                  # 非秘密客户端配置、环境标识
│   │   ├── errors/                  # 统一错误类型
│   │   ├── i18n/                    # 本地化
│   │   ├── theme/                   # 浅色/深色主题
│   │   └── analytics/               # 埋点抽象及适配器
│   ├── features/
│   │   ├── connection/              # F-A；按四层组织
│   │   ├── diagnostics/             # F-B；Domain 定义 OBD 仓库接口
│   │   ├── ai_diagnosis/            # F-C；Edge Function 客户端适配器在 data/
│   │   ├── garage/                  # F-D
│   │   ├── account/                 # F-E
│   │   ├── subscription/            # F-F
│   │   ├── report/                  # F-G
│   │   ├── community/               # F-H，P2
│   │   ├── store/                   # F-I
│   │   └── settings/                # F-J
│   └── obd/                         # OBD 基础设施实现，见 06-OBD-PROTOCOL
│       ├── obd_client.dart           # 面向仓库实现的高层门面
│       ├── connection/               # WiFi / BLE / Android SPP / Mock
│       ├── elm327/                   # ELM327 命令、提示符、超时、串行队列
│       ├── protocol/                 # ProtocolParser：响应归一化 + SAE J1979
│       ├── pid/                      # typed PID 定义、公式、采样模型
│       └── dtc/                      # DTC 模型与解析
├── test/                             # 单元、Widget、集成测试
└── pubspec.yaml

supabase/                             # 唯一服务端代码根目录
├── config.toml
├── functions/                       # Deno / TypeScript Edge Functions
│   ├── _shared/                     # 鉴权、Schema、CORS、外部 API 客户端
│   ├── ai-diagnose/index.ts
│   ├── account-export/index.ts
│   ├── account/index.ts             # DELETE /account
│   ├── revenuecat-webhook/index.ts
│   ├── verify-subscription/index.ts
│   └── vehicle-decode/index.ts
├── migrations/                      # Postgres schema / RLS 迁移
└── seed.sql                         # 仅本地开发种子数据

tools/
└── elm327-simulator/                # ELM327 文本响应模拟器与 fixtures
```

目录约束：

- Flutter 客户端只通过 Supabase Flutter SDK / HTTPS 调用 Edge Functions，不直接调用 LLM、维修费用或 RevenueCat REST API。
- Edge Function 代码统一为 TypeScript，并运行在 Supabase 的 Deno Runtime；共享逻辑放 `supabase/functions/_shared/`。
- Drift table、DAO 与映射器放对应功能的 `data/` 层；数据库初始化和 migration 放共享基础设施目录；Domain 只看实体和仓库接口。
- `lib/obd/` 是本地基础设施，不是第二套 Domain。`features/diagnostics/data/` 通过适配器把它实现为 Domain 仓库。

---

## 3. 分层架构与依赖方向

```
Presentation（Flutter Widgets）
          ↓
Application（Riverpod Notifier / 用例编排）
          ↓
Domain（实体、值对象、Repository 接口）
          ↑
Data / Infrastructure（Repository 实现）
   ├─ Drift / SQLite（本地）
   ├─ Supabase Flutter（云）
   ├─ RevenueCat SDK（支付）
   └─ OBDClient（ELM327）

Supabase Edge Functions（Deno / TypeScript）
   ├─ Supabase Auth + Postgres / RLS
   ├─ RevenueCat REST 二次校验
   └─ LLM / VIN / 维修数据供应商
```

**依赖规则：** Presentation → Application → Domain；Data/Infrastructure 实现 Domain 接口。Domain 不导入 Flutter 插件、Drift、Supabase、RevenueCat 或 `lib/obd/`，因此可注入内存仓库和 `MockConnection` 测试。

---

## 4. 关键设计决策

### 4.1 连接层只负责连接 ELM327

`OBDConnection` 是 App 与 ELM327 适配器之间的字节通道，不解释车载 CAN / ISO / J1850 报文，也不承担业务命令重试。

```dart
abstract interface class OBDConnection {
  Future<void> connect(ConnectionConfig config);
  Future<void> disconnect();
  Future<void> write(List<int> bytes);
  Stream<List<int>> get incomingBytes;
  ConnectionStatus get status;
}

enum ConnectionType { wifi, ble, bluetoothClassic }
```

实现与平台矩阵：

| 实现 | Android | iOS | 说明 |
|---|---:|---:|---|
| `WifiConnection` | ✅ | ✅ | TCP；需处理本地网络权限和网络切换 |
| `BleConnection` | ✅ | ✅ | GATT；负责 BLE 分包/合包，不解释 ELM 文本 |
| `SppConnection` | ✅ | ❌ | Android 蓝牙经典；iOS 不创建实现、不展示选项 |
| `MockConnection` | ✅ | ✅ | 测试 fixture，不需要真车 |

同一连接同一时刻只允许一个 ELM 命令在途；命令队列、收到 `>` 后结束响应、超时与安全重试由 `ELM327Transport` 负责。

### 4.2 OBD 协议边界（见 06-OBD-PROTOCOL.md）

```
OBDClient（读 DTC / PID / VIN / 冻结帧、实时采样）
├── ProtocolParser
│   ├─ 归一化 ELM 文本（echo / 空格 / CRLF / > / 状态行）
│   ├─ 按 ECU 聚合并重组多帧响应
│   └─ SAE J1979 service、PID、DTC、VIN 解析
└── ELM327Transport（AT 命令、串行队列、分命令超时/重试）
     └── OBDConnection（WiFi / BLE / Android SPP）
          └── ELM327 适配器
               └── 车辆 CAN / ISO 9141 / KWP / J1850
```

**边界说明：** ELM327 负责车载链路的协议选择、总线访问、物理/链路层时序与流控。App 不自行实现 CAN、ISO 9141、KWP 或 J1850 的物理/链路层编解码；`ProtocolParser` 只处理 ELM 返回的文本帧/载荷、ECU 来源、多帧重组和 SAE J1979 应用层语义。

首发范围是标准 SAE J1979 排放相关诊断。**不承诺** ABS、SRS/安全气囊、转向、车身模块或厂商增强 DTC/PID；这些能力需要后续单独的 OEM 协议、寻址、数据授权和真车验证。

标准 SAE J1979 也没有可依赖的“车辆总里程”PID。PID 21 等距离字段不是 odometer；车库里程由用户录入或经独立、明确标注的数据源更新。

### 4.3 本地数据锁定 Drift / SQLite

- 车辆、保养、诊断历史、AI 结果缓存和同步队列统一保存到 Drift 管理的 SQLite 数据库。
- Repository 负责 Domain 实体与 Drift table/DAO 的映射，UI 不直接执行 SQL 或查询 DAO。
- 一次诊断会话及其 DTC/冻结帧必须在同一事务写入；同步 upsert、tombstone 和 schema migration 规则见 03-DATA-MODEL。
- 原生端数据库使用 Drift `NativeDatabase` + SQLite3MultipleCiphers 加密；`sqlite3` build hook 固定 `source: sqlite3mc`，启动时以 `PRAGMA cipher` 验证加密实现存在后再设置 key，验证失败必须拒绝打开而不是退回明文 SQLite。随机数据库密钥保存在 iOS Keychain / Android Keystore，不写入源码、普通 preferences、日志或云备份。
- 登录后由同步用例增量写入 Supabase；冲突策略和服务端 RLS 以 03-DATA-MODEL 为准。
- 不并行引入 Isar 或第二套结构化数据库，避免维护两套迁移、事务和查询语义。

### 4.4 服务端统一为 Supabase Edge Functions

- 所有业务端点位于 `supabase/functions/`，统一 Deno / TypeScript、错误格式、鉴权和输入/输出 Schema。
- LLM、维修数据、RevenueCat secret 只存 Supabase Secrets；不得出现在 Flutter `.env`、源码或日志中。
- 客户端只保存可公开的 Supabase URL、anon/publishable key 和环境标识。
- `ai-diagnose` 必须校验 Supabase JWT，并在服务端二次复核 RevenueCat entitlement（见 07-AI-DIAGNOSIS.md）。

### 4.5 订阅校验（防破解）

- 客户端 RevenueCat SDK 用于展示购买状态与发起购买。
- Pro 服务端能力以 Edge Function 的 entitlement 复核为准，不能只信客户端布尔值。
- 免费的本地 OBD 读取和离线通用码解释不依赖服务端。

匿名 Auth 仍会产生真实 `auth.users` 行和可消费的 AI 免费权益；生产环境必须启用 Supabase 支持的 CAPTCHA、防滥用速率限制与告警。Edge 限流同时按已验证用户和短期加盐 IP 摘要执行，日志/分析不保存原始 IP。

### 4.6 离线优先

- V1 的离线保证从“至少成功创建/恢复一次 Supabase 匿名或正式会话”后开始；首次安装需要网络完成身份与加密库初始化，UI 必须明确说明并可重试。
- 无网络时，车辆档案、历史和标准 OBD 诊断继续使用 Drift 与本地 DTC 表。
- AI 诊断、订阅复核、云同步与在线 VIN/维修数据需要网络，并提供明确降级状态。
- 同步失败不得阻断本地诊断；重试任务必须幂等。

---

## 5. 环境与密钥配置

| 环境 | 用途 | 配置方式 |
|---|---|---|
| `dev` | 本地 Flutter + ELM 模拟器 + Supabase local | 客户端公开配置 + 本地 Supabase |
| `staging` | TestFlight / Android 内测 | 独立 Supabase 项目与测试 RevenueCat entitlement |
| `prod` | 正式上架 | 独立 Supabase 项目、正式 entitlement 与受限 secrets |

Flutter 使用 `config/dev.json`、`config/staging.json`、`config/prod.json` 锁定
`APP_ENV`，并通过第二个、被 Git 忽略的 `.env.<environment>` 文件注入
`SUPABASE_URL` 与 `SUPABASE_PUBLISHABLE_KEY`。两者统一由
`--dart-define-from-file` 在编译期注入；运行时不读取可变 dotenv 文件。缺失或非法
环境、缺失公开配置、非 HTTPS 的 staging/prod URL 必须在启动时明确失败，不得静默
回退为 dev 或 prod。

客户端配置文件不进敏感密钥；CI 只注入构建所需的公开环境值。服务端秘密通过 Supabase Secrets 管理，并按环境隔离。

Supabase access/refresh session 必须通过 Keychain/Keystore 支持的安全存储适配器持久化；不得把 refresh token 落入普通 preferences、日志或分析。登出/账号删除时清理会话与对应本地加密缓存，但在删除尚未同步数据前必须向用户说明并二次确认。

---

## 6. 依赖清单（pubspec 关键项）

| 类别 | 包 |
|---|---|
| 应用状态/路由 | `flutter_riverpod`、`go_router` |
| 连接 | `flutter_blue_plus`；Android SPP 使用自有 platform channel 调用官方 `BluetoothSocket` / RFCOMM API，不引入第三方 SPP Flutter 包 |
| 支付/云 | `purchases_flutter`、`supabase_flutter` |
| 本地数据库 | `drift`、`drift_flutter`、`sqlite3`、`path`、`path_provider`、`flutter_secure_storage`；pubspec hook 配置 `sqlite3.source=sqlite3mc` |
| UI/报告/本地化 | V1：`pdf`、`printing`、`share_plus`、`intl`、`flutter_local_notifications`、`timezone`；V1.1 图表任务再引入 `fl_chart` |
| Model 生成 | `freezed_annotation`、`json_annotation` |
| 标识/值对象 | `uuid`（离线 UUIDv7 与 `Idempotency-Key`）；服务端 cache/request hash 使用 Deno Web Crypto |
| 开发依赖 | `drift_dev`、`freezed`、`json_serializable`、`build_runner`、`flutter_lints`、`mocktail` |

不在设计文档里写 `^2.x` 一类不可直接执行、且容易过期的占位约束。T-00-02 使用官方包源选择与当时 Flutter stable 兼容的稳定版本，运行完整测试后提交 `pubspec.yaml` 与 `pubspec.lock`；升级走独立任务。不得为同一职责同时引入 Drift 与 Isar。

---

## 7. 测试策略

| 层 | 方式 |
|---|---|
| `ProtocolParser` | 纯单测：echo/提示符/空格/报头、多 ECU、多帧、异常字节、SAE J1979 fixtures |
| `ELM327Transport` | `MockConnection`：分片响应、分命令超时、串行化、重试/断连 |
| Drift Repository | 临时 SQLite 测试：DAO、事务、迁移、离线写入、同步队列及加密库恢复 |
| Application / Domain | Riverpod/用例单测，注入 mock 仓库 |
| UI | Widget 测试关键流程和平台能力开关 |
| Edge Functions | Deno 单测：Schema、JWT、RLS、订阅复核、供应商失败降级 |
| 集成 | ELM 模拟器端到端：连接 → 读码/PID → 本地保存 → AI 解读 |
| 真机 | Android：WiFi/BLE/SPP；iOS：WiFi/BLE；覆盖多种 ELM327 与车辆协议 |

协议层和 AI 层目标行覆盖率 ≥ 80%，但多 ECU、多帧、清码确认、鉴权和安全降级等关键分支必须 100% 有场景测试；覆盖率不能替代真车验证。
