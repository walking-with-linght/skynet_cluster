# WebSocket 通信包格式说明

本文档详细说明 WebSocket 通信包的字段结构和含义。

---

## 一、通信包类型

根据代码分析，系统中有三种类型的通信包：

1. **客户端请求包** (`ReqBody`) - 客户端发送给服务器
2. **服务器响应包** (`RspBody`) - 服务器响应客户端请求
3. **服务器推送包** (`RspBody`) - 服务器主动推送给客户端

---

## 二、客户端请求包 (ReqBody)

### 2.1 结构定义

```go
type ReqBody struct {
    Seq     int64       `json:"seq"`      // 序列号
    Name    string      `json:"name"`      // 协议名
    Msg     interface{} `json:"msg"`       // 协议内容
    Proxy   string      `json:"proxy"`    // 代理地址（可选）
}
```

### 2.2 字段说明

#### `seq` (序列号)
- **类型**: `int64`
- **必填**: 是
- **说明**: 
  - 客户端生成的唯一序列号，用于匹配请求和响应
  - 每个请求都会分配一个递增的序列号
  - 服务器响应时必须使用相同的 `seq` 值
  - **推送消息的 `seq` 为 0**，用于区分请求响应和推送

#### `name` (协议名)
- **类型**: `string`
- **必填**: 是
- **说明**: 
  - 协议路由名称，格式通常为 `模块.操作`
  - 例如：`role.enterServer`、`chat.login`、`army.assign`
  - 用于路由到对应的处理函数

#### `msg` (协议内容)
- **类型**: `interface{}` (实际为 JSON 对象)
- **必填**: 是
- **说明**: 
  - 具体的请求数据，根据不同的协议有不同的结构
  - 例如登录请求：`{"username": "xxx", "password": "xxx"}`
  - 例如发送聊天：`{"type": 0, "msg": "消息内容"}`

#### `proxy` (代理地址)
- **类型**: `string`
- **必填**: 否（可选字段）
- **说明**: 
  - 仅在通过 **gateserver** 转发时使用
  - 用于指定目标服务器地址（如 `ws://127.0.0.1:8001`）
  - 如果为空，gateserver 会根据 `name` 的前缀自动路由：
    - `account.*` → loginserver
    - `chat.*` → chatserver
    - 其他 → slgserver
  - **客户端直接连接业务服务器时不需要此字段**

### 2.3 请求包示例

#### 示例1：登录请求（通过 gateserver）
```json
{
  "seq": 1,
  "name": "account.login",
  "msg": {
    "username": "testuser",
    "password": "123456",
    "ip": "192.168.1.1",
    "hardware": "device123"
  },
  "proxy": ""  // gateserver 会根据 name 自动路由
}
```

#### 示例2：进入游戏服务器（直接连接）
```json
{
  "seq": 2,
  "name": "role.enterServer",
  "msg": {
    "session": "eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9..."
  }
}
```

#### 示例3：发送聊天消息
```json
{
  "seq": 3,
  "name": "chat.chat",
  "msg": {
    "type": 0,
    "msg": "大家好！"
  }
}
```

---

## 三、服务器响应包 (RspBody)

### 3.1 结构定义

```go
type RspBody struct {
    Seq     int64       `json:"seq"`      // 序列号（与请求一致）
    Name    string      `json:"name"`      // 协议名（与请求一致）
    Code    int         `json:"code"`      // 错误码（0=成功）
    Msg     interface{} `json:"msg"`       // 响应数据
}
```

### 3.2 字段说明

#### `seq` (序列号)
- **类型**: `int64`
- **必填**: 是
- **说明**: 
  - **必须与对应请求的 `seq` 值完全一致**
  - 客户端通过 `seq` 匹配请求和响应
  - 如果 `seq == 0`，表示这是推送消息，不是响应

#### `name` (协议名)
- **类型**: `string`
- **必填**: 是
- **说明**: 
  - 与请求的 `name` 保持一致
  - 用于客户端识别这是哪个协议的响应

#### `code` (错误码)
- **类型**: `int`
- **必填**: 是
- **说明**: 
  - `0` 表示成功
  - 非 `0` 表示错误，具体错误码定义在 `constant/code.go`
  - 常见错误码：
    - `1`: 参数错误 (InvalidParam)
    - `2`: 数据库错误 (DBError)
    - `4`: 密码不正确 (PwdIncorrect)
    - `16`: 资源不足 (ResNotEnough)
    - 等等...

