# WebSocket 加密验证流程详解

## 一、当前项目的加密验证流程

### 1. 连接建立阶段

#### 1.1 服务器端初始化

```33:44:net/serverconn.go
func NewServerConn(wsSocket *websocket.Conn, needSecret bool) *ServerConn {
	conn := &ServerConn{
		wsSocket: wsSocket,
		outChan: make(chan *WsMsgRsp, 1000),
		isClosed:false,
		property:make(map[string]interface{}),
		needSecret:needSecret,
		Seq: 0,
	}

	return conn
}
```

- 创建 `ServerConn` 时，通过 `needSecret` 参数决定是否需要加密
- 连接属性存储在 `property` map 中，用于保存 `secretKey`

#### 1.2 服务器主动发送握手消息

```64:64:net/server.go
	conn.Handshake()
```

连接建立后，服务器立即调用 `Handshake()` 方法：

```233:264:net/serverconn.go
func (this *ServerConn) Handshake(){

	secretKey := ""
	if this.needSecret {
		key, err:= this.GetProperty("secretKey")
		if err == nil {
			secretKey = key.(string)
		}else{
			secretKey = util.RandSeq(16)
		}
	}

	handshake := &Handshake{Key: secretKey}
 	body := &RspBody{Name: HandshakeMsg, Msg: handshake}
 	if data, err := util.Marshal(body); err == nil {
 		if secretKey != ""{
			this.SetProperty("secretKey", secretKey)
		}else{
			this.RemoveProperty("secretKey")
		}

		log.DefaultLog.Info("handshake secretKey",
			zap.String("secretKey", secretKey))

		if data, err = util.Zip(data); err == nil{
			this.wsSocket.WriteMessage(websocket.BinaryMessage, data)
		}

	}else {
		log.DefaultLog.Error("handshake Marshal body error", zap.Error(err))
	}
}
```

**握手流程：**
1. 如果 `needSecret=true`，生成一个 16 位随机字符串作为 `secretKey`（字符集：`0-9a-zA-Z`）
2. 将 `secretKey` 保存到连接的 `property` 中
3. 构造 `Handshake` 消息（协议名：`"handshake"`，`Seq=0`）
4. 序列化后压缩，通过 WebSocket 发送给客户端
5. **注意**：握手消息本身**不加密**，因为此时客户端还没有密钥

### 2. 客户端接收握手消息

```111:182:net/clientconn.go
func (this *ClientConn) wsReadLoop() {
	defer func() {
		if err := recover(); err != nil {
			e := fmt.Sprintf("%v", err)
			log.DefaultLog.Error("wsReadLoop error", zap.String("err", e))
			this.Close()
		}
	}()

	for {
		// 读一个message
		_, data, err := this.wsSocket.ReadMessage()
		if err != nil {
			break
		}

		data, err = util.UnZip(data)
		if err != nil {
			log.DefaultLog.Error("wsReadLoop UnZip error", zap.Error(err))
			continue
		}

		//需要检测是否有加密
		body := &RspBody{}
		if secretKey, err := this.GetProperty("secretKey"); err == nil {
			key := secretKey.(string)
			d, err := util.AesCBCDecrypt(data, []byte(key), []byte(key), openssl.ZEROS_PADDING)
			if err != nil {
				log.DefaultLog.Error("AesDecrypt error", zap.Error(err))
			}else{
				data = d
			}
		}

		if err := util.Unmarshal(data, body); err == nil {
			if body.Seq == 0 {
				if body.Name == HandshakeMsg{
					h := Handshake{}
					mapstructure.Decode(body.Msg, &h)
					log.DefaultLog.Info("client 收到握手协议", zap.String("data", string(data)))
					if h.Key != ""{
						this.SetProperty("secretKey", h.Key)
					}else{
						this.RemoveProperty("secretKey")
					}
					this.handshake = true
					this.handshakeChan <- true
				}else{
					//推送，需要推送到指定的代理连接
					if this.onPush != nil{
						this.onPush(this, body)
					}else{
						log.DefaultLog.Warn("clientconn not deal push")
					}
				}
			}else{
				this.syncLock.RLock()
				s, ok := this.syncCtxs[body.Seq]
				this.syncLock.RUnlock()
				if ok {
					s.outChan <- body
				}else{
					log.DefaultLog.Warn("seq not found sync",
						zap.Int64("seq", body.Seq),
						zap.String("msgName", body.Name))
				}
			}

		}else{
			log.DefaultLog.Error("wsReadLoop Unmarshal error", zap.Error(err))
		}
	}

	this.Close()
}
```

