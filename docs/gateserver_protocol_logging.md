# Gateserver 协议日志说明

本文档说明 gateserver 中添加的协议日志功能。

---

## 一、功能概述

Gateserver 作为通信总入口，现在会记录所有经过的协议消息，包括：
- 客户端发送的请求
- 发送给客户端的响应
- 转发到业务服务器的请求
- 从业务服务器收到的响应
- 服务器推送的消息

---

## 二、日志记录位置

### 2.1 收到客户端请求

**位置**: `server/gateserver/controller/handle.go:130` (`all` 方法)

**日志格式**:
```
[GATESERVER] 收到客户端请求
- protocol: 协议名（如 "role.enterServer"）
- seq: 序列号
- proxy: 代理地址（如果有）
- cid: 连接ID
- msg: 请求消息内容（JSON格式）
- direction: "client->server"
```

**示例**:
```
[GATESERVER] 收到客户端请求 protocol=role.enterServer seq=1 proxy= cid=12345 msg={"session":"xxx"} direction=client->server
```

---

### 2.2 发送客户端响应

**位置**: `server/gateserver/controller/handle.go:154` (`all` 方法)

**日志格式**:
```
[GATESERVER] 发送客户端响应
- protocol: 协议名
- seq: 序列号（与请求一致）
- code: 错误码（0=成功）
- msg: 响应消息内容（JSON格式）
- direction: "server->client"
```

**示例**:
```
[GATESERVER] 发送客户端响应 protocol=role.enterServer seq=1 code=0 msg={"role":{...},"role_res":{...}} direction=server->client
```

---

### 2.3 转发到业务服务器

**位置**: `server/gateserver/controller/handle.go:222` (`deal` 方法)

**日志格式**:
```
[GATESERVER] 转发到业务服务器
- protocol: 协议名
- seq: 序列号
- target: 目标服务器地址（如 "ws://127.0.0.1:8001"）
- msg: 请求消息内容（JSON格式）
- direction: "gate->business"
```

**示例**:
```
[GATESERVER] 转发到业务服务器 protocol=role.enterServer seq=1 target=ws://127.0.0.1:8001 msg={"session":"xxx"} direction=gate->business
```

---

### 2.4 收到业务服务器响应

**位置**: `server/gateserver/controller/handle.go:238` (`deal` 方法)

**日志格式**:
```
[GATESERVER] 收到业务服务器响应
- protocol: 协议名
- seq: 序列号
- code: 错误码
- target: 来源服务器地址
- msg: 响应消息内容（JSON格式）
- direction: "business->gate"
```

**示例**:
```
[GATESERVER] 收到业务服务器响应 protocol=role.enterServer seq=1 code=0 target=ws://127.0.0.1:8001 msg={"role":{...}} direction=business->gate
```

---

### 2.5 业务服务器响应错误

**位置**: `server/gateserver/controller/handle.go:249` (`deal` 方法)

**日志格式**:
```
[GATESERVER] 业务服务器响应错误
- protocol: 协议名
- seq: 序列号
- target: 目标服务器地址
- error: 错误信息
- direction: "business->gate"
```

**示例**:
```
[GATESERVER] 业务服务器响应错误 protocol=role.enterServer seq=1 target=ws://127.0.0.1:8001 error=connection closed direction=business->gate
```

---

### 2.6 服务器推送消息

**位置**: `server/gateserver/controller/handle.go:79` (`onPush` 方法)

**日志格式**:
```
[GATESERVER] 推送协议
- protocol: 推送协议名（如 "chat.push"）
- seq: 序列号（固定为0）
- code: 错误码（通常为0）
- msg: 推送消息内容（JSON格式）
- direction: "server->client"
```

**示例**:
```
[GATESERVER] 推送协议 protocol=chat.push seq=0 code=0 msg={"rid":123,"msg":"hello"} direction=server->client
```

---

## 三、日志字段说明

### 3.1 通用字段

| 字段 | 类型 | 说明 |
|------|------|------|
| `protocol` | string | 协议名称（如 "role.enterServer"） |
| `seq` | int64 | 序列号（推送消息为0） |
| `code` | int | 错误码（0=成功） |
| `msg` | string | 消息内容（JSON格式字符串） |
| `direction` | string | 消息方向 |

