# AutoPilot AI — OBD2 AI 汽车诊断 App

> 面向美国 DIY 车主的 AI 汽车诊断应用（iOS + Android）
> 开发方式：自研，使用 Codex（GPT-5.6）辅助编码
> 产品策略：以完整产品蓝图为目标，按 V1 / V1.1 / V2 分版本交付
> 当前状态：产品与技术文档已完成；T-00-01 脚手架已提交，T-00-02 依赖与三环境配置已建立；移动端 `flutter run` 待可用设备环境终验

---

## 文档体系

所有开发文档位于 `docs/` 目录，按编号顺序阅读。**每份文档都是 Codex 的开发依据，需完整、精确、无歧义。**

| # | 文档 | 内容 | 状态 |
|---|---|---|---|
| — | [PROJECT_PLAN.md](./PROJECT_PLAN.md) | 立项计划书（市场/产品/里程碑）| ✅ 完成 |
| 01 | [docs/01-PRD.md](./docs/01-PRD.md) | 产品需求文档（完整功能规格）| ✅ 完成 |
| 02 | [docs/02-TECH-ARCH.md](./docs/02-TECH-ARCH.md) | 技术架构设计（技术栈/模块/依赖）| ✅ 完成 |
| 03 | [docs/03-DATA-MODEL.md](./docs/03-DATA-MODEL.md) | 数据模型（表结构/字段/关系）| ✅ 完成 |
| 04 | [docs/04-API-SPEC.md](./docs/04-API-SPEC.md) | 后端 API 规范（端点/请求/响应）| ✅ 完成 |
| 05 | [docs/05-UI-SPEC.md](./docs/05-UI-SPEC.md) | UI/UX 规格（页面清单/组件/交互）| ✅ 完成 |
| 06 | [docs/06-OBD-PROTOCOL.md](./docs/06-OBD-PROTOCOL.md) | OBD2 协议实现规范（AT 命令/PID/多协议）| ✅ 完成 |
| 07 | [docs/07-AI-DIAGNOSIS.md](./docs/07-AI-DIAGNOSIS.md) | AI 诊断层设计（提示词/数据源/输出结构）| ✅ 完成 |
| 08 | [docs/08-TASKS.md](./docs/08-TASKS.md) | 开发任务分解（Codex 可执行的 backlog）| ✅ 完成 |

> “完成”仅表示文档基线已经形成，不表示对应功能已实现。Flutter 客户端目前只有阶段 0 工程与配置基线；后端 API 和调试工具仍未实现。

---

## 关键决策（已拍板）

1. **开发人力**：自研，Codex（GPT-5.6）辅助编码，文档先行
2. **平台**：双平台（iOS + Android），Flutter 一套代码
3. **交付方式**：完整产品蓝图分版本交付；V1 = P0、V1.1 = P1、V2 = P2
4. **调试**：ELM327 模拟器 → 国内真车 → 美国 TestFlight；国内车可覆盖标准协议开发，美国车型/排放场景仍需当地终验
5. **AI 权益**：每位用户可免费完成 1 次完整 AI 诊断；用完后需订阅 Pro
6. **单次解锁**：`$2.99/次` 属 V1.1（P1），不阻塞 V1 上架
7. **V1 维修费**：由 AI 生成美国市场估算区间，必须明确标注 `source: "estimate"`，不得表述为精确报价
8. **专业维修数据**：RepairPal / Motor 等数据供应商接入后再替换或增强 AI 估算

如其他文档与以上决策冲突，以本节为当前产品基线；AI 请求/响应字段以 `docs/07-AI-DIAGNOSIS.md` 的最终契约为准。

## 版本与权益基线

| 版本 | 范围 | 交付原则 |
|---|---|---|
| **V1** | 所有 P0 | 形成可测试、可审核、可双平台上架的首发版本 |
| **V1.1** | 所有 P1 | 上架后的体验和商业化增强，含 `$2.99` 单次 AI 解锁 |
| **V2** | 所有 P2 | 社区、推荐奖励等长期生态能力 |

| 用户层级 | AI 诊断权益 |
|---|---|
| **Free** | 生命周期内 1 次完整 AI 诊断，结果字段与 Pro 相同 |
| **Pro** | 免费次数用完后继续使用 AI 诊断；受服务端额度与合理使用策略约束 |
| **OneTime（V1.1）** | 非订阅用户 `$2.99` 解锁 1 次完整 AI 诊断 |

## 待定决策

- [ ] 品牌名（AutoPilot AI 为占位名）
- [ ] 专业维修费用数据供应商（RepairPal / Motor / 其他；V1 暂不依赖）
- [ ] 公司主体（收款 + 税务）

---

## 技术栈（约定）

| 模块 | 选型 |
|---|---|
| 客户端 | Flutter（iOS + Android）|
| 连接 | flutter_blue_plus（BLE）+ platform channel（蓝牙经典 SPP）+ TCP Socket（WiFi）|
| 支付 | RevenueCat |
| 后端 | Supabase（账号/云同步）+ Edge Functions（Deno/TypeScript）|
| AI | LLM API + 经许可、可再分发的通用 DTC 目录 |

## 目录结构（约定）

```
obd2-project/
├── README.md              # 本文件
├── PROJECT_PLAN.md        # 立项计划
├── docs/                  # 开发文档（Codex 依据）
├── app/                   # Flutter 客户端（T-00-01 脚手架已创建）
├── supabase/              # Edge Functions、迁移、RLS 与本地 Supabase 配置（目录已预留）
└── tools/                 # ELM327 模拟器等调试工具（目录已预留）
```