#### `msg` (响应数据)
- **类型**: `interface{}` (实际为 JSON 对象或 null)
- **必填**: 是（即使错误也可能返回部分数据）
- **说明**: 
  - 成功时：包含响应数据
  - 失败时：可能为 `null` 或包含部分错误信息

### 3.3 响应包示例

#### 示例1：登录成功响应
```json
{
  "seq": 1,
  "name": "account.login",
  "code": 0,
  "msg": {
    "username": "testuser",
    "password": "123456",
    "session": "eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9...",
    "uid": 12345
  }
}
```

#### 示例2：登录失败响应
```json
{
  "seq": 1,
  "name": "account.login",
  "code": 4,
  "msg": null
}
```

#### 示例3：进入游戏服务器响应
```json
{
  "seq": 2,
  "name": "role.enterServer",
  "code": 0,
  "msg": {
    "role": {
      "rid": 1001,
      "uid": 12345,
      "nickName": "玩家昵称",
      "sex": 0,
      "balance": 0,
      "headId": 1,
      "profile": ""
    },
    "role_res": {
      "wood": 1000,
      "iron": 1000,
      "stone": 1000,
      "grain": 1000,
      "gold": 1000,
      "decree": 10
    },
    "time": 1234567890123,
    "token": "new_session_token"
  }
}
```

---

## 四、服务器推送包 (RspBody)

### 4.1 结构定义

推送包使用与响应包相同的 `RspBody` 结构，但有以下区别：

```go
type RspBody struct {
    Seq     int64       `json:"seq"`      // 固定为 0
    Name    string      `json:"name"`      // 推送协议名
    Code    int         `json:"code"`      // 通常为 0
    Msg     interface{} `json:"msg"`       // 推送数据
}
```

### 4.2 字段说明

#### `seq` (序列号)
- **类型**: `int64`
- **值**: **固定为 `0`**
- **说明**: 
  - `seq == 0` 是推送消息的唯一标识
  - 客户端通过 `seq == 0` 判断这是推送消息，不是响应
  - 推送消息不需要匹配请求，是服务器主动发送

#### `name` (推送协议名)
- **类型**: `string`
- **必填**: 是
- **说明**: 
  - 推送协议名称，格式通常为 `模块.push`
  - 例如：`chat.push`、`roleRes.push`、`army.push`
  - 用于客户端识别推送类型

#### `code` (错误码)
- **类型**: `int`
- **值**: 通常为 `0`
- **说明**: 推送消息通常表示成功，所以 `code` 一般为 `0`

#### `msg` (推送数据)
- **类型**: `interface{}` (实际为 JSON 对象)
- **必填**: 是
- **说明**: 推送的具体数据内容

### 4.3 推送包示例

#### 示例1：聊天消息推送
```json
{
  "seq": 0,
  "name": "chat.push",
  "code": 0,
  "msg": {
    "rid": 1001,
    "nickName": "玩家A",
    "type": 0,
    "msg": "大家好！",
    "time": 1234567890
  }
}
```

#### 示例2：资源更新推送
```json
{
  "seq": 0,
  "name": "roleRes.push",
  "code": 0,
  "msg": {
    "wood": 1500,
    "iron": 1200,
    "stone": 1300,
    "grain": 1400,
    "gold": 1100,
    "decree": 8
  }
}
```

#### 示例3：军队移动推送
```json
{
  "seq": 0,
  "name": "army.push",
  "code": 0,
  "msg": {
    "id": 1,
    "cityId": 1,
    "order": 1,
    "cmd": 1,
    "state": 0,
    "from_x": 100,
    "from_y": 200,
    "to_x": 150,
    "to_y": 250,
    "start": 1234567890,
    "end": 1234567900
  }
}
```

---

## 五、通信流程

### 5.1 请求-响应流程

```
客户端                          服务器
  |                              |
  |--- seq:1, name:"role.enterServer" --->|
  |                              | 处理请求
  |                              |
  |<-- seq:1, name:"role.enterServer", code:0 ---|
  |                              |
```