**客户端处理流程：**
1. 接收消息后先解压（`UnZip`）
2. 如果已有 `secretKey`，尝试解密；否则直接解析（握手消息未加密）
3. 识别到 `HandshakeMsg` 后：
   - 提取 `Key` 字段
   - 保存到连接的 `property` 中
   - 设置 `handshake=true`
   - 通过 `handshakeChan` 通知等待协程

**客户端等待握手：**

```49:65:net/clientconn.go
func (this *ClientConn) waitHandshake() bool{
	if this.handshake == false{
		ctx, cancel := context.WithTimeout(context.Background(), 5*time.Second)
		defer cancel()
		select {
			case _ = <-this.handshakeChan:{
				log.DefaultLog.Info("recv handshakeChan")
				return true
			}
			case <-ctx.Done():{
				log.DefaultLog.Info("recv handshakeChan timeout")
				return false
			}
		}
	}
	return true
}
```

- 客户端启动后，会阻塞等待握手完成（最多 5 秒）
- 超时则连接失败

### 3. 后续通信加密

#### 3.1 服务器端加密发送

```152:175:net/serverconn.go
func (this *ServerConn) write(msg interface{}) error{
	data, err := util.Marshal(msg)
	if err == nil {
		if this.needSecret {
			if secretKey, err:= this.GetProperty("secretKey"); err == nil {
				key := secretKey.(string)
				data, _ = util.AesCBCEncrypt(data, []byte(key), []byte(key), openssl.ZEROS_PADDING)
			}
		}
	}else {
		log.DefaultLog.Error("wsWriteLoop Marshal body error", zap.Error(err))
		return err
	}

	if data, err := util.Zip(data); err == nil{
		if err := this.wsSocket.WriteMessage(websocket.BinaryMessage, data); err != nil {
			this.Close()
			return err
		}
	}else{
		return err
	}
	return nil
}
```

**加密流程：**
1. 序列化消息（JSON）
2. 如果 `needSecret=true` 且存在 `secretKey`，使用 **AES-CBC** 加密
   - **密钥（Key）**：`secretKey`（16 字节）
   - **初始向量（IV）**：`secretKey`（16 字节）
   - **填充方式**：`ZEROS_PADDING`
3. 压缩（Gzip）
4. 发送二进制消息

#### 3.2 服务器端解密接收

```67:130:net/serverconn.go
func (this *ServerConn) wsReadLoop() {
	defer func() {
		if err := recover(); err != nil {
			e := fmt.Sprintf("%v", err)
			log.DefaultLog.Error("wsReadLoop error", zap.String("err", e))
			this.Close()
		}
	}()

	for {
		// 读一个message
		_, data, err := this.wsSocket.ReadMessage()
		if err != nil {
			break
		}

		data, err = util.UnZip(data)
		if err != nil {
			log.DefaultLog.Error("wsReadLoop UnZip error", zap.Error(err))
			continue
		}

		body := &ReqBody{}
		if this.needSecret {
			//检测是否有加密，没有加密发起Handshake
			if secretKey, err:= this.GetProperty("secretKey"); err == nil {
				key := secretKey.(string)
				d, err := util.AesCBCDecrypt(data, []byte(key), []byte(key), openssl.ZEROS_PADDING)
				if err != nil {
					log.DefaultLog.Error("AesDecrypt error", zap.Error(err))
					this.Handshake()
				}else{
					data = d
				}
			}else{
				log.DefaultLog.Info("secretKey not found client need handshake", zap.Error(err))
				this.Handshake()
				return
			}
		}

		if err := util.Unmarshal(data, body); err == nil {
			req := &WsMsgReq{Conn: this, Body: body}
			rsp := &WsMsgRsp{Body: &RspBody{Name: body.Name, Seq: req.Body.Seq}}

			if req.Body.Name == HeartbeatMsg {
				h := &Heartbeat{}
				mapstructure.Decode(body.Msg, h)
				h.STime = time.Now().UnixNano()/1e6
				rsp.Body.Msg = h
			}else{
				if this.router != nil {
					this.router.Run(req, rsp)
				}
			}
			this.outChan <- rsp
		}else{
			log.DefaultLog.Error("wsReadLoop Unmarshal error", zap.Error(err))
			this.Handshake()
		}
	}

	this.Close()
}
```

