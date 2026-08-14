# 04 · 后端 API 规范

> 文档版本：v1.1 · 产品范围：V1 = P0 · 读者：Codex（实现 `supabase/functions/`）
> 载体：Supabase Edge Functions（Deno/TypeScript）
> 认证：Supabase Auth JWT（`Authorization: Bearer`；游客使用 Anonymous Auth JWT）

---

## 1. 端点总览

| 方法 | 路径 | 功能 | 认证 | 关联功能 |
|---|---|---|---|---|
| POST | /ai-diagnose | 单个 DTC 的完整 AI 故障诊断 | JWT + 原子额度校验 | F-C |
| POST | /vehicle-decode | VIN 解码 | JWT | F-B-08 |
| POST | /verify-subscription | 刷新并返回订阅/额度状态 | JWT | F-F |
| POST | /revenuecat-webhook | RevenueCat 事件收件并刷新当前权益 | 配置的 Authorization secret（内部） | F-F |
| GET | /account-export | 导出当前账号全部自有数据 | JWT + 限流 | F-E-03 |
| DELETE | /account | 确认并排队删除账号 | JWT + 确认 + 幂等键（正式账号另需近期重登） | F-E-03 |

> 普通读写可使用 `supabase_flutter` + RLS；涉及付费边界或批量同步的写入必须走 03 定义的数据库 RPC：`create_vehicle`、`sync_diagnostic_batch`、`upsert_maintenance_record`、`upsert_maintenance_schedule`。客户端不能直接写 AI 结果、entitlement 或 usage 表。

V1 只识别 Free 与 RevenueCat `pro` 订阅。OneTime 属于 **V1.1**，不得在 V1 接口中返回或放行尚未实现的 OneTime 权益。

---

## 2. 通用规范

- 请求/响应均为 `application/json`
- 除 `/vehicle-decode` 与 RevenueCat 控制的 `/revenuecat-webhook` 外，所有会产生副作用的 POST 都要求 `Idempotency-Key: <UUID>`；同一用户、同一 key、同一规范化请求重试返回首次结果，不重复扣额度或写记录；同 key 携带不同请求体返回 409 `CONFLICT`。Webhook 改用 RevenueCat `event.id` 做幂等键
- 客户端不得上传 `user_id`；服务端用户 ID 只能来自已验证 JWT
- Edge Function 必须通过 Supabase Auth `getUser(token)`/等价服务端验证取得用户，不能只 base64 decode JWT；Anonymous Auth 的 JWT 也映射为 `authenticated` 角色并受同一 RLS 保护
- 错误格式统一：
```json
{
  "error": {
    "code": "NOT_SUBSCRIBED",
    "message": "免费 AI 诊断已使用，需要 Pro 订阅",
    "request_id": "7ff9f2b8-3aa6-4f2d-b77a-948e2fdfe90b"
  }
}
```
- 错误码：`UNAUTHORIZED`(401) / `FORBIDDEN`(403) / `NOT_SUBSCRIBED`(403) / `NOT_FOUND`(404) / `CONFLICT`(409) / `VALIDATION_ERROR`(422) / `RATE_LIMITED`(429) / `QUOTA_EXHAUSTED`(429) / `UPSTREAM_UNAVAILABLE`(503) / `INTERNAL`(500)
- 429 响应增加 `Retry-After`；503 表示依赖暂不可用且本次不扣 AI 额度；日志和响应都使用同一 `request_id`

---

## 3. POST /ai-diagnose

**请求头**：`Authorization`、`Content-Type: application/json`、`Idempotency-Key: <UUID>`。

**请求体**（对应 07-AI-DIAGNOSIS 输入契约）：
```json
{
  "diagnostic_record_id": "018f1f5e-b17a-7d2f-90f2-7c1f06719d42",
  "dtc_record_id": "018f1f60-00c2-77ff-a446-c6f638a32621",
  "zip_code": "90210"
}
```

