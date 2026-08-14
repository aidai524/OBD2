# 03 · 数据模型设计

> 文档版本：v1.1 · 产品范围：V1 = P0 · 读者：Codex（建表 / 模型实现依据）
> 云端：Supabase（PostgreSQL）· 本地：Drift / SQLite（离线数据库）

---

## 1. 云端表结构（Supabase / PostgreSQL）

以下 DDL 是 **V1 初始迁移的规范来源**，不是字段示意。实现迁移时必须保留约束、外键动作和索引；所有客户端离线创建的业务 ID 由客户端生成 UUIDv7（服务端 `gen_random_uuid()` 仅作兜底）。匿名游客也先通过 Supabase Anonymous Auth 获得 `auth.users.id`，因此与正式账号共用同一归属模型。

```sql
create extension if not exists pgcrypto;

create table public.profiles (
  id uuid primary key references auth.users(id) on delete cascade,
  email text,
  display_name text,
  locale text not null default 'en-US' check (char_length(locale) between 2 and 16),
  unit_system text not null default 'imperial' check (unit_system in ('imperial', 'metric')),
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

create table public.vehicles (
  id uuid primary key default gen_random_uuid(),
  user_id uuid not null references public.profiles(id) on delete cascade,
  vin text check (vin is null or vin ~ '^[A-HJ-NPR-Z0-9]{17}$'),
  year smallint not null check (year between 1981 and 2100),
  make text not null check (char_length(btrim(make)) > 0),
  model text not null check (char_length(btrim(model)) > 0),
  engine text,
  transmission text,
  mileage_miles integer check (mileage_miles is null or mileage_miles >= 0),
  license_plate text check (license_plate is null or char_length(btrim(license_plate)) between 1 and 20),
  nickname text,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  deleted_at timestamptz,
  unique (id, user_id)
);

create table public.diagnostic_records (
  id uuid primary key default gen_random_uuid(),
  user_id uuid not null references public.profiles(id) on delete cascade,
  vehicle_id uuid not null,
  mileage_miles integer check (mileage_miles is null or mileage_miles >= 0),
  readiness jsonb check (readiness is null or jsonb_typeof(readiness) = 'object'),
  started_at timestamptz not null default now(),
  ended_at timestamptz,
  connection_type text not null check (connection_type in ('wifi', 'ble', 'spp')),
  adapter_name text,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  deleted_at timestamptz,
  constraint diagnostic_records_time_check check (ended_at is null or ended_at >= started_at),
  constraint diagnostic_records_vehicle_owner_fk
    foreign key (vehicle_id, user_id) references public.vehicles(id, user_id) on delete cascade,
  unique (id, vehicle_id, user_id),
  unique (id, user_id)
);

create table public.diagnostic_actions (
  id uuid primary key default gen_random_uuid(),
  user_id uuid not null references public.profiles(id) on delete cascade,
  diagnostic_record_id uuid not null,
  vehicle_id uuid not null,
  action_type text not null check (action_type = 'clear_dtc'),
  status text not null default 'requested'
    check (status in ('requested', 'succeeded', 'failed', 'unknown')),
  error_code text,
  requested_at timestamptz not null default now(),
  completed_at timestamptz,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  deleted_at timestamptz,
  constraint diagnostic_actions_completion_check check (
    (status = 'requested' and completed_at is null)
    or (status <> 'requested' and completed_at is not null and completed_at >= requested_at)
  ),
  constraint diagnostic_actions_record_owner_fk
    foreign key (diagnostic_record_id, vehicle_id, user_id)
    references public.diagnostic_records(id, vehicle_id, user_id) on delete cascade,
  unique (id, user_id)
);

create table public.dtc_records (
  id uuid primary key default gen_random_uuid(),
  user_id uuid not null references public.profiles(id) on delete cascade,
  diagnostic_record_id uuid not null,
  vehicle_id uuid not null,
  source_ecu text not null check (source_ecu ~ '^[0-9A-F]{2,8}$'),
  dtc_code text not null check (dtc_code ~ '^[PBCU][0-3][0-9A-F]{3}$'),
  status text not null check (status in ('confirmed', 'pending', 'permanent')),
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  deleted_at timestamptz,
  constraint dtc_records_diagnostic_owner_fk
    foreign key (diagnostic_record_id, vehicle_id, user_id)
    references public.diagnostic_records(id, vehicle_id, user_id) on delete cascade,
  unique (id, diagnostic_record_id, vehicle_id, user_id),
  unique (id, user_id)
);

create table public.freeze_frames (
  id uuid primary key default gen_random_uuid(),
  user_id uuid not null references public.profiles(id) on delete cascade,
  diagnostic_record_id uuid not null,
  vehicle_id uuid not null,
  dtc_record_id uuid,
  frame_number smallint not null check (frame_number between 0 and 255),
  ecu_address text not null check (ecu_address ~ '^[0-9A-F]{2,8}$'),
  pid_values jsonb not null check (
    jsonb_typeof(pid_values) = 'object'
    and (pid_values ->> 'schema_version') = 'obd2.pid.v1'
    and jsonb_typeof(pid_values -> 'values') = 'object'
  ),
  captured_at timestamptz,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  deleted_at timestamptz,
  constraint freeze_frames_diagnostic_owner_fk
    foreign key (diagnostic_record_id, vehicle_id, user_id)
    references public.diagnostic_records(id, vehicle_id, user_id) on delete cascade,
  constraint freeze_frames_optional_dtc_owner_fk
    foreign key (dtc_record_id, diagnostic_record_id, vehicle_id, user_id)
    references public.dtc_records(id, diagnostic_record_id, vehicle_id, user_id),
  unique (id, user_id)
);

create table public.ai_diagnoses (
  id uuid primary key default gen_random_uuid(),
  user_id uuid not null references public.profiles(id) on delete cascade,
  dtc_record_id uuid not null,
  idempotency_key uuid not null,
  result jsonb not null check (jsonb_typeof(result) = 'object'),
  severity text not null check (severity in ('critical', 'warning', 'info')),
  repair_cost_low integer not null check (repair_cost_low >= 0),
  repair_cost_high integer not null check (repair_cost_high >= repair_cost_low),
  currency text not null default 'USD' check (currency = 'USD'),
  cost_source text not null default 'estimate' check (cost_source = 'estimate'),
  generation_source text not null check (generation_source in ('llm', 'cache')),
  model_provider text not null check (char_length(btrim(model_provider)) > 0),
  model_name text not null check (char_length(btrim(model_name)) > 0),
  model_version text not null check (char_length(btrim(model_version)) > 0),
  prompt_version text not null check (char_length(btrim(prompt_version)) > 0),
  schema_version text not null check (char_length(btrim(schema_version)) > 0),
  safety_rules_version text not null check (char_length(btrim(safety_rules_version)) > 0),
  cache_key text not null check (cache_key ~ '^[0-9a-f]{64}$'),
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  deleted_at timestamptz,
  constraint ai_diagnoses_dtc_owner_fk
    foreign key (dtc_record_id, user_id) references public.dtc_records(id, user_id) on delete cascade,
  constraint ai_diagnoses_result_severity_check
    check ((result ->> 'severity') is not distinct from severity),
  constraint ai_diagnoses_result_schema_check
    check ((result ->> 'schema_version') is not distinct from schema_version),
  constraint ai_diagnoses_result_cost_source_check
    check ((result #>> '{repair_cost,source}') is not distinct from 'estimate'),
  constraint ai_diagnoses_result_currency_check
    check ((result #>> '{repair_cost,currency}') is not distinct from 'USD'),
  unique (user_id, idempotency_key),
  unique (id, user_id)
);

create table public.maintenance_records (
  id uuid primary key default gen_random_uuid(),
  user_id uuid not null references public.profiles(id) on delete cascade,
  vehicle_id uuid not null,
  type text not null check (type in ('oil', 'brake', 'tire', 'battery', 'other')),
  service_date date not null,
  mileage_miles integer not null check (mileage_miles >= 0),
  cost numeric(10,2) check (cost is null or cost >= 0),
  currency text not null default 'USD' check (currency ~ '^[A-Z]{3}$'),
  notes text,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  deleted_at timestamptz,
  constraint maintenance_records_vehicle_owner_fk
    foreign key (vehicle_id, user_id) references public.vehicles(id, user_id) on delete cascade
);

create table public.maintenance_schedules (
  id uuid primary key default gen_random_uuid(),
  user_id uuid not null references public.profiles(id) on delete cascade,
  vehicle_id uuid not null,
  type text not null check (type in ('oil', 'brake', 'tire', 'battery', 'other')),
  interval_miles integer check (interval_miles is null or interval_miles > 0),
  interval_months integer check (interval_months is null or interval_months > 0),
  last_mileage integer check (last_mileage is null or last_mileage >= 0),
  last_date date,
  enabled boolean not null default true,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  deleted_at timestamptz,
  constraint maintenance_schedules_interval_check
    check (interval_miles is not null or interval_months is not null),
  constraint maintenance_schedules_vehicle_owner_fk
    foreign key (vehicle_id, user_id) references public.vehicles(id, user_id) on delete cascade
);

-- RevenueCat 的服务端镜像；客户端只读，RevenueCat 仍是订阅事实来源。
create table public.subscription_entitlements (
  user_id uuid primary key references public.profiles(id) on delete cascade,
  tier text not null default 'free' check (tier in ('free', 'pro')),
  status text not null default 'inactive' check (status in ('inactive', 'active', 'grace', 'expired')),
  source text not null default 'revenuecat' check (source in ('revenuecat', 'system')),
  revenuecat_app_user_id text unique,
  revenuecat_original_app_user_id text,
  product_id text,
  store text check (store is null or store in ('app_store', 'play_store')),
  period_started_at timestamptz,
  expires_at timestamptz,
  grace_expires_at timestamptz,
  free_ai_trial_consumed_at timestamptz,
  free_ai_trial_reservation_id uuid,
  quota_window_started_at timestamptz,
  quota_window_ends_at timestamptz,
  ai_quota_limit integer not null default 0 check (ai_quota_limit >= 0),
  ai_quota_used integer not null default 0 check (ai_quota_used >= 0 and ai_quota_used <= ai_quota_limit),
  updated_at timestamptz not null default now(),
  constraint subscription_entitlements_period_check
    check (expires_at is null or period_started_at is null or expires_at > period_started_at),
  constraint subscription_entitlements_grace_check
    check (
      grace_expires_at is null
      or (expires_at is not null and grace_expires_at >= expires_at)
    ),
  constraint subscription_entitlements_free_trial_reservation_check
    check (free_ai_trial_reservation_id is null or free_ai_trial_consumed_at is not null),
  constraint subscription_entitlements_quota_window_check
    check (
      (quota_window_started_at is null and quota_window_ends_at is null)
      or quota_window_ends_at = quota_window_started_at + interval '30 days'
    ),
  constraint subscription_entitlements_tier_quota_check
    check (
      (tier = 'free' and ai_quota_limit = 0 and quota_window_started_at is null)
      or (tier = 'pro' and ai_quota_limit > 0 and quota_window_started_at is not null)
    ),
  constraint subscription_entitlements_pro_identity_check
    check (
      tier = 'free'
      or (
        revenuecat_app_user_id is not null
        and product_id is not null
        and store is not null
        and expires_at is not null
      )
    )
);

-- RevenueCat webhook 的幂等收件箱；仅 service_role 可访问，不保存完整 payload。
create table public.revenuecat_webhook_events (
  event_id text primary key check (char_length(event_id) between 1 and 200),
  app_user_id text not null check (char_length(app_user_id) between 1 and 200),
  payload_hash text not null check (payload_hash ~ '^[0-9a-f]{64}$'),
  status text not null default 'received' check (status in ('received', 'processed', 'failed')),
  received_at timestamptz not null default now(),
  processed_at timestamptz,
  last_error_code text,
  updated_at timestamptz not null default now(),
  constraint revenuecat_webhook_events_completion_check check (
    (status = 'processed' and processed_at is not null and processed_at >= received_at)
    or (status <> 'processed' and processed_at is null)
  )
);

-- 账号删除的耐久任务；删除 auth.users 后仍须保留到 RevenueCat 清理完成。
create table public.account_deletion_jobs (
  id uuid primary key default gen_random_uuid(),
  user_id uuid not null,
  idempotency_key uuid not null,
  request_hash text not null check (request_hash ~ '^[0-9a-f]{64}$'),
  revenuecat_app_user_id text not null check (char_length(revenuecat_app_user_id) between 1 and 200),
  status text not null default 'pending'
    check (status in ('pending', 'primary_deleted', 'retrying', 'completed')),
  attempts integer not null default 0 check (attempts >= 0),
  next_attempt_at timestamptz not null default now(),
  primary_deleted_at timestamptz,
  revenuecat_deleted_at timestamptz,
  completed_at timestamptz,
  last_error_code text,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  constraint account_deletion_jobs_state_check check (
    (status = 'pending' and primary_deleted_at is null and completed_at is null)
    or (status in ('primary_deleted', 'retrying') and primary_deleted_at is not null and completed_at is null)
    or (
      status = 'completed'
      and primary_deleted_at is not null
      and revenuecat_deleted_at is not null
      and completed_at is not null
    )
  ),
  unique (user_id, idempotency_key)
);

-- 每次完整 AI 诊断先预留用量；失败释放，成功完成。idempotency_key 与 trace request_id 不同。
create table public.ai_usage_events (
  id uuid primary key default gen_random_uuid(),
  user_id uuid not null references public.profiles(id) on delete cascade,
  idempotency_key uuid not null,
  request_hash text not null check (request_hash ~ '^[0-9a-f]{64}$'),
  dtc_record_id uuid not null,
  ai_diagnosis_id uuid,
  quota_kind text not null check (quota_kind in ('free_trial', 'pro')),
  status text not null default 'reserved' check (status in ('reserved', 'completed', 'released')),
  reservation_expires_at timestamptz not null default (now() + interval '15 minutes'),
  cache_hit boolean not null default false,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  constraint ai_usage_events_dtc_owner_fk
    foreign key (dtc_record_id, user_id) references public.dtc_records(id, user_id) on delete cascade,
  constraint ai_usage_events_diagnosis_owner_fk
    foreign key (ai_diagnosis_id, user_id) references public.ai_diagnoses(id, user_id) on delete cascade,
  constraint ai_usage_events_reservation_time_check
    check (reservation_expires_at > created_at),
  unique (user_id, idempotency_key)
);

-- 正式账号和匿名账号都自动获得 profile + Free entitlement 镜像。
create or replace function public.handle_new_auth_user()
returns trigger language plpgsql security definer set search_path = '' as $$
begin
  insert into public.profiles(id, email)
  values (new.id, new.email)
  on conflict (id) do nothing;
  insert into public.subscription_entitlements(user_id, tier, status, source)
  values (new.id, 'free', 'inactive', 'system')
  on conflict (user_id) do nothing;
  return new;
end;
$$;

create trigger auth_user_created
after insert on auth.users
for each row execute function public.handle_new_auth_user();
```

