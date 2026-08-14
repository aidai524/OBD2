# OBD2 App 开发交接

> 更新时间：2026-08-14（Asia/Shanghai）
>
> 工作目录：`/Users/joe/obd2-project`
>
> 分支：`main`
>
> 当前代码基线：`654ffb1 T-00-04: 建立主题、本地化与单位框架`

## 1. 当前结论

项目已完成 T-00-01～T-00-04，当前只有阶段 0 的工程与展示基线：Flutter 双平台工程、锁定依赖、三环境配置、Riverpod/go_router 5 Tab 壳、可恢复启动/未知路由、固定深色主题、en-US 和展示层单位转换。

以下内容尚未实现：真实 OBD 协议与连接、ELM327 模拟器、业务页面、Drift 数据库、Supabase 初始化/Auth/同步、RevenueCat、通知、PDF 报告和 AI 诊断。依赖已经锁定不代表这些能力已经接通。

M0 仍未完成：CI、ELM327 fixtures 和协议纯函数均待开发。不要勾选 `PROJECT_PLAN.md` 的 M0 完成项。

## 2. 先读这些文档

按以下顺序建立上下文：

1. [`README.md`](README.md)：当前产品基线与已拍板决策。
2. [`PROJECT_PLAN.md`](PROJECT_PLAN.md)：版本和里程碑。
3. [`docs/08-TASKS.md`](docs/08-TASKS.md)：任务依赖、验收和提交规则。
4. 当前任务关联的权威规格；协议工作优先读 [`docs/06-OBD-PROTOCOL.md`](docs/06-OBD-PROTOCOL.md)。
5. 客户端现状与环境命令见 [`app/README.md`](app/README.md)。

文档冲突时暂停实现，先更新权威文档并确认；不要在代码里隐藏选择一套假设。

## 3. 已完成提交

| 任务 | 提交 | 内容 |
|---|---|---|
| T-00-01 | `14e018d` | Git、Flutter iOS/Android 脚手架与目录骨架 |
| T-00-02 | `00109f1` | 锁定依赖、dev/staging/prod 配置、sqlite3mc hook |
| T-00-03 | `ac61fa5` | Riverpod、go_router、启动恢复和 5 Tab 壳 |
| 维护 | `8268432` | 忽略本地 `.archive/` 记录 |
| T-00-04 | `654ffb1` | 深色主题、en-US、英/公制展示框架及测试 |

当前没有配置 Git remote，也没有推送或部署记录。

## 4. 当前代码地图

### 启动和配置

- [`app/lib/main.dart`](app/lib/main.dart) 只初始化 Flutter binding 并挂载 `AppStartup`。
- [`app/lib/app/app_startup.dart`](app/lib/app/app_startup.dart) 负责同步/异步配置加载、loading、失败重试和旧 Future 竞态保护。
- 配置成功后才创建 `ProviderScope`，并覆盖 [`appConfigProvider`](app/lib/core/config/app_config_provider.dart)。
- [`app/lib/core/config/app_config.dart`](app/lib/core/config/app_config.dart) 只接受编译期：
  - `APP_ENV=dev|staging|prod`
  - `SUPABASE_URL`
  - `SUPABASE_PUBLISHABLE_KEY`
- staging/prod 必须使用 HTTPS；缺失、非法或仍为示例占位值时会安全失败。

`--dart-define` 会进入客户端二进制，不是秘密存储。Flutter 端只能放公开 URL 和 publishable/anon key；严禁放 service-role、LLM、RevenueCat REST/webhook、签名或数据库凭据。

交接时没有本地 `.env.dev`、`.env.staging` 或 `.env.prod`。真实运行前按 `app/README.md` 从 `.env.example` 创建并替换占位值；这些文件必须保持忽略。

### 路由和应用壳

- [`app/lib/app/app_router.dart`](app/lib/app/app_router.dart) 使用 Riverpod 管理 `GoRouter` 生命周期。
- `/` 重定向到 `/garage`。
- 5 个分支使用 `StatefulShellRoute.indexedStack`，顺序固定为：Garage、Diagnostics、Live Data、History、Settings。
- [`AppTab`](app/lib/app/app_shell.dart) 的枚举顺序就是 NavigationBar 和 Router branch index，不要单独重排。
- 未知路由只展示安全的本地化错误；不得输出原始异常、URI、query 或配置值。
- 5 个 Tab 当前仍是占位页，业务实现必须进入各自 feature 分层和路由，不要堆进 `AppShell`。

### 主题、无障碍和本地化

- V1 固定 Material 3 深色，不提供浅色或跟随系统选择器。
- 颜色与 Token 位于 [`app/lib/core/theme/`](app/lib/core/theme/)：
  - Primary `#0A84FF`
  - Danger `#E53935`
  - Warning `#FBC02D`
  - Normal `#43A047`
  - Background `#05070A`
  - Card 圆角 12，最小触控尺寸 48，大按钮高度 52