**解密流程：**
1. 接收消息后解压
2. 如果 `needSecret=true`：
   - 检查是否存在 `secretKey`
   - 如果不存在或解密失败，**重新发送握手消息**
   - 解密成功则继续处理
3. 反序列化并路由到对应的处理器

### 4. 加密算法细节

```15:30:util/crypto.go
func AesCBCEncrypt(src, key, iv []byte, padding string) ([]byte, error)  {
	data, err := openssl.AesCBCEncrypt(src, key, iv, padding)
	if err != nil {
		return nil, err
	}
	return []byte(hex.EncodeToString(data)), nil
}

func AesCBCDecrypt(src, key, iv []byte, padding string) ([]byte, error) {
	data, err := hex.DecodeString(string(src))
	if err != nil{
		return nil, err
	}
	return openssl.AesCBCDecrypt(data, key, iv, padding)

}
```

**加密特点：**
- **算法**：AES-CBC（128 位）
- **密钥长度**：16 字节（由 `RandSeq(16)` 生成）
- **IV**：与密钥相同（16 字节）
- **填充**：`ZEROS_PADDING`
- **编码**：加密后的二进制数据转换为 **十六进制字符串**

## 二、连接验证的完整流程

### 时序图

```
客户端                    服务器
  |                        |
  |--- WebSocket 连接 ---->|
  |                        |
  |<--- Handshake(未加密) -|
  |    {Key: "abc123..."}  |
  |                        |
  |--- 保存 secretKey ---->|
  |                        |
  |--- 请求(加密) -------->|
  |    AES-CBC(secretKey)  |
  |                        |
  |<--- 响应(加密) --------|
  |    AES-CBC(secretKey)  |
  |                        |
```

### 关键点

1. **握手消息不加密**：因为客户端此时还没有密钥
2. **密钥随机生成**：每次连接都生成新的 16 位随机密钥
3. **密钥仅用于本次连接**：连接断开后密钥失效
4. **自动重握手**：如果解密失败，服务器会重新发送握手消息
5. **压缩在加密之后**：先加密，再压缩

## 三、在 Skynet 框架中的实现方案

### 1. Skynet 框架特点

- **Actor 模型**：每个服务是独立的 Actor
- **消息传递**：服务间通过消息通信
- **Gate 服务**：通常有一个 Gate 服务负责接收客户端连接
- **Session 管理**：每个连接对应一个 session

### 2. 连接验证方案

#### 方案一：保持现有加密机制

**实现步骤：**

1. **Gate 服务处理 WebSocket 连接**
   ```lua
   -- gate.lua
   local skynet = require "skynet"
   local socket = require "socket"
   local websocket = require "websocket"
   
   local need_secret = true
   local connections = {}  -- session -> {secret_key, ...}
   
   -- 生成随机密钥
   local function generate_secret_key()
       local chars = "0123456789abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ"
       local key = ""
       for i = 1, 16 do
           local idx = math.random(1, #chars)
           key = key .. string.sub(chars, idx, idx)
       end
       return key
   end
   
   -- 发送握手消息
   local function send_handshake(fd, secret_key)
       local handshake = {
           name = "handshake",
           seq = 0,
           msg = {key = secret_key}
       }
       local data = websocket.write_text(fd, json.encode(handshake))
       socket.write(fd, data)
   end
   
   -- 处理新连接
   local function handle_connection(fd, addr)
       local session = skynet.genid()
       local secret_key = generate_secret_key()
       
       connections[session] = {
           fd = fd,
           secret_key = secret_key,
           addr = addr
       }
       
       -- 立即发送握手
       send_handshake(fd, secret_key)
       
       -- 启动消息处理协程
       skynet.fork(function()
           handle_messages(session, fd)
       end)
   end
   ```

2. **消息加密/解密**
   ```lua
   local crypto = require "crypto"
   
   -- AES-CBC 加密
   local function encrypt(data, key)
       -- 使用 lua-resty-openssl 或类似库
       return crypto.aes_cbc_encrypt(data, key, key, "zeros")
   end
   
   -- AES-CBC 解密
   local function decrypt(data, key)
       return crypto.aes_cbc_decrypt(data, key, key, "zeros")
   end
   
   -- 处理接收到的消息
   local function handle_messages(session, fd)
       local conn = connections[session]
       if not conn then return end
       
       while true do
           local data = socket.read(fd)
           if not data then break end
           
           -- 解压
           data = util.unzip(data)
           
           -- 解密
           if conn.secret_key then
               local ok, decrypted = pcall(decrypt, data, conn.secret_key)
               if not ok then
                   -- 解密失败，重新握手
                   send_handshake(fd, conn.secret_key)
                   break
               end
               data = decrypted
           end
           
           -- 解析消息
           local msg = json.decode(data)
           
           -- 路由到对应的服务
           route_message(session, msg)
       end
       
       -- 清理连接
       connections[session] = nil
   end
   ```