客户端必须先通过 `sync_diagnostic_batch` 把车辆、诊断会话、带 `source_ecu` 的 DTC 和多 ECU/multi-frame 冻结帧写入云端；匿名游客也先取得 Supabase Anonymous Auth JWT 并同步。Edge Function 根据两个 ID 从数据库加载主 DTC 的 code/status/source ECU、车辆、**诊断时里程快照**、readiness、多条 `freeze_frames`、带 ECU 来源的 sibling DTC，以及 profile 的 locale/unit system；AI 车辆字段只取 `year/make/model/engine/transmission`，不加载 VIN、车牌或昵称。不接受客户端重复上传这些可被篡改的字段，并验证两条记录属于同一 JWT 用户且父子关系一致。AI 使用会话里程快照，不能用后来变化的 `vehicles.mileage_miles` 改写历史上下文。冻结帧只在 `dtc_record_id` 明确等于主 DTC 时标记为其触发帧；`dtc_record_id=null` 的 PID 02 帧作为 `trigger_dtc_unknown` 的同会话上下文，绝不能推断成主 DTC 触发帧。

**响应 200**：`diagnosis` 严格符合 07 输出契约；`meta.cached` 仅表示是否省掉 LLM 调用。下例中文只便于阅读本规范；V1 实际响应语言固定为规范化后的 `en-US`。

```json
{
  "diagnosis": {
    "schema_version": "1.0",
    "dtc": "P0420",
    "summary": "催化转化器效率低于阈值，建议尽快检查。",
    "severity": "warning",
    "severity_label": "Inspect soon",
    "possible_causes": [{ "cause": "催化转化器老化", "probability": 1.0 }],
    "repair_cost": {
      "low": 800, "high": 1800, "currency": "USD",
      "labor": { "low": 150, "high": 400 },
      "parts": { "low": 650, "high": 1400 },
      "source": "estimate",
      "estimate_note": "Rough estimate based on vehicle context and general U.S. market data; it is not a repair-shop quote."
    },
    "parts": [],
    "diy_steps": ["检查排气管有无明显泄漏"],
    "when_to_seek_pro": "建议 1 周内送修。",
    "can_drive": true,
    "can_drive_note": "可短途驾驶；出现动力下降时停止驾驶并求助。",
    "disclaimer": "AI-generated guidance is for informational purposes only and does not replace an in-person inspection by a certified technician. If a safety risk is present, stop driving and seek professional help immediately."
  },
  "meta": {
    "diagnosis_id": "018f1f65-a6e0-7ba4-8c72-dbd6ee7cda2e",
    "request_id": "7ff9f2b8-3aa6-4f2d-b77a-948e2fdfe90b",
    "cached": false,
    "quota_kind": "free_trial",
    "quota_remaining": 0
  }
}
```

Free 用户的第一次调用返回与 Pro 相同字段的**完整结果**，成功后消耗唯一一次试用；不存在“只给半份结果的 AI preview”。本地 DTC 通用含义卡片属于离线静态预览，不调用本端点、不耗额度。免费完整结果已使用且无有效 Pro 时才返回 `403 NOT_SUBSCRIBED`。

**额度/缓存语义**：一次新的完整诊断无论来自 LLM 还是缓存，都计一次产品额度；缓存只节省模型成本。重复查看已落库的历史结果直接读 `ai_diagnoses`，不调用本端点。相同 `Idempotency-Key` 的网络重试不重复计数。

**流程**：

1. 验证 JWT（正式或匿名）并为本次尝试生成 trace `request_id`；它与客户端 `Idempotency-Key` 不同。
2. zod 校验 ID/邮编；按 RLS 归属链读取诊断、主 DTC、车辆、里程/readiness 快照、全部 freeze frames（保留可空 DTC 关联标记）和 sibling DTC；不存在或不属于用户统一返回 404，避免泄露 ID。
3. 对规范化请求体做 SHA-256 `request_hash` 并检查幂等记录；同 key + 不同 hash 返回 409，同 key 已有 diagnosis 则补齐 usage 状态并返回原结果。
4. entitlement 镜像过期时调用 RevenueCat 刷新；上游失败且没有可接受的新鲜镜像时返回 503。
5. 调用 `reserve_ai_usage(user_id, idempotency_key, request_hash, dtc_record_id)` 短事务原子预留 Free 试用或 Pro 30 天窗口额度。Free 试用已用返回 403；Pro 窗口额度耗尽返回 429。
6. 用 07 的规范化字段与版本生成 cache key 后查缓存。命中则跳过 LLM；未命中则查 DTC 目录、调用 LLM、zod 校验、执行确定性 safety override，并组装已验证 references。
7. 用 `(user_id,idempotency_key)` 执行 `insert ... on conflict do nothing` 写 `ai_diagnoses`；冲突时读既有行。随后幂等调用 `finalize_ai_usage(..., success=true, ...)` 并返回，确保同一 DTC 允许多版本、同一 key 只落一条。
8. 第 6 步或结果落库前失败时调用 `finalize_ai_usage(..., success=false, ...)` 释放预留，再返回 503/500。若在结果插入后、finalize 前崩溃，重试或超时清理按 key 找到既有结果并补完成，不能重复写入或重复扣额。