**关键点**：
- 请求和响应的 `seq` 必须一致
- 请求和响应的 `name` 必须一致
- 客户端通过 `seq` 匹配响应

### 5.2 推送流程

```
服务器                          客户端
  |                              |
  |--- seq:0, name:"chat.push" --->|
  |                              | 处理推送
  |                              |
```

**关键点**：
- `seq` 固定为 `0`，表示推送
- 不需要客户端响应
- 客户端通过 `seq == 0` 识别推送

### 5.3 Gateserver 转发流程

```
客户端        Gateserver        业务服务器
  |              |                  |
  |-- ReqBody -->|                  |
  |              |-- ReqBody ------>|
  |              |                  | 处理
  |              |<-- RspBody ------|
  |<-- RspBody --|                  |
  |              |                  |
```

**关键点**：
- Gateserver 根据 `name` 前缀或 `proxy` 字段路由
- Gateserver 保持 `seq` 不变，确保客户端能正确匹配

---

## 六、特殊协议

### 6.1 握手协议 (Handshake)

**请求**（服务器主动发送）:
```json
{
  "seq": 0,
  "name": "handshake",
  "code": 0,
  "msg": {
    "key": "16位随机字符串"  // 加密密钥（如果 needSecret=true）
  }
}
```

**说明**：
- 连接建立后，如果服务器需要加密（`needSecret=true`），会主动发送握手协议
- 客户端收到后，保存 `key`，后续通信使用此密钥加密/解密
- 如果 `key` 为空字符串，表示不需要加密

### 6.2 心跳协议 (Heartbeat)

**请求**:
```json
{
  "seq": 123,
  "name": "heartbeat",
  "msg": {
    "ctime": 1234567890123  // 客户端时间戳（毫秒）
  }
}
```

**响应**:
```json
{
  "seq": 123,
  "name": "heartbeat",
  "code": 0,
  "msg": {
    "ctime": 1234567890123,  // 客户端时间戳
    "stime": 1234567890456   // 服务器时间戳（毫秒）
  }
}
```

---

## 七、数据加密和压缩

### 7.1 加密

- **算法**: AES-CBC
- **密钥**: 握手协议中的 `key`（16位字符串）
- **填充**: ZEROS_PADDING
- **触发条件**: 服务器配置 `needSecret=true` 时启用

### 7.2 压缩

- **算法**: gzip
- **位置**: 加密后进行压缩
- **格式**: WebSocket BinaryMessage

### 7.3 数据流

```
原始数据 → JSON序列化 → AES加密 → gzip压缩 → WebSocket发送
```

接收时反向：
```
WebSocket接收 → gzip解压 → AES解密 → JSON反序列化 → 原始数据
```

---

## 八、字段总结表

| 字段 | 请求包 | 响应包 | 推送包 | 说明 |
|------|--------|--------|--------|------|
| `seq` | ✅ 客户端生成递增 | ✅ 与请求一致 | ✅ 固定为 0 | 序列号，用于匹配 |
| `name` | ✅ 协议路由名 | ✅ 与请求一致 | ✅ 推送协议名 | 协议标识 |
| `msg` | ✅ 请求数据 | ✅ 响应数据 | ✅ 推送数据 | 具体内容 |
| `proxy` | ✅ 可选 | ❌ | ❌ | 代理地址（仅 gateserver） |
| `code` | ❌ | ✅ 错误码 | ✅ 通常为 0 | 状态码 |

---

## 九、注意事项

1. **序列号管理**：
   - 客户端必须为每个请求生成唯一的递增序列号
   - 服务器响应时必须保持 `seq` 不变
   - `seq == 0` 专门用于推送消息

2. **协议名格式**：
   - 格式：`模块.操作`，如 `role.enterServer`
   - 推送格式：`模块.push`，如 `chat.push`

3. **错误处理**：
   - `code == 0` 表示成功
   - `code != 0` 表示错误，需要根据错误码处理
   - 即使错误，`msg` 字段也可能包含部分数据

4. **推送识别**：
   - 客户端必须检查 `seq == 0` 来识别推送消息
   - 推送消息不需要响应

5. **Gateserver 路由**：
   - 如果 `proxy` 为空，gateserver 根据 `name` 前缀自动路由
   - 客户端通常不需要设置 `proxy` 字段

---

**文档版本**: 1.0  
**最后更新**: 2024

