# ChatServer 协议文档

本文档整理了 chatserver 进程所需的所有协议定义，用于重构到 skynet 框架。

## 一、协议概述

ChatServer 提供聊天服务，支持两种聊天频道：
- **世界聊天**（Type = 0）：所有玩家可见的公共频道
- **联盟聊天**（Type = 1）：特定联盟成员可见的频道

## 二、客户端请求协议

所有客户端请求通过 gateserver 转发，消息路由格式为：`chat.{action}`

### 1. 登录聊天服务器

**路由**: `chat.login`

**请求协议**:
```go
type LoginReq struct {
    RId      int    `json:"rid"`       // 角色ID
    NickName string `json:"nickName"`   // 昵称
    Token    string `json:"token"`     // 会话令牌（用于验证）
}
```

**响应协议**:
```go
type LoginRsp struct {
    RId      int    `json:"rid"`       // 角色ID
    NickName string `json:"nickName"`   // 昵称
}
```

**功能说明**:
- 验证 token 有效性
- 将用户加入世界聊天频道
- 建立连接与角色ID的映射关系

**错误码**:
- `InvalidParam (1)`: token 无效或 rid 不匹配

---

### 2. 登出聊天服务器

**路由**: `chat.logout`

**请求协议**:
```go
type LogoutReq struct {
    RId int `json:"RId"`  // 角色ID
}
```

**响应协议**:
```go
type LogoutRsp struct {
    RId int `json:"RId"`  // 角色ID
}
```

**功能说明**:
- 从世界聊天频道移除用户
- 从联盟聊天频道移除用户（如果已加入）
- 清除连接与角色ID的映射关系

---

### 3. 发送聊天消息

**路由**: `chat.chat`

**请求协议**:
```go
type ChatReq struct {
    Type int8  `json:"type"`  // 聊天类型：0=世界聊天，1=联盟聊天
    Msg  string `json:"msg"`  // 消息内容
}
```

**响应协议**:
```go
type ChatMsg struct {
    RId      int    `json:"rid"`       // 发送者角色ID
    NickName string `json:"nickName"`   // 发送者昵称
    Type     int8   `json:"type"`      // 聊天类型：0=世界聊天，1=联盟聊天
    Msg      string `json:"msg"`       // 消息内容
    Time     int64  `json:"time"`      // 时间戳（Unix时间戳）
}
```

**功能说明**:
- 将消息添加到对应频道的消息队列（最多保存100条）
- 向频道内所有在线用户推送消息（通过 `chat.push` 协议）
- 返回发送的消息信息

**注意事项**:
- 如果用户不在对应的联盟聊天组中，消息不会发送

---

### 4. 获取历史消息

**路由**: `chat.history`

**请求协议**:
```go
type HistoryReq struct {
    Type int8 `json:"type"`  // 聊天类型：0=世界聊天，1=联盟聊天
}
```

**响应协议**:
```go
type HistoryRsp struct {
    Type int8       `json:"type"`  // 聊天类型：0=世界聊天，1=联盟聊天
    Msgs []ChatMsg  `json:"msgs"`  // 历史消息列表
}
```

**功能说明**:
- 返回指定频道的历史消息（最多100条）
- 世界聊天：返回世界频道历史
- 联盟聊天：返回用户所在联盟的历史消息

---

### 5. 加入联盟聊天组

**路由**: `chat.join`

**请求协议**:
```go
type JoinReq struct {
    Type int8 `json:"type"`  // 聊天类型：固定为 1（联盟聊天）
    Id   int  `json:"id"`    // 联盟ID
}
```

**响应协议**:
```go
type JoinRsp struct {
    Type int8 `json:"type"`  // 聊天类型：固定为 1
    Id   int  `json:"id"`    // 联盟ID
}
```

**功能说明**:
- 将用户加入指定联盟的聊天组
- 如果用户已加入其他联盟聊天组，会自动退出旧组并加入新组
- 如果联盟聊天组不存在，会自动创建

**错误码**:
- `InvalidParam (1)`: 用户不在世界聊天频道中（必须先登录）

---

### 6. 退出联盟聊天组

**路由**: `chat.exit`

**请求协议**:
```go
type ExitReq struct {
    Type int8 `json:"type"`  // 聊天类型：固定为 1（联盟聊天）
    Id   int  `json:"id"`    // 联盟ID
}
```

**响应协议**:
```go
type ExitRsp struct {
    Type int8 `json:"type"`  // 聊天类型：固定为 1
    Id   int  `json:"id"`    // 联盟ID
}
```