**限流**：按已验证用户 ID + 短期加盐 IP 摘要双维度执行，Free/未订阅用户 10 次/分钟，Pro 60 次/分钟；不把原始 IP 写入应用日志或分析。每次只诊断一个主 DTC；多 DTC 会话按 07 的队列策略逐个请求。

---

## 4. POST /vehicle-decode

**请求**：`{ "vin": "1HGCM82633A004352" }`

**响应 200（成功解码）**：
```json
{
  "vin": "1HGCM82633A004352",
  "decoded": true,
  "year": 2003, "make": "Honda", "model": "Accord",
  "engine": null, "transmission": null,
  "source": "nhtsa"
}
```

**数据源**：NHTSA 公开 VIN 解码 API（免费）。

- VIN 不符合 17 位格式/校验规则：422 `VALIDATION_ERROR`。
- VIN 合法但 NHTSA 没有足够字段：返回 200、`decoded: false`、可用字段或 `null`，客户端提示手动输入。
- NHTSA 超时、限流或 5xx：503 `UPSTREAM_UNAVAILABLE`，不能伪装成“车辆未知”。

---

## 5. 订阅校验（内部实现）

客户端初始化 RevenueCat SDK 后必须执行 `logIn(supabaseUser.id)`；服务端的 `app_user_id` 永远取已验证 JWT 的 `user.id`，不接受请求参数。调用 RevenueCat REST API `GET /v1/subscribers/{app_user_id}`，检查 entitlement `pro` 是否仍有效：