### 1.1 时间戳触发器与索引

云表 `updated_at` 必须由 PostgreSQL 写入，禁止相信设备时钟。初始迁移同时创建统一触发器，并覆盖所有外键、RLS 和常用查询列的索引：

```sql
create or replace function public.set_updated_at()
returns trigger language plpgsql set search_path = '' as $$
begin
  new.updated_at = now();
  return new;
end;
$$;

create or replace function public.stamp_deleted_at()
returns trigger language plpgsql set search_path = '' as $$
begin
  if old.deleted_at is null and new.deleted_at is not null then
    new.deleted_at = now();
  end if;
  return new;
end;
$$;

do $$
declare t text;
begin
  foreach t in array array[
    'profiles', 'vehicles', 'diagnostic_records', 'diagnostic_actions', 'dtc_records',
    'freeze_frames', 'ai_diagnoses',
    'maintenance_records', 'maintenance_schedules', 'subscription_entitlements',
    'revenuecat_webhook_events', 'account_deletion_jobs', 'ai_usage_events'
  ] loop
    execute format(
      'create trigger %I before update on public.%I for each row execute function public.set_updated_at()',
      t || '_set_updated_at', t
    );
  end loop;
end $$;

do $$
declare t text;
begin
  foreach t in array array[
    'vehicles', 'diagnostic_records', 'diagnostic_actions', 'dtc_records',
    'freeze_frames', 'ai_diagnoses',
    'maintenance_records', 'maintenance_schedules'
  ] loop
    execute format(
      'create trigger %I before update on public.%I for each row execute function public.stamp_deleted_at()',
      t || '_stamp_deleted_at', t
    );
  end loop;
end $$;

create index vehicles_user_id_idx on public.vehicles(user_id);
create unique index vehicles_user_vin_active_uidx on public.vehicles(user_id, vin)
  where vin is not null and deleted_at is null;
create index diagnostic_records_user_started_idx
  on public.diagnostic_records(user_id, started_at desc) where deleted_at is null;
create index diagnostic_records_user_id_idx
  on public.diagnostic_records(user_id);
create index diagnostic_records_vehicle_owner_idx
  on public.diagnostic_records(vehicle_id, user_id);
create index diagnostic_actions_record_owner_idx
  on public.diagnostic_actions(diagnostic_record_id, vehicle_id, user_id);
create index diagnostic_actions_user_requested_idx
  on public.diagnostic_actions(user_id, requested_at desc);
create index dtc_records_diagnostic_owner_idx
  on public.dtc_records(diagnostic_record_id, vehicle_id, user_id);
create index dtc_records_vehicle_code_idx
  on public.dtc_records(vehicle_id, dtc_code) where deleted_at is null;
create unique index dtc_records_session_ecu_code_status_active_uidx
  on public.dtc_records(diagnostic_record_id, source_ecu, dtc_code, status)
  where deleted_at is null;
create index dtc_records_user_id_idx
  on public.dtc_records(user_id);
create index freeze_frames_dtc_owner_idx
  on public.freeze_frames(dtc_record_id, diagnostic_record_id, vehicle_id, user_id)
  where dtc_record_id is not null;
create index freeze_frames_diagnostic_owner_idx
  on public.freeze_frames(diagnostic_record_id, vehicle_id, user_id);
create index freeze_frames_user_id_idx
  on public.freeze_frames(user_id);
create unique index freeze_frames_session_ecu_frame_active_uidx
  on public.freeze_frames(diagnostic_record_id, ecu_address, frame_number)
  where deleted_at is null;
create index ai_diagnoses_dtc_created_idx
  on public.ai_diagnoses(dtc_record_id, created_at desc) where deleted_at is null;
create index ai_diagnoses_dtc_owner_idx
  on public.ai_diagnoses(dtc_record_id, user_id);
create index ai_diagnoses_user_id_idx
  on public.ai_diagnoses(user_id);
create index ai_diagnoses_user_cache_idx
  on public.ai_diagnoses(user_id, cache_key) where deleted_at is null;
create index ai_diagnoses_shared_cache_idx
  on public.ai_diagnoses(cache_key, created_at desc) where deleted_at is null;
create index maintenance_records_vehicle_owner_idx
  on public.maintenance_records(vehicle_id, user_id);
create index maintenance_records_vehicle_date_idx
  on public.maintenance_records(vehicle_id, service_date desc) where deleted_at is null;
create index maintenance_records_user_id_idx
  on public.maintenance_records(user_id);
create index maintenance_schedules_vehicle_owner_idx
  on public.maintenance_schedules(vehicle_id, user_id);
create index maintenance_schedules_user_id_idx
  on public.maintenance_schedules(user_id);
create unique index maintenance_schedules_vehicle_type_active_uidx
  on public.maintenance_schedules(vehicle_id, type) where deleted_at is null;
create index ai_usage_events_user_created_idx
  on public.ai_usage_events(user_id, created_at desc);
create index ai_usage_events_dtc_owner_idx
  on public.ai_usage_events(dtc_record_id, user_id);
create index ai_usage_events_diagnosis_owner_idx
  on public.ai_usage_events(ai_diagnosis_id, user_id) where ai_diagnosis_id is not null;
create index ai_usage_events_expiring_reservations_idx
  on public.ai_usage_events(reservation_expires_at)
  where status = 'reserved';
create unique index ai_usage_one_free_trial_uidx
  on public.ai_usage_events(user_id)
  where quota_kind = 'free_trial' and status in ('reserved', 'completed');
create index revenuecat_webhook_events_user_received_idx
  on public.revenuecat_webhook_events(app_user_id, received_at desc);
create index account_deletion_jobs_retry_idx
  on public.account_deletion_jobs(next_attempt_at)
  where status in ('pending', 'primary_deleted', 'retrying');
create unique index account_deletion_jobs_one_active_user_uidx
  on public.account_deletion_jobs(user_id) where status <> 'completed';
create index account_deletion_jobs_revenuecat_user_idx
  on public.account_deletion_jobs(revenuecat_app_user_id, created_at desc);
```