#### 方案二：增强身份验证（推荐）

在加密验证的基础上，增加**应用层身份验证**：

1. **Token 验证**
   ```lua
   -- 客户端连接时携带 token（通过 HTTP Header 或首次消息）
   local function authenticate(session, token)
       -- 验证 token 有效性
       local ok, user_id = skynet.call(".auth", "lua", "verify_token", token)
       if not ok then
           return false
       end
       
       -- 保存用户信息到连接
       connections[session].user_id = user_id
       connections[session].authenticated = true
       return true
   end
   ```

2. **Session 绑定**
   ```lua
   -- 将 session 与用户 ID 绑定
   local function bind_session(session, user_id)
       -- 通知其他服务用户已上线
       skynet.send(".slgserver", "lua", "user_online", user_id, session)
   end
   ```

3. **消息路由前验证**
   ```lua
   local function route_message(session, msg)
       local conn = connections[session]
       
       -- 检查是否已认证（某些协议需要）
       if need_auth(msg.name) and not conn.authenticated then
           send_error(session, "not_authenticated")
           return
       end
       
       -- 根据协议名路由
       if string.match(msg.name, "^account%.") then
           skynet.send(".loginserver", "lua", "handle", session, msg)
       elseif string.match(msg.name, "^chat%.") then
           skynet.send(".chatserver", "lua", "handle", session, msg)
       elseif string.match(msg.name, "^slgserver%.") then
           skynet.send(".slgserver", "lua", "handle", session, msg)
       end
   end
   ```

### 3. 完整的 Skynet Gate 服务架构

```
┌─────────────┐
│   Client    │
└──────┬──────┘
       │ WebSocket
       │
┌──────▼──────────────────────────────────────┐
│           Gate Service                      │
│  ┌──────────────────────────────────────┐  │
│  │  1. 接收连接                          │  │
│  │  2. 生成 secretKey，发送 Handshake   │  │
│  │  3. 消息加密/解密                     │  │
│  │  4. Token 验证（可选）                │  │
│  │  5. 消息路由                          │  │
│  └──────────────────────────────────────┘  │
└──────┬──────────────────────────────────────┘
       │
       ├─────────────┬──────────────┬─────────────┐
       │             │              │             │
┌──────▼──────┐ ┌───▼──────┐ ┌─────▼──────┐ ┌───▼──────┐
│ LoginServer │ │ChatServer│ │ SLGServer  │ │HttpServer│
└─────────────┘ └──────────┘ └────────────┘ └──────────┘
```

### 4. 安全建议

1. **传输层安全（TLS）**
   - 使用 `wss://` 替代 `ws://`
   - 在 WebSocket 层之上增加 TLS 加密

2. **密钥管理**
   - 考虑使用更长的密钥（32 字节）
   - 定期更换密钥（连接保持时间过长时）

3. **防重放攻击**
   - 在消息中添加时间戳
   - 验证消息的时效性

4. **防中间人攻击**
   - 使用 TLS 证书验证
   - 客户端验证服务器证书

5. **连接限制**
   - 限制同一 IP 的连接数
   - 实现连接频率限制

## 四、总结

### 当前项目的验证机制

- ✅ **加密验证**：通过 Handshake 协议交换密钥，后续通信使用 AES-CBC 加密
- ✅ **自动重握手**：解密失败时自动重新握手
- ❌ **缺少身份验证**：没有用户身份验证机制
- ❌ **缺少连接限制**：没有防止恶意连接的机制

### Skynet 实现要点

1. **Gate 服务**：负责 WebSocket 连接管理和加密/解密
2. **消息路由**：根据协议名前缀路由到对应的业务服务
3. **Session 管理**：每个连接对应一个 session，绑定用户信息
4. **身份验证**：在加密验证基础上，增加 Token 验证
5. **服务通信**：Gate 服务通过 Skynet 消息与其他服务通信

### 迁移建议

1. 保持现有的 Handshake 机制，确保兼容性
2. 在 Gate 服务中实现加密/解密逻辑
3. 增加 Token 验证机制
4. 使用 Skynet 的 cluster 模式实现服务间通信
5. 考虑使用 TLS 增强安全性