```ts
type ProEntitlement = {
  expires_date?: string | null;
  grace_period_expires_date?: string | null;
  product_identifier?: string | null;
};
type SubscriptionInfo = { store?: string | null };

async function fetchProEntitlement(userIdFromVerifiedJwt: string) {
  const resp = await fetch(
    `https://api.revenuecat.com/v1/subscribers/${encodeURIComponent(userIdFromVerifiedJwt)}`,
    {
      headers: {
        Authorization: `Bearer ${Deno.env.get('REVENUECAT_API_KEY')!}`,
        Accept: 'application/json',
      },
    },
  );

  if (!resp.ok) {
    throw new Error(`REVENUECAT_${resp.status}`);
  }

  const body = await resp.json() as {
    subscriber?: {
      entitlements?: Record<string, ProEntitlement>;
      subscriptions?: Record<string, SubscriptionInfo>;
      original_app_user_id?: string;
    };
  };
  const pro = body.subscriber?.entitlements?.pro;
  const parseOptionalDate = (value?: string | null) => {
    if (value == null) return null;
    const parsed = Date.parse(value);
    if (Number.isNaN(parsed)) throw new Error('REVENUECAT_INVALID_DATE');
    return parsed;
  };
  const allowedProductIds = new Set(
    (Deno.env.get('V1_PRO_PRODUCT_IDS') ?? '')
      .split(',')
      .map((value) => value.trim())
      .filter(Boolean),
  );
  if (allowedProductIds.size === 0) {
    throw new Error('V1_PRO_PRODUCT_IDS_NOT_CONFIGURED');
  }

  const productId = pro?.product_identifier ?? null;
  const subscription = productId == null
    ? undefined
    : body.subscriber?.subscriptions?.[productId];
  const store = subscription?.store ?? null;
  const expiresAtMs = parseOptionalDate(pro?.expires_date);
  const graceExpiresAtMs = parseOptionalDate(pro?.grace_period_expires_date);
  const allowedProduct = productId != null && allowedProductIds.has(productId);
  const allowedStore = store === 'app_store' || store === 'play_store';
  const inPaidPeriod = expiresAtMs != null && expiresAtMs > Date.now();
  const inGrace = expiresAtMs != null
    && graceExpiresAtMs != null
    && graceExpiresAtMs >= expiresAtMs
    && graceExpiresAtMs > Date.now();
  const status = allowedProduct && allowedStore
    ? (inPaidPeriod ? 'active' : inGrace ? 'grace' : 'inactive')
    : 'inactive';

  return {
    active: status === 'active' || status === 'grace',
    status,
    productId,
    store,
    originalAppUserId: body.subscriber?.original_app_user_id ?? null,
    expiresAt: pro?.expires_date ?? null,
    graceExpiresAt: pro?.grace_period_expires_date ?? null,
  };
}
```

RevenueCat v1 会返回过期 entitlement，也可能用 `expires_date: null` 表示 OneTime/lifetime；因此 V1 必须同时校验 `product_identifier` 月/年订阅 allowlist、`subscriptions[product_id].store` 为 App Store/Play Store，以及正常 expiry 或 grace 尚未结束。空 expiry 不再自动视为 active，避免提前放行 V1.1 OneTime。字段形状以 [RevenueCat API v1 Customer Info](https://www.revenuecat.com/docs/api-v1) 为准。成功响应把 product/store/expiry/grace 写入 `subscription_entitlements`，`updated_at` 在 5 分钟内可作为新鲜镜像；Edge 可使用相同 TTL 的短缓存。RevenueCat webhook、购买/恢复购买成功和 `/verify-subscription` 强制刷新都会使缓存失效；镜像超过 5 分钟且 RevenueCat 刷新失败时 fail closed 返回 503。REST 非 2xx/非法 JSON 不得当作 Free 静默覆盖已有权益。

`POST /verify-subscription` 请求体为空；请求头必须带 JWT 和新的 `Idempotency-Key`，同一次购买后刷新发生网络重试时复用该 key。响应示例：

```json
{
  "tier": "pro",
  "status": "active",
  "product_id": "obd2_pro_monthly",
  "store": "app_store",
  "expires_at": "2026-09-14T00:00:00Z",
  "ai_quota": {
    "limit": 100,
    "used": 12,
    "remaining": 88,
    "window_started_at": "2026-08-20T00:00:00Z",
    "window_ends_at": "2026-09-19T00:00:00Z"
  }
}
```

示例中的 100 只展示字段关系，不是产品承诺；实际 `limit` 读取服务端 `PRO_AI_QUOTA_PER_30_DAYS`。AI 窗口独立于 RevenueCat 月/年订阅周期，按首次 Pro 激活锚点连续 30 天推进；续订不会提前重置额度。

### 5.1 POST /revenuecat-webhook（内部）

RevenueCat 项目后台必须配置独立高熵 Authorization 值；端点按常量时间比较完整 `Authorization` header 与 `Bearer ${REVENUECAT_WEBHOOK_SECRET}`。鉴权失败返回 401，且不解析或记录 body。`Content-Length` 预检和实际读取字节数都不得超过 64 KiB；缺少/非法 JSON、`event.id` 或 `event.app_user_id` 返回 422。日志不记录 Authorization、原始 body 或完整 Customer Info。

处理顺序固定为：

1. 对原始 body 做 SHA-256，以 `event.id`、`event.app_user_id` 和 hash 插入 03 的 `revenuecat_webhook_events`；同 ID/同 hash 的 processed 重试直接返回 204，同 ID/不同 hash 返回 409 并产生安全告警。
2. **不按 webhook 的事件类型或时间戳直接增减权益**。事件可能重复或乱序；鉴权和收件成功后，用 `event.app_user_id` 调 RevenueCat Customer Info，复用上面的 product/store/expiry/grace allowlist 校验取得当前事实状态。
3. 在短数据库事务调用 `refresh_entitlement(...)` 并把收件箱行标为 processed，成功返回 204。Customer Info 暂不可用时把行标为 failed、只留稳定错误码并返回 503，以便 RevenueCat 重试；再次处理同 ID/同 hash 的 failed 行必须可恢复。

此端点不接受客户端 JWT、客户端 `Idempotency-Key` 或 `user_id` 覆盖；只有 RevenueCat REST 返回的当前状态可以改变 entitlement 镜像。

---

## 6. 账号导出与删除

### 6.1 GET /account-export

服务端通过 `getUser(token)` 取得当前用户，并以该 JWT/RLS 分页流式读取 profile、车辆、诊断会话、清码 action、DTC、冻结帧、AI 结果、保养记录/提醒、entitlement 和 usage（包括仍在保留期内的软删除行）。导出不得包含其他用户、内部 webhook/job 行、Auth 密码哈希、JWT/refresh token、服务端日志、密钥或模型 Prompt。响应为带版本号与 `generated_at` 的 JSON attachment；必须设置 `Cache-Control: private, no-store`、`Pragma: no-cache`、`X-Content-Type-Options: nosniff`，禁止写 CDN/公共对象存储、应用日志或分析事件。导出限流，客户端只在用户明确操作后保存到其选择的位置。

### 6.2 DELETE /account

请求头必须有 JWT 与 `Idempotency-Key: <UUID>`；请求体固定为：

```json
{
  "confirmation": "DELETE MY ACCOUNT",
  "acknowledge_store_subscription_not_cancelled": true
}
```

正式账号必须先执行一次真正的密码、OTP 或 OAuth/SAML provider 重登，再用新 access token 调删除端点。Edge 同时调用 `getUser(token)` 与 `getClaims(token)`，要求两者 subject 一致，并在已签名 JWT 的 `amr` 中找到 `password`、`otp`、`oauth`、`sso/saml` 或 `totp` 方法且其 timestamp 不早于服务端当前时间 5 分钟；`token_refresh` 不算重新认证，不能只比较易随刷新变化的 JWT `iat`。字段定义以 [Supabase JWT Claims Reference](https://supabase.com/docs/guides/auth/jwt-fields) 为准。

匿名账号不能被强迫先提供个人信息才能删除。匿名例外要求 `getUser/getClaims` 都验证成功、subject 一致、两处 `is_anonymous=true`、JWT 未过期，且请求带固定确认与知情确认；服务端按 anonymous UID + 短期加盐 IP 摘要执行更严的 3 次/日限流。客户端在发送前还要用系统凭据/生物识别做一次本地用户在场确认，但该步骤只是设备侧风险降低，**不能**作为服务端 reauth 证明，也不得上传生物识别结果。任一适用确认或正式账号近期强认证缺失返回 403/422，不建任务，也不在日志记录 token/claims 全文。

验证成功后先对规范化请求做 SHA-256 `request_hash`，再以 `(user_id,idempotency_key)` 在 03 的 `account_deletion_jobs` 建耐久任务并持久化 hash，返回 `202 {job_id,status:"pending"}`；同 key/同 hash 重试返回同一任务，同 key/不同 hash 返回 409。RPC 还必须锁定用户并依靠 active-user unique 约束：同一用户用不同 key 并发请求删除时，只创建一个 active job，其他请求返回该既有 job，而不是启动两套 worker。后台 worker：

1. 删除该用户拥有的 Supabase Storage 对象（如有），再以 Admin API 删除 `auth.users` 行，使 03 的 Supabase 主数据通过 FK cascade 清除；所有业务端点仍须调用 `getUser`，不得因旧 JWT 在到期前仍可验签就继续放行。随后把 job 标为 `primary_deleted`（设备本地库清理由客户端另行确认，不能用这个状态表示）。
2. 使用服务端 secret 调 RevenueCat API v1 `DELETE /subscribers/{app_user_id}`；200 或“已不存在”等价结果视为成功，429/5xx/网络失败按退避和 `Retry-After` 可靠重试，最终标为 completed。该能力以 [RevenueCat Delete Customer](https://www.revenuecat.com/docs/api-v1) 为准。
3. 后续 webhook 若命中已有删除 job，只能重新触发 provider 清理，不能重建本地 profile/entitlement。任务完成后仅按隐私保留策略留下防重建所需的最小 tombstone，删除错误详情和其他操作数据。

删除账号/RevenueCat customer **不会取消 App Store 或 Play Store 订阅**；确认页必须在删除前提供系统订阅管理入口并明确说明这一点，依据 [RevenueCat customer deletion guidance](https://www.revenuecat.com/docs/dashboard-and-metrics/customer-profile)。客户端收到 202 且用户再次确认清理设备数据后，关闭当前 Drift 句柄并删除该 UID 的专属加密数据库与 Keychain/Keystore 密钥；不得顺带删除其他账号的本地库。

---

## 7. 环境变量（Edge Function）

| 变量 | 说明 |
|---|---|
| `SUPABASE_URL` / `SUPABASE_ANON_KEY` | 使用用户 JWT 执行归属读取 |
| `SUPABASE_SERVICE_ROLE_KEY` | 仅 Edge Function；写 AI/entitlement/usage 与调用受控额度 RPC，绝不下发客户端 |
| `OPENAI_API_KEY` 或 `ANTHROPIC_API_KEY` | LLM |
| `REVENUECAT_API_KEY` | 订阅校验 |
| `REVENUECAT_WEBHOOK_SECRET` | RevenueCat webhook 专用高熵 Authorization secret；不得与 REST API key 共用 |
| `V1_PRO_PRODUCT_IDS` | 逗号分隔的 V1 月/年订阅 product allowlist；不得包含 OneTime/lifetime SKU |
| `PRO_AI_QUOTA_PER_30_DAYS` | Pro 连续 30 天窗口额度；服务端 policy，不能由客户端覆盖 |
| `NHTSA_BASE_URL` | VIN 解码 |

V1 维修费用来源固定为 `estimate`，不调用或配置 RepairPal/Motor。相关真实数据源集成属于后续版本；文案不得暗示 V1 估算来自这些服务。

---

## 8. 测试要点

- 匿名 Supabase Auth 用户首次调用 `/ai-diagnose` → 200 + 与 Pro 同结构的完整结果，`quota_kind=free_trial`、剩余 0
- 同一 Free 用户第二个新 `Idempotency-Key` → 403 `NOT_SUBSCRIBED`
- Free 完整试用成功后，即使历史保留期结束并硬删对应诊断/DTC/AI/usage 行，entitlement 的永久消费标记仍使新 key 返回 403；失败释放才恢复一次机会
- 有效 Pro 且有 30 天窗口额度 → 200 + 合法 JSON（zod + safety override 通过）；窗口额度耗尽 → 429 `QUOTA_EXHAUSTED`
- RevenueCat 月/年 allowlist 正常期与未结束 grace → Pro；未知 product、未知 store、过期 grace、`expires_date=null` 的 OneTime/lifetime → V1 不放行
- RevenueCat webhook：合法 Authorization + 当前 Customer Info 可刷新；伪造 Authorization、超 64 KiB body 被拒绝；重复/乱序事件和同 ID 重试不会重复写或把当前权益回滚；同 ID 不同 hash 告警；上游失败后可重试收敛
- 缓存命中 → 不调用 LLM，但成功后仍消耗一次产品额度；相同 idempotency key 重试不重复消耗
- 同 key + 不同规范化请求 hash → 409；模拟“diagnosis 已插入、usage 未 finalize”崩溃后重试，只保留一条结果且补完成原 usage
- LLM、RevenueCat 或落库在预留后失败 → 预留被幂等释放，Free 用户仍可重试唯一一次完整结果
- `diagnostic_record_id` 与 `dtc_record_id` 不属于同一用户/父子链 → 404，且不消耗额度
- 非法 UUID、缺失 ID 或非法 ZIP → 422 `VALIDATION_ERROR`；DTC 本身只能来自已校验并落库的 `dtc_records`
- 限流触发 → 429 RATE_LIMITED
- VIN 格式非法 → 422；合法但无结果 → 200 `decoded=false`；NHTSA 故障 → 503
- 同一 DTC 使用不同模型/Prompt/Schema 版本可生成多条 `ai_diagnoses`，历史默认读最新未删除版本
- 导出仅含当前用户的完整自有数据和软删除保留行，敏感响应带 `no-store` 且不进入日志/CDN；跨用户 ID、无效 JWT 和限流路径被拒绝
- 正式账号删除要求 JWT subject 一致且 `amr` 有 5 分钟内的 password/OTP/OAuth/SAML/TOTP 强认证；token refresh/旧 amr 被拒绝。匿名账号凭有效 anonymous JWT + 固定二次确认 + 更严限流可直接删除，客户端系统凭据确认不冒充服务端 reauth。两类都要求商店订阅知情确认；同 key 重试或同用户不同 key 并发都只建一个 active job；Storage/Auth/Postgres 数据清除后 RevenueCat 临时失败可继续重试；旧 JWT、后续 webhook 和账号 B 均不能读回/重建账号 A 数据