- 主应用和启动错误使用两套 `MaterialApp`，修改主题或 i18n 时必须同步两处。
- Android/iOS 原生启动背景也固定为 `#05070A`；若修改背景 Token，必须同步原生资源。
- V1 运行时只暴露 `Locale('en', 'US')`。
- 编辑 [`app/lib/core/i18n/app_en.arb`](app/lib/core/i18n/app_en.arb) 后运行 `fvm flutter gen-l10n`；不要手改生成的 `app_localizations*.dart`。
- 后续新增用户可见文案必须进入 ARB。
- `AppTypography.instrumentValue` 仅提供 tabular figures，业务数字 Widget 仍需显式应用该样式。
- 严重程度不能只靠红黄绿；后续组件必须同时给出文字、语义和行动说明。

### 单位边界

- [`UnitSystem`](app/lib/core/units/unit_system.dart) 的 wire 值只有 `imperial` 和 `metric`。
- [`unitSystemProvider`](app/lib/core/units/unit_system_provider.dart) 默认英制，目前只存在内存中；新 ProviderContainer/应用重启会恢复英制。
- Settings 控件、profile 同步和持久化属于后续任务，不要提前实现。
- [`MeasurementFormatter`](app/lib/core/units/measurement_formatter.dart) 只负责展示，不得把转换后或格式化后的值写回 Domain/数据库。
- Canonical 单位必须保持：
  - PID 温度：°C
  - PID 速度：km/h
  - 压力：kPa
  - PID 距离：km
  - 数据库车辆/诊断/保养里程：integer miles
- `pidDistanceFromKilometers()` 与 `storedMileageFromMiles(int)` 不可混用。
- 车辆安全规则、阈值和诊断必须使用未舍入 canonical 值，不能使用显示字符串。

### 当前空实现

- [`app/lib/obd/obd_client.dart`](app/lib/obd/obd_client.dart) 仍是空 facade。
- `features/`、`obd/` 下大多数目录只有 `.gitkeep`。
- BLE、WiFi/SPP、Drift、Supabase、RevenueCat、PDF 和通知包虽已锁定，但没有运行时初始化。

## 5. 依赖与架构约束

- 始终使用 `fvm flutter`；不要调用全局 Flutter。
- 当前锁定 Flutter 3.47.0 / Dart 3.13.0；FVM 4.0.5。
- PATH 中裸 `flutter`/`dart` 指向另一套 `/Users/joe/dev/flutter`，不是项目 SDK。
- Flutter 会把固定 tag 报告为 channel `[user-branch]`，这是当前 SDK pin 的 doctor 警告，不要擅自换 SDK。
- codegen 组合刻意锁定：`freezed 3.2.5`、`drift_dev 2.34.0`、`build_runner 2.15.1`、`json_serializable 6.14.1`。不要单独升级或添加 analyzer override。
- `flutter_secure_storage 10.3.1` 是 compileSdk 36 兼容 pin；11.x 需要更高 compileSdk，升级必须单独验证迁移和真机。
- sqlite3 hook 指向 `sqlite3mc`；APK 已能打包原生库，但“已打包”不等于数据库已经加密。运行时加密、错误密钥拒开和磁盘 header 测试属于 T-04-01。
- Supabase 后续必须为 session 和 PKCE 使用 `flutter_secure_storage` 自定义存储，不可接受默认 SharedPreferences。
- Android SPP 使用自有 platform channel + 官方 `BluetoothSocket`/RFCOMM；不要加入第三方 SPP Flutter 包。
- 不要提前加入 `fl_chart`，V1.1 才需要。
- Domain 层不得依赖 Flutter 插件、Drift、Supabase、RevenueCat 或 `lib/obd/`。
- `pub get` 会提示 22 个包存在不兼容当前约束的更新，这是 intentional pins 的信息提示，不是失败。

## 6. 当前验证基线

在 `2026-08-14`，以下验证通过：

- `fvm flutter gen-l10n`
- 格式检查：30 个文件，0 变更
- `fvm flutter analyze --no-pub`：0 issue
- 默认测试：45/45
- dev、staging、prod 编译期环境测试：各 47/47
- Android debug APK：构建成功
- Android/iOS XML 与 Info.plist：语法检查通过
- 密钥扫描和 `git diff --check`：通过

APK 位于 `app/build/app/outputs/flutter-apk/app-debug.apk`，属于构建产物，不提交。当前快照是约 208 MB 的 universal debug APK：

- SHA-256：`603d37ae36acd55061da772be3701127ccb6adccc170fe06cee6e32a28dbc906`
- application ID：`com.example.obd2app`
- minSdk 26、targetSdk 36、debug signing
- 包含 arm64-v8a、armeabi-v7a、x86_64 三个 ABI 的 `libsqlite3mc.so`

这些证据只说明 debug 打包成功，不代表生产配置、数据库运行时加密、release signing 或商店产物已验证。

### 基础验证命令

```sh
cd /Users/joe/obd2-project/app

fvm flutter gen-l10n
fvm dart format --output=none --set-exit-if-changed lib test
fvm flutter analyze --no-pub
fvm flutter test --no-pub
```

三环境入口可用以下非敏感测试值复现：