`ai_diagnoses.dtc_record_id` **不唯一**：同一 DTC 在车辆上下文、模型、Prompt、Schema 或安全规则变化后允许生成多版结果；展示默认取最新且未删除的一条。

---

## 2. freeze_frames（多 ECU / 多帧冻结帧）结构

冻结帧不是 `dtc_records` 的单个 JSON 字段；每个 ECU、每个 `frame_number` 独立存一行 `freeze_frames`。OBD Service 02/PID 02 可能不返回触发 DTC，因此每帧必须直接归属诊断会话与车辆，而 `dtc_record_id` 可空；只有协议明确给出触发 DTC 且能匹配本会话 DTC 时才关联，不能推测或伪造。以下是完整 FreezeFrame 序列化示例：

```json
{
  "diagnostic_record_id": "018f1f5e-b17a-7d2f-90f2-7c1f06719d42",
  "vehicle_id": "018f1f55-b873-7e5f-aa42-1234aabbccdd",
  "dtc_record_id": null,
  "frame_number": 0,
  "ecu_address": "7E8",
  "pid_values": {
    "schema_version": "obd2.pid.v1",
    "values": {
      "0C": { "value": 1800, "unit": "rpm" },
      "05": { "value": 92, "unit": "deg_c" },
      "0D": { "value": 55, "unit": "km_h" },
      "04": { "value": 45, "unit": "percent" }
    }
  },
  "captured_at": "2026-08-13T10:30:00Z"
}
```