### 3.2 方向标识

| 方向 | 说明 |
|------|------|
| `client->server` | 客户端发送给服务器 |
| `server->client` | 服务器发送给客户端 |
| `gate->business` | 网关转发到业务服务器 |
| `business->gate` | 业务服务器响应给网关 |

### 3.3 特殊字段

| 字段 | 出现位置 | 说明 |
|------|---------|------|
| `cid` | 客户端请求 | 连接ID |
| `proxy` | 客户端请求 | 代理地址（可选） |
| `target` | 转发/响应 | 目标/来源服务器地址 |
| `error` | 错误日志 | 错误信息 |

---

## 四、日志示例

### 4.1 完整的请求-响应流程

```
[GATESERVER] 收到客户端请求 protocol=role.enterServer seq=1 proxy= cid=12345 msg={"session":"xxx"} direction=client->server
[GATESERVER] 转发到业务服务器 protocol=role.enterServer seq=1 target=ws://127.0.0.1:8001 msg={"session":"xxx"} direction=gate->business
[GATESERVER] 收到业务服务器响应 protocol=role.enterServer seq=1 code=0 target=ws://127.0.0.1:8001 msg={"role":{...}} direction=business->gate
[GATESERVER] 发送客户端响应 protocol=role.enterServer seq=1 code=0 msg={"role":{...}} direction=server->client
```

### 4.2 推送消息流程

```
[GATESERVER] 推送协议 protocol=chat.push seq=0 code=0 msg={"rid":123,"msg":"hello"} direction=server->client
```

### 4.3 错误流程

```
[GATESERVER] 收到客户端请求 protocol=role.enterServer seq=1 proxy= cid=12345 msg={"session":"xxx"} direction=client->server
[GATESERVER] 转发到业务服务器 protocol=role.enterServer seq=1 target=ws://127.0.0.1:8001 msg={"session":"xxx"} direction=gate->business
[GATESERVER] 业务服务器响应错误 protocol=role.enterServer seq=1 target=ws://127.0.0.1:8001 error=connection closed direction=business->gate
[GATESERVER] 发送客户端响应 protocol=role.enterServer seq=1 code=-4 msg=null direction=server->client
```

---

## 五、日志配置

### 5.1 日志级别

所有协议日志使用 `Info` 级别，错误日志使用 `Error` 级别。

### 5.2 日志输出

日志会输出到配置的日志文件中（`data/conf/env.ini` 中的 `[log]` 配置）。

**日志文件**: `bin/logs/gateserver.log`

### 5.3 日志格式

使用 zap 结构化日志，格式为：
```
时间戳 级别 [GATESERVER] 操作类型 protocol=xxx seq=xxx ...
```

---

## 六、使用建议

### 6.1 调试协议问题

通过日志可以：
1. 查看客户端发送了什么协议
2. 查看协议转发到了哪个服务器
3. 查看业务服务器的响应
4. 查看最终返回给客户端的内容
5. 查看推送消息

### 6.2 性能分析

可以通过日志分析：
- 协议处理时间（结合现有的 `ElapsedTime` 中间件）
- 协议转发路径
- 错误发生频率

### 6.3 协议追踪

通过 `seq` 和 `protocol` 字段，可以追踪一个完整的请求-响应流程。

---

## 七、注意事项

1. **日志量**: 协议日志会产生大量日志，注意日志文件大小
2. **敏感信息**: 日志中包含完整的协议内容，注意保护敏感信息（如密码、token）
3. **性能影响**: JSON序列化可能影响性能，如果性能敏感，可以考虑异步日志
4. **日志过滤**: 可以使用日志工具过滤特定协议或方向的消息

---

## 八、日志过滤示例

如果需要过滤特定协议的日志，可以使用 grep：

```bash
# 只看某个协议的日志
grep "protocol=role.enterServer" bin/logs/gateserver.log

# 只看客户端请求
grep "direction=client->server" bin/logs/gateserver.log

# 只看推送消息
grep "seq=0" bin/logs/gateserver.log

# 只看错误
grep "业务服务器响应错误" bin/logs/gateserver.log
```

---

**文档版本**: 1.0  
**最后更新**: 2024