```sh
fvm flutter test --no-pub \
  --dart-define-from-file=config/dev.json \
  --dart-define=SUPABASE_URL=http://127.0.0.1:54321 \
  --dart-define=SUPABASE_PUBLISHABLE_KEY=public-test-dev

fvm flutter test --no-pub \
  --dart-define-from-file=config/staging.json \
  --dart-define=SUPABASE_URL=https://staging.example.invalid \
  --dart-define=SUPABASE_PUBLISHABLE_KEY=public-test-staging

fvm flutter test --no-pub \
  --dart-define-from-file=config/prod.json \
  --dart-define=SUPABASE_URL=https://prod.example.invalid \
  --dart-define=SUPABASE_PUBLISHABLE_KEY=public-test-prod
```

Android 构建：

```sh
fvm flutter build apk --debug --no-pub \
  --dart-define-from-file=config/dev.json \
  --dart-define=SUPABASE_URL=http://127.0.0.1:54321 \
  --dart-define=SUPABASE_PUBLISHABLE_KEY=public-build-dev
```

## 7. 当前环境与未验证项

- 项目 compile/target SDK 36、minSdk 26、JDK 17，可以完成 debug APK 构建。
- 当前 Android 构建链为 AGP 9.1.0、Kotlin 2.4.0、Gradle 9.3.1；`sdkmanager` 仍有 SDK XML version 提示，但 Flutter doctor 的 Android toolchain 为 green。
- 当前没有 Android AVD/设备；`adb devices` 为空。
- Xcode 16.4 / iOS SDK 18.5 已安装，但 `xcrun simctl list runtimes` 为空，没有 iOS Simulator runtime。
- 两台 iPhone 当前均显示 offline/未满足 Developer Mode 连接条件。
- `flutter devices` 只能看到 macOS 和 Chrome；V1 不包含这两个平台，不能拿它们代替移动端验收。
- CocoaPods 1.16.2 在当前 `LC_ALL=C` 下会警告；执行 Pod/iOS 命令时使用：

```sh
LANG=en_US.UTF-8 LC_ALL=en_US.UTF-8 pod install
```

- iOS 无签名构建/真机/模拟器运行未通过环境终验；不能表述为 iOS 原生构建已验证。
- 没有 AAB、IPA、release signing、Play Console、TestFlight 或 App Store 验证。
- Android/iOS 冷启动无白闪目前是资源和配置静态确认，尚未在移动设备上观察。
- `purchases_flutter` 构建时仍有未来 Built-in Kotlin 兼容警告；当前不阻塞，但升级任务必须跟踪。
- 真车 OBD、第三方服务、购买沙盒、云同步和 AI 调用均未验证。

## 8. 下一步任务

### 第一优先：T-00-05

任务：lint、单测、覆盖率与 CI 基线。它是 T-01-01 的前置条件。

当前 `.github/workflows/` 不存在，`app/analysis_options.yaml` 只有基础 lint。建议建立一个本地与 CI 共用的单一验证入口，再由 GitHub Actions 调用；不要把“建议入口”误写成现有能力。

T-00-05 范围内不要加入协议实现、模拟器、业务页或依赖升级。完成后提交：

```sh
git commit -m "T-00-05: 建立统一验证与 CI 基线"
```

### 第二优先：T-00-06

任务：确定 ELM327 模拟器并建立版本化 fixtures。目标目录为 `tools/elm327-simulator/`。

必须记录来源、许可证、固定版本和可重复启动方式；fixtures 至少覆盖 echo、S0/S1、H1、多 ECU、多帧、分片、慢复位、断线和 malformed response。

T-00-06 不得顺带实现 Parser、Transport 或真实 BLE/WiFi/SPP。它与 T-00-05 可独立推进，但必须保持单独提交：

```sh
git commit -m "T-00-06: 确定 ELM327 模拟器并建立响应 fixtures"
```

### 阶段 0 之后

严格按 TDD 推进：T-01-01 → T-01-02 → T-01-03 → T-01-04。T-01-05 可在阶段 0 验收完成后并行处理数据来源与许可证。

不要因为某个后续任务的直接依赖看似已满足就绕过阶段验收门。

## 9. 提交和安全规则

每个 backlog 任务至少一个范围清晰的提交；不同任务不要混在同一个提交中。提交前执行：

```sh
git status --short
git diff --stat
git diff --check
git diff --cached --name-status
git diff --cached --check
```

显式暂存任务文件，避免无审计地执行 `git add .`。自动化通过、真机、第三方账号、购买沙盒和商店审核必须分别报告。

严禁提交真实 `.env`、API key、token、私钥、签名文件或敏感日志。

## 10. Git 交接状态

创建本文件前，已跟踪工作树是干净的，HEAD 为 `654ffb1`。`HANDOFF.md` 是本次新增文件，除非用户明确要求，否则不要把它与下一个 backlog 任务混在同一提交中。

同一工作区内还有被 Git 忽略的 `.archive/MEMORY.md`，其中记录了 T-00-04 的本地决策和验证细节；它不会被提交或推送。
