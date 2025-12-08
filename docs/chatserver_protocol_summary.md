# ChatServer 协议快速参考

## 客户端请求协议（通过 gateserver 转发）

| 路由 | 请求结构 | 响应结构 | 说明 |
|------|---------|---------|------|
| `chat.login` | `LoginReq` | `LoginRsp` | 登录聊天服务器，加入世界频道 |
| `chat.logout` | `LogoutReq` | `LogoutRsp` | 登出聊天服务器，退出所有频道 |
| `chat.chat` | `ChatReq` | `ChatMsg` | 发送聊天消息（世界/联盟） |
| `chat.history` | `HistoryReq` | `HistoryRsp` | 获取历史消息 |
| `chat.join` | `JoinReq` | `JoinRsp` | 加入联盟聊天组 |
| `chat.exit` | `ExitReq` | `ExitRsp` | 退出联盟聊天组 |

## 服务器推送协议

| 路由 | 推送结构 | 说明 |
|------|---------|------|
| `chat.push` | `ChatMsg` | 推送聊天消息给频道内所有用户 |

## 协议结构定义

### LoginReq
```json
{
  "rid": 123,
  "nickName": "玩家昵称",
  "token": "会话令牌"
}
```

### LoginRsp
```json
{
  "rid": 123,
  "nickName": "玩家昵称"
}
```

### LogoutReq / LogoutRsp
```json
{
  "RId": 123
}
```

### ChatReq
```json
{
  "type": 0,  // 0=世界聊天, 1=联盟聊天
  "msg": "消息内容"
}
```

### ChatMsg (响应和推送)
```json
{
  "rid": 123,
  "nickName": "玩家昵称",
  "type": 0,  // 0=世界聊天, 1=联盟聊天
  "msg": "消息内容",
  "time": 1234567890  // Unix时间戳
}
```

### HistoryReq
```json
{
  "type": 0  // 0=世界聊天, 1=联盟聊天
}
```

### HistoryRsp
```json
{
  "type": 0,
  "msgs": [
    {
      "rid": 123,
      "nickName": "玩家昵称",
      "type": 0,
      "msg": "消息内容",
      "time": 1234567890
    }
  ]
}
```

### JoinReq / JoinRsp
```json
{
  "type": 1,  // 固定为1（联盟聊天）
  "id": 456   // 联盟ID
}
```

### ExitReq / ExitRsp
```json
{
  "type": 1,  // 固定为1（联盟聊天）
  "id": 456   // 联盟ID
}
```

## 业务规则

1. **频道类型**
   - Type = 0: 世界聊天（全局唯一，自动加入）
   - Type = 1: 联盟聊天（按联盟ID创建，需主动加入）

2. **消息存储**
   - 每个频道最多保存 100 条历史消息
   - 采用队列结构，FIFO

3. **用户管理**
   - 登录时自动加入世界频道
   - 只能加入一个联盟聊天组（加入新组会退出旧组）
   - 登出时自动退出所有频道

4. **消息推送**
   - 发送消息时，向频道内所有在线用户推送
   - 推送路由：`chat.push`

## 错误码

- `0`: 成功
- `1`: 参数错误（InvalidParam）

## 中间件

- `chat.login`: 无特殊中间件
- 其他接口：需要 `CheckRId()` 中间件验证角色ID