`pid_values.schema_version` 与 `values` 在数据库层必填；应用层 zod 还必须要求 PID key 为两位大写 hex，条目严格为 `{value:number|null, unit:enum}`，并按版本化 PID 目录校验单位（如 `rpm/deg_c/km_h/percent/kpa`）。未知 PID 只能放进新 schema 版本允许的 `extensions`，不能复用已知 PID 键或自创单位。原始总线帧若需要审计应进入单独受限调试日志，不能混入用户同步数据或分析事件。

### 2.1 readiness（排放就绪快照）

`diagnostic_records.readiness` 保存本次会话读取时的快照，而不是引用车辆当前状态：

```json
{
  "mil_on": false,
  "monitors": {
    "misfire": { "supported": true, "complete": true },
    "fuel_system": { "supported": true, "complete": true },
    "catalyst": { "supported": true, "complete": false }
  },
  "captured_at": "2026-08-13T10:30:00Z"
}
```

未知/未支持与未完成必须是不同状态；PDF/历史页读取会话快照，不能回看 `vehicles` 当前值后重算。

---

## 3. 本地存储（Drift / SQLite）

**用途**：离线可用 + 减少云请求。服务端记录是跨设备同步的权威版本，本地保留尚未同步的写入队列和已同步缓存。

V1 唯一本地数据库方案为 **Drift**。选择它是因为本项目需要关系、外键、事务、可审计 migration 和离线同步队列。