**功能说明**:
- 将用户从指定联盟的聊天组中移除
- 清除用户与联盟的映射关系

---

## 三、服务器推送协议

### 1. 聊天消息推送

**路由**: `chat.push`

**推送协议**:
```go
type ChatMsg struct {
    RId      int    `json:"rid"`       // 发送者角色ID
    NickName string `json:"nickName"`   // 发送者昵称
    Type     int8   `json:"type"`      // 聊天类型：0=世界聊天，1=联盟聊天
    Msg      string `json:"msg"`       // 消息内容
    Time     int64  `json:"time"`      // 时间戳（Unix时间戳）
}
```

**功能说明**:
- 当有用户发送聊天消息时，服务器会向频道内所有在线用户推送此消息
- 推送是异步的，不需要客户端响应

---

## 四、数据结构定义

### 用户信息
```go
type User struct {
    rid      int    // 角色ID
    nickName string // 昵称
}
```

### 消息结构（内部使用）
```go
type Msg struct {
    RId      int       // 角色ID
    NickName string    // 昵称
    Msg      string    // 消息内容
    Time     time.Time // 时间（内部使用）
}
```

---

## 五、业务逻辑说明

### 1. 频道管理
- **世界频道**：全局唯一，所有登录用户自动加入
- **联盟频道**：按联盟ID动态创建，用户需要主动加入

### 2. 消息存储
- 每个频道最多保存 100 条历史消息
- 采用队列结构，新消息入队，超过100条时自动删除最旧的消息

### 3. 用户管理
- 用户登录时自动加入世界频道
- 用户可以加入一个联盟聊天组（加入新组会自动退出旧组）
- 用户登出时自动从所有频道移除

### 4. 消息广播
- 发送消息时，向频道内所有在线用户广播
- 使用角色ID（rid）进行推送，通过连接管理器查找对应的连接

---

## 六、错误码定义

参考 `constant/code.go`，chatserver 使用的错误码：
- `OK (0)`: 成功
- `InvalidParam (1)`: 参数错误（token无效、用户不存在等）

---

## 七、中间件说明

chatserver 使用的中间件：
- `middleware.ElapsedTime()`: 记录请求处理时间
- `middleware.Log()`: 记录请求日志
- `middleware.CheckRId()`: 验证请求中是否包含有效的角色ID（除 login 外所有接口都需要）

---

## 八、Skynet 重构建议

### 1. 服务划分
- **chat_service**: 处理聊天业务逻辑
- **group_manager**: 管理聊天组（世界频道、联盟频道）
- **message_queue**: 管理消息队列和历史记录
- **user_manager**: 管理用户连接和映射关系

### 2. 协议转换
- 将 WebSocket 消息格式转换为 skynet 的 lua 消息格式
- 保持协议字段名称和类型一致，便于客户端兼容

### 3. 集群通信
- 使用 skynet cluster 实现多进程通信
- 考虑跨进程的用户连接管理和消息推送

### 4. 数据持久化
- 当前实现：消息仅保存在内存中，最多100条
- 重构建议：可考虑将历史消息持久化到数据库或 Redis

---

## 九、协议调用流程示例

### 登录并发送消息流程
```
1. 客户端 -> gateserver -> chatserver: chat.login
   chatserver -> 客户端: LoginRsp

2. 客户端 -> gateserver -> chatserver: chat.chat (Type=0, 世界聊天)
   chatserver -> 频道内所有用户: chat.push (推送消息)
   chatserver -> 客户端: ChatMsg (响应)

3. 客户端 -> gateserver -> chatserver: chat.join (加入联盟1)
   chatserver -> 客户端: JoinRsp

4. 客户端 -> gateserver -> chatserver: chat.chat (Type=1, 联盟聊天)
   chatserver -> 联盟1内所有用户: chat.push (推送消息)
   chatserver -> 客户端: ChatMsg (响应)
```

---

## 十、注意事项

1. **Token 验证**：login 接口需要验证 token，确保用户身份合法
2. **连接管理**：需要维护角色ID与连接的映射关系，用于消息推送
3. **并发安全**：频道操作和消息队列操作需要加锁保护
4. **消息限制**：建议对消息内容长度进行限制（当前代码未实现，可参考 `ContentTooLong` 错误码）
5. **联盟验证**：当前实现未验证用户是否真的属于该联盟，重构时建议添加验证逻辑