| Drift Table | 对应云表/用途 | 同步策略 |
|---|---|---|
| `LocalVehicles` | `vehicles` | 双向；保留本地修改时间、服务端时间与 tombstone |
| `LocalDiagnosticRecords` | `diagnostic_records` | 与 DTC 在同一事务写入；登录后批量上传 |
| `LocalDiagnosticActions` | `diagnostic_actions` | 清码请求与结果审计；与所属会话同步 |
| `LocalDtcRecords` | `dtc_records` | 外键指向本地诊断和车辆；保留规范化 `sourceEcu` |
| `LocalFreezeFrames` | `freeze_frames` | 必须指向本地诊断/车辆，DTC 外键可空；支持多 ECU + `frameNumber` |
| `LocalAiDiagnoses` | `ai_diagnoses` | 服务端生成后下载；本地只读缓存，DTC 1:N |
| `LocalMaintenanceRecords` | `maintenance_records` | 双向；服务端写入受 Pro RPC 约束 |
| `LocalMaintenanceSchedules` | `maintenance_schedules` | 双向；服务端写入受 Pro RPC 约束 |
| `PendingMutations` | 离线 outbox | `id/entityType/entityId/operation/payload/createdAt/attempts/lastError` |
| `SyncState` | 每类同步游标 | 保存服务端 `(updated_at, id)` 游标，不上传 |
| `LocalSettings` | 纯本地设置 | 不同步 |

DAO 边界固定为 `VehicleDao`、`DiagnosticDao`、`AiDiagnosisDao`、`MaintenanceDao`、`SyncDao`。UI/Provider 不直接拼 Drift 查询；所有写入经 DAO，DAO 在同一 `database.transaction` 内同时更新业务表和 `PendingMutations`，保证“本地状态已改变但同步事件丢失”不会发生。一次扫描的 `LocalDiagnosticRecords + LocalDtcRecords + LocalFreezeFrames` 必须同事务提交；冻结帧始终写入会话/车辆外键，只有解析到可信触发 DTC 时才填可空 `dtcRecordId`。每次清码在发送命令前先写 `LocalDiagnosticActions(requested)`，收到响应后同事务更新最终状态并入 outbox，应用崩溃恢复时未完成项标为 `unknown`。

Drift schema 规则：

- 本地 UUID、父级 UUID 均存 `text`；时间统一存 UTC `DateTime`；readiness、冻结帧的 `pidValues`、AI `result` 和 outbox `payload` 存 JSON text，并由应用模型解码校验。
- ECU header/address 在解析入口统一去掉 `0x`、转大写并校验 2～8 位 hex；DTC 在同一会话按 `(sourceEcu, dtcCode, status)` 去重，不能把不同 ECU 的同码覆盖成一条。
- 每张可同步本地表都必须有 `localModifiedAt`、可空 `serverUpdatedAt`、`syncStatus`（`pending/synced/conflict/pendingDelete`）和可空 `deletedAt`。离线修改只更新 `localModifiedAt` 与 `syncStatus`；只有服务端响应可以写 `serverUpdatedAt`。不能把尚未上传的本地记录描述成“`updated_at` 由服务端生成”。
- 开启 `PRAGMA foreign_keys = ON`；外键动作与云端一致，普通删除仍使用 tombstone，不直接执行物理级联。
- `AppDatabase.schemaVersion` 每次表或索引变化递增；`MigrationStrategy.onCreate` 建全量 schema，`onUpgrade` 使用 Drift `Migrator` 按版本逐步迁移，不允许卸载重建用户数据库。
- 每次 migration 都要有“旧 schema fixture → 升级 → 行数/外键/关键字段不丢失”测试；开发期也禁止依赖 destructive migration。
- 大批量上传确认后，在一个事务内标记 outbox 已完成并写入新游标；失败只增加 `attempts/lastError`，不得回滚已经提交的本地诊断。
- 本地数据库按 Supabase `auth.uid()` 物理隔离：匿名账号也先取得 UID，再打开该 UID 专属的加密 DB 与独立密钥；文件名使用不可逆摘要/本地随机映射，不暴露原始 UID。Repository 只能持有当前账号的数据库句柄，禁止跨库联合查询。

### 3.1 本地数据库加密

- Drift 使用 `NativeDatabase.createInBackground` + `sqlite3`。在 workspace/app 根 `pubspec.yaml` 的 build hooks 配置 `sqlite3: source: sqlite3mc`，由 `sqlite3` 打包 SQLite3MultipleCiphers；**不另加 sqlite3mc Dart 包**。以 [Drift 官方 Encryption 指南](https://drift.simonbinder.eu/platforms/encryption/) 为实现基线。

  ```yaml
  hooks:
    user_defines:
      sqlite3:
        source: sqlite3mc
  ```

- `NativeDatabase` 的 `setup` 必须在设 key 和执行任何业务查询前运行 `PRAGMA cipher`。结果为空表示误链接了明文 SQLite：debug 与 release 都必须抛出启动错误并 fail closed，不能只用会在 release 被移除的 `assert`，更不能退回明文打开。确认 cipher 后才设置 `PRAGMA key`，随后用一个已知 schema 查询验证密钥正确。
- 每次安装生成独立随机数据库密钥，保存在 iOS Keychain / Android Keystore（可由 `flutter_secure_storage` 封装）；密钥不得写入 Dart 日志、崩溃上报、分析事件、`.env` 或源码。
- 每个 Supabase UID 使用独立密钥别名。登出、会话失效或切换账号时立即停止同步、关闭 Drift/SQLite 句柄并清除内存密钥；新账号只能打开自己的库。匿名账号绑定登录且 UID 不变时延续同一库；确需 UID 迁移时，必须在服务端所有权迁移成功后走受测的解密导出/重新加密事务。账号删除经用户确认后才删除该 UID 的数据库文件与 Keychain/Keystore 密钥。
- 数据库文件、WAL/SHM 和密钥均标记为不进入系统云备份。已同步数据可在重新认证后从 Supabase 恢复；若密钥丢失，不能尝试以明文打开原库，必须保留错误状态并由用户确认后重建本地缓存。尚未同步的数据无法从服务端恢复，UI 必须明确告知风险。
- 明文旧库迁移遵循官方临时副本流程：先 `VACUUM INTO` 一个 `.tmp` 副本，再用 sqlite3mc 对副本执行 `PRAGMA rekey`；用正确/错误密钥、行数、外键和 schema 校验副本后原子 rename。只有新加密库完整验证成功才删除旧库；崩溃后可从旧库或临时状态安全重试。
- 自动化测试必须覆盖：明文 SQLite 构建因无 `PRAGMA cipher` 被拒绝、错误密钥无法读取、正确密钥重开可读、明文旧库经临时副本/rekey 一次性迁移、schema migration 后仍可解密、密钥轮换的导出/重加密、迁移中断恢复、模拟损坏/密钥丢失后的受控恢复，以及日志中不出现密钥、原始 VIN 或车牌。还要执行“账号 A 写数据并登出 → 账号 B 登录”的隔离测试，证明 B 的 DAO、搜索、同步和备份均看不到 A 的任何本地行；切回 A 才能重新解锁 A 的库。

同步约定：

1. **离线 ID**：客户端创建记录时立即生成 UUIDv7，同一 ID 原样上传；严禁先上传再用服务端 ID 回填。
2. **原子 upsert**：按主键 `id` 使用 `insert ... on conflict do update` 或对应受控 RPC，不使用“先查再写”。`user_id`、父级 ID 创建后不可改。
3. **区分两套时钟**：`localModifiedAt` 只是设备内 outbox 排序依据，不参与跨设备胜负；云端 `created_at/updated_at/deleted_at` 由 PostgreSQL 生成，回包后写入本地 `serverUpdatedAt`。增量拉取游标为服务端 `(updated_at, id)`，避免同毫秒遗漏。
4. **并发冲突**：可编辑记录更新时携带上次同步的 `serverUpdatedAt`，使用条件更新；0 行更新表示版本冲突，本地置 `syncStatus=conflict` 并拉取服务端版本后提示合并。诊断、DTC、AI 结果视为不可变记录，只追加或软删除。
5. **软删除**：本地先置 `syncStatus=pendingDelete`；上传后由受控操作把云端 `deleted_at` 设为 PostgreSQL `now()`，回包再写本地 `deletedAt/serverUpdatedAt`。拉取必须包含 tombstone，至少保留 30 天后才可由后台任务硬删除。账号注销时允许依靠 `on delete cascade` 立即硬删除。
6. **游客升级**：匿名 Supabase 用户绑定邮箱/第三方登录时保留原 `auth.uid()`；若身份提供商导致 UID 变化，必须先走一次服务端所有权迁移事务，不能由客户端改 `user_id`。

---

## 4. 实体关系图（ERD）

```
profiles 1
├── * vehicles 1
│   ├── * diagnostic_records 1 ──── * dtc_records 1 ──── * ai_diagnoses
│   │        ├── * diagnostic_actions
│   │        └── * freeze_frames ──── 0..1 dtc_records（可选可信触发码）
│   ├── * maintenance_records
│   └── * maintenance_schedules
├── 0..1 subscription_entitlements
└── * ai_usage_events ──── 1 dtc_records / 0..1 ai_diagnoses
```

`ai_usage_events` 同时直接属于 `profiles`，并通过复合外键绑定所属 `dtc_records`；`revenuecat_webhook_events` 与 `account_deletion_jobs` 是无客户端访问权的服务端操作表，因此不放进用户 ERD。删除任务故意不以 FK 指向 `profiles/auth.users`，否则用户级联删除会把尚待 RevenueCat 清理的任务一起删掉。

---

## 5. RLS 策略（Row Level Security）

**原则**：所有表启用 RLS。匿名 Supabase Auth 用户与正式用户都属于 `authenticated` 角色；策略使用 `(select auth.uid())`，确保函数只计算一次。每张业务表都有直接 `user_id`，复合外键保证直接归属与父链归属一致：

| 表 | 归属链 |
|---|---|
| profiles | `profiles.id = auth.uid()` |
| vehicles | `vehicles.user_id → profiles.id` |
| diagnostic_records | `(vehicle_id, user_id) → vehicles(id, user_id)` |
| diagnostic_actions | `(diagnostic_record_id, vehicle_id, user_id) → diagnostic_records(...)` |
| dtc_records | `(diagnostic_record_id, vehicle_id, user_id) → diagnostic_records(...)` |
| freeze_frames | 必须 `(diagnostic_record_id, vehicle_id, user_id) → diagnostic_records(...)`；可空 DTC 复合 FK 还验证同会话/车辆/用户 |
| ai_diagnoses | `(dtc_record_id, user_id) → dtc_records(id, user_id)` |
| maintenance_records / schedules | `(vehicle_id, user_id) → vehicles(id, user_id)` |
| subscription_entitlements | `user_id → profiles.id`，客户端只读 |
| ai_usage_events | `(dtc_record_id, user_id) → dtc_records(id, user_id)`，客户端只读 |
| revenuecat_webhook_events | 服务端收件箱；启用 RLS 但不给 `authenticated`/`anon` 任何 policy 或表权限 |
| account_deletion_jobs | 服务端耐久任务；启用 RLS 但不给 `authenticated`/`anon` 任何 policy 或表权限，完成后按短期审计保留策略清理 |

初始迁移必须实际创建策略，而不是只保留注释示例：

```sql
alter table public.profiles enable row level security;
alter table public.vehicles enable row level security;
alter table public.diagnostic_records enable row level security;
alter table public.diagnostic_actions enable row level security;
alter table public.dtc_records enable row level security;
alter table public.freeze_frames enable row level security;
alter table public.ai_diagnoses enable row level security;
alter table public.maintenance_records enable row level security;
alter table public.maintenance_schedules enable row level security;
alter table public.subscription_entitlements enable row level security;
alter table public.revenuecat_webhook_events enable row level security;
alter table public.account_deletion_jobs enable row level security;
alter table public.ai_usage_events enable row level security;

create policy profiles_owner_select on public.profiles for select to authenticated
  using ((select auth.uid()) = id);
create policy profiles_owner_update on public.profiles for update to authenticated
  using ((select auth.uid()) = id)
  with check ((select auth.uid()) = id);

create policy vehicles_owner_select on public.vehicles for select to authenticated
  using ((select auth.uid()) = user_id);
create policy vehicles_owner_update on public.vehicles for update to authenticated
  using ((select auth.uid()) = user_id)
  with check ((select auth.uid()) = user_id);
create policy diagnostic_records_owner_select on public.diagnostic_records for select to authenticated
  using ((select auth.uid()) = user_id);
create policy diagnostic_actions_owner_select on public.diagnostic_actions for select to authenticated
  using ((select auth.uid()) = user_id);
create policy dtc_records_owner_select on public.dtc_records for select to authenticated
  using ((select auth.uid()) = user_id);
create policy freeze_frames_owner_select on public.freeze_frames for select to authenticated
  using ((select auth.uid()) = user_id);
create policy maintenance_records_owner_select on public.maintenance_records for select to authenticated
  using ((select auth.uid()) = user_id);
create policy maintenance_schedules_owner_select on public.maintenance_schedules for select to authenticated
  using ((select auth.uid()) = user_id);

create policy ai_diagnoses_owner_select on public.ai_diagnoses for select to authenticated
  using ((select auth.uid()) = user_id);
create policy subscription_entitlements_owner_select on public.subscription_entitlements for select to authenticated
  using ((select auth.uid()) = user_id);
create policy ai_usage_events_owner_select on public.ai_usage_events for select to authenticated
  using ((select auth.uid()) = user_id);
```

RLS 只解决“这是谁的数据”，不能安全表达车辆数、Pro 提醒、历史条数等付费约束。迁移还必须收紧表权限：

```sql
-- 受限写入只能走下节的 SECURITY DEFINER 函数；函数固定 search_path 并校验 user_id。
revoke insert, delete, update on public.profiles, public.vehicles from authenticated;
revoke insert, update, delete on public.diagnostic_records, public.diagnostic_actions,
  public.dtc_records, public.freeze_frames from authenticated;
revoke insert, update, delete on public.maintenance_records, public.maintenance_schedules from authenticated;
revoke insert, update, delete on public.ai_diagnoses,
  public.subscription_entitlements, public.ai_usage_events from authenticated;
revoke all on public.revenuecat_webhook_events from anon, authenticated;
revoke all on public.account_deletion_jobs from anon, authenticated;

grant select on public.profiles, public.vehicles, public.diagnostic_records, public.diagnostic_actions,
  public.dtc_records, public.freeze_frames,
  public.ai_diagnoses, public.maintenance_records, public.maintenance_schedules,
  public.subscription_entitlements, public.ai_usage_events to authenticated;
grant update(display_name, locale, unit_system) on public.profiles to authenticated;
grant update(vin, year, make, model, engine, transmission, mileage_miles, license_plate, nickname)
  on public.vehicles to authenticated;
```

`SECURITY DEFINER` 函数必须 `set search_path = ''`、全部使用 schema 限定名、从验证后的 JWT 或服务端参数确定用户、并只向所需角色授予 `execute`；不得接受客户端提供的任意 `user_id`。

---

## 6. 免费/Pro 层级与数据库强制约束

| 约束 | Free | Pro |
|---|---|---|
| 车辆数 | ≤ 1 | 无限 |
| 诊断历史 | 最近 10 条 | 无限 |
| AI 解读 | **完整结果 1 次** | 按连续 30 天额度窗口 |
| 保养记录与提醒 | ✗ | ✓ |

V1 只支持 Free 与 RevenueCat `pro` 订阅；OneTime 为 **V1.1**，V1 schema 和权限判断不得把 OneTime 当作已上线 entitlement。

数据库迁移必须提供以下受控函数/触发器，Edge Function 与 Flutter 调用这些入口，不能仅靠 UI 隐藏：

| 入口 | 数据库事务内的强制行为 |
|---|---|
| `create_vehicle(...)` | 锁定用户 entitlement/资料行；Free 统计 `deleted_at is null` 的车辆，已有 1 辆则拒绝；Pro 可创建。|
| `sync_diagnostic_batch(...)` | 校验车辆归属后原子 upsert 会话（含诊断时里程和 readiness 快照）、清码 action、DTC 与多 ECU/multi-frame `freeze_frames`；每帧必须绑定会话/车辆，触发 DTC 不可信/缺失时保持空。Free 上传完成后把超出最近 10 条的云端会话及其 action/DTC/freeze frame/AI 子记录在同一事务置为软删除，Pro 不裁剪。客户端 Free 查询同样只展示最近 10 条。|
| `upsert_maintenance_record(...)` | 只允许当前有效 Pro 新增/修改保养记录，并校验车辆归属；Free 拒绝。|
| `upsert_maintenance_schedule(...)` | 只允许当前有效 Pro 写入；Free 拒绝。|
| `reserve_ai_usage(user_id, idempotency_key, request_hash, dtc_record_id)` | 仅供 `service_role` 的 AI Edge Function 调用。相同 key 先比较规范化请求的 SHA-256 `request_hash`：不同则 409，相同则返回原 usage/结果。随后锁定 entitlement 行并清理该用户超时预留。非 Pro 必须检查永久 `free_ai_trial_consumed_at is null`，预生成 usage ID 后在同一事务写入 `free_ai_trial_consumed_at=now()`、`free_ai_trial_reservation_id=usage.id` 与 `free_trial` event；仅靠会随历史清理的 usage partial unique 不足以保护终身一次。Pro 若跨过 `quota_window_ends_at`，先按连续 30 天步长推进窗口、清零用量，再检查/递增。|
| `finalize_ai_usage(usage_id, success, cache_hit, ai_diagnosis_id)` | 仅供 `service_role`；仅未过期的 `reserved` 可成功完成。Free 成功时保留 `free_ai_trial_consumed_at` 并仅清空匹配的 reservation ID；Free 失败/超时时只有 `free_ai_trial_reservation_id=usage_id` 才能把两个字段清空。Pro 成功置 `completed`，失败/超时置 `released` 并幂等退回计数。只有返回了符合 07 契约的完整结果才算成功。|
| `release_expired_ai_reservations()` | 定时任务调用，并由每次 reserve 兜底。对每个超时 usage 先按 `(user_id,idempotency_key)` 查 `ai_diagnoses`：结果已存在则补链并置 `completed`；不存在才置 `released`，按匹配 reservation ID 释放 Free 标记或退回 Pro 次数。确保 Edge 在“结果插入后、finalize 前”崩溃也不会重复结果、重复扣费或永久占额度。|
| RevenueCat webhook / `refresh_entitlement(...)` | 仅供服务端；按 RevenueCat `app_user_id = Supabase auth.uid()` 更新 `product_id/store/period_started_at/expires_at/grace_expires_at` 与状态。V1 只有产品 ID 命中月/年订阅 allowlist，且正常到期或 grace 尚未结束时才写为可用 Pro；空 expiry 的 lifetime/OneTime 不放行。首次 Pro 激活时用服务端 policy 初始化 30 天 quota window；RevenueCat 月/年续订本身**不重置** AI 用量。|

Webhook 先以 RevenueCat `event.id` + 原始 body SHA-256 插入 `revenuecat_webhook_events`。同 ID/同 hash 重试直接返回已处理结果，同 ID/不同 hash 作为安全冲突拒绝。事件 delta 可能乱序，不能直接增减 entitlement；收件后必须用事件的 `app_user_id` 拉取当前 Customer Info，再在短事务调用 `refresh_entitlement(...)`，最后标记 processed。失败只记录稳定错误码，不保存完整 webhook payload，并允许 RevenueCat 重试。

AI Edge 写结果必须使用 `insert ... on conflict (user_id, idempotency_key) do nothing returning id`；冲突时读取既有行并补做幂等 finalize，形成 exactly-once 结果。HTTP `request_id` 仅是每次尝试的 trace ID，不写入幂等唯一键，也不能替代 `Idempotency-Key`。

所有外部网络调用（RevenueCat、LLM）必须在数据库事务之外完成；数据库锁只覆盖额度预留/完成的短事务。V1 Pro 限额由服务端 `PRO_AI_QUOTA_PER_30_DAYS` policy 配置，不在本文写死产品数值。30 天窗口从首次 Pro 激活时锚定并连续推进，使月订阅与年订阅获得相同补给节奏；订阅中断后重新激活可建立新窗口。AI 完整结果即使来自缓存也占用一次产品额度，因为用户获得了完整 AI 诊断；重复查看已保存的历史结果不调用 `/ai-diagnose`，不再次计数。

---

## 7. Migration / 数据层验收

- 空数据库可一次执行初始 migration；创建正式与匿名 `auth.users` 后都自动产生 profile 和 Free entitlement。
- 对每个 `not null/check/FK/unique` 写正反例；删除测试同时覆盖应用软删除和账号 `on delete cascade` 硬删除。
- 用两个用户验证所有表 RLS：自己的行可读、跨用户 ID 返回空；受限表的直接写入被 privilege 拒绝，RPC 仍只能操作调用者的归属链。
- 并发调用 `create_vehicle`、`reserve_ai_usage`、连续 30 天窗口额度预留，证明 Free 不会出现第 2 辆车/第 2 次试用，Pro 不会超过 `ai_quota_limit`；同 idempotency key + 不同 hash 返回 409；失败/重复 finalize 不会多退额度；分别模拟结果落库前后 Edge 崩溃，证明重试只保存一条 diagnosis 且 usage 最终一致。成功 Free 试用后软删并最终硬删诊断/DTC/diagnosis/usage 历史，`free_ai_trial_consumed_at` 仍保留并拒绝第二次试用；只有账号删除会清掉它。
- 用 `EXPLAIN` 检查 RLS `user_id`、复合父链 FK、级联删除和最新历史查询命中对应索引。
- Drift 使用旧版本加密 fixture 做逐版升级，验证业务行、outbox、`localModifiedAt/serverUpdatedAt/syncStatus`、外键、tombstone 和同步游标都保留；禁止以删库重建作为 migration 通过标准。
- Freeze Frame 测试覆盖同会话多 ECU/多 frame、可信 DTC 关联、PID 02 不返回触发 DTC 时 `dtc_record_id=null`、跨会话/跨车辆/跨用户关联被复合 FK 拒绝，以及 session/ECU/frame active 去重。
- RevenueCat webhook 测试覆盖合法请求、伪造 Authorization、超限 body、同 event ID 同/不同 hash、重复投递、乱序事件和 Customer Info 上游失败重试；重复/乱序都必须收敛到当前 Customer Info，而不是按旧事件 delta 回滚权益。
- 账号删除测试覆盖同 idempotency key + 同 request hash 重试只建一个 job、同 key + 不同 hash 返回 409、同用户不同 key 并发也只产生一个 active job 并返回既有 job、用户数据/auth 行级联删除后 job 仍存在、RevenueCat 删除暂时失败的指数退避恢复，以及完成后只按隐私保留策略保存防重建所需的最小 tombstone；webhook 按 `revenuecat_app_user_id` 查询须命中索引，不得把删除 RevenueCat customer 当作取消 App Store/Play Store 订阅。
