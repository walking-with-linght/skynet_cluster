# SLG 服务器 WebSocket 协议完整文档

本文档整理了整个项目的所有 WebSocket 协议，按进程分类，包含所有字段名和详细说明。

---

## 目录

1. [Loginserver 协议](#一-loginserver-协议)
2. [Chatserver 协议](#二-chatserver-协议)
3. [Slgserver 协议](#三-slgserver-协议)
   - [角色相关 (role)](#31-角色相关-role)
   - [城市相关 (city)](#32-城市相关-city)
   - [武将相关 (general)](#33-武将相关-general)
   - [军队相关 (army)](#34-军队相关-army)
   - [联盟相关 (union)](#35-联盟相关-union)
   - [战争相关 (war)](#36-战争相关-war)
   - [技能相关 (skill)](#37-技能相关-skill)
   - [内政相关 (interior)](#38-内政相关-interior)
   - [国家地图相关 (nationMap)](#39-国家地图相关-nationmap)
4. [服务器推送协议](#四-服务器推送协议)
5. [Gateserver 说明](#五-gateserver-说明)

---

## 一、Loginserver 协议

所有协议路由前缀：`account.`

### 1.1 登录

**路由**: `account.login`

**请求** (`LoginReq`):
```json
{
  "username": "string",   // 用户名
  "password": "string",   // 密码
  "ip": "string",         // 客户端IP
  "hardware": "string"    // 硬件标识
}
```

**响应** (`LoginRsp`):
```json
{
  "username": "string",   // 用户名
  "password": "string",   // 密码（返回用于客户端验证）
  "session": "string",    // 会话令牌
  "uid": 123              // 用户ID
}
```

**错误码**: `PwdIncorrect (4)`, `UserNotExist (5)`, `DBError (2)`

---

### 1.2 重新登录

**路由**: `account.reLogin`

**请求** (`ReLoginReq`):
```json
{
  "session": "string",    // 会话令牌
  "ip": "string",         // 客户端IP
  "hardware": "string"    // 硬件标识
}
```

**响应** (`ReLoginRsp`):
```json
{
  "session": "string"     // 会话令牌
}
```

**错误码**: `SessionInvalid (6)`, `HardwareIncorrect (7)`

---

### 1.3 登出

**路由**: `account.logout`

**请求** (`LogoutReq`):
```json
{
  "uid": 123              // 用户ID
}
```

**响应** (`LogoutRsp`):
```json
{
  "uid": 123              // 用户ID
}
```

---

### 1.4 服务器列表

**路由**: `account.serverList`

**请求** (`ServerListReq`):
```json
{}
```

**响应** (`ServerListRsp`):
```json
{
  "lists": [
    {
      "id": 1,                    // 服务器ID
      "slg": "ws://127.0.0.1:8001",  // 游戏服务器地址
      "chat": "ws://127.0.0.1:8002"  // 聊天服务器地址
    }
  ]
}
```

---

## 二、Chatserver 协议

所有协议路由前缀：`chat.`

详细文档请参考：[chatserver_protocol.md](./chatserver_protocol.md)

### 2.1 登录聊天服务器

**路由**: `chat.login`

**请求** (`LoginReq`):
```json
{
  "rid": 123,             // 角色ID
  "nickName": "string",   // 昵称
  "token": "string"       // 会话令牌
}
```

**响应** (`LoginRsp`):
```json
{
  "rid": 123,
  "nickName": "string"
}
```

---

### 2.2 登出聊天服务器

**路由**: `chat.logout`

**请求** (`LogoutReq`):
```json
{
  "RId": 123
}
```

**响应** (`LogoutRsp`):
```json
{
  "RId": 123
}
```

---

### 2.3 发送聊天消息

**路由**: `chat.chat`

**请求** (`ChatReq`):
```json
{
  "type": 0,              // 0=世界聊天, 1=联盟聊天
  "msg": "string"         // 消息内容
}
```

**响应** (`ChatMsg`):
```json
{
  "rid": 123,
  "nickName": "string",
  "type": 0,
  "msg": "string",
  "time": 1234567890      // Unix时间戳
}
```

---

### 2.4 获取历史消息

**路由**: `chat.history`

**请求** (`HistoryReq`):
```json
{
  "type": 0               // 0=世界聊天, 1=联盟聊天
}
```

**响应** (`HistoryRsp`):
```json
{
  "type": 0,
  "msgs": [
    {
      "rid": 123,
      "nickName": "string",
      "type": 0,
      "msg": "string",
      "time": 1234567890
    }
  ]
}
```

---

### 2.5 加入联盟聊天组

**路由**: `chat.join`

**请求** (`JoinReq`):
```json
{
  "type": 1,              // 固定为1（联盟聊天）
  "id": 456               // 联盟ID
}
```

**响应** (`JoinRsp`):
```json
{
  "type": 1,
  "id": 456
}
```

---

### 2.6 退出联盟聊天组

**路由**: `chat.exit`

**请求** (`ExitReq`):
```json
{
  "type": 1,
  "id": 456
}
```

**响应** (`ExitRsp`):
```json
{
  "type": 1,
  "id": 456
}
```

---

## 三、Slgserver 协议

### 3.1 角色相关 (role)

所有协议路由前缀：`role.`

#### 3.1.1 进入服务器

**路由**: `role.enterServer`

**请求** (`EnterServerReq`):
```json
{
  "session": "string"     // 会话令牌
}
```

**响应** (`EnterServerRsp`):
```json
{
  "role": {
    "rid": 123,
    "uid": 456,
    "nickName": "string",
    "sex": 0,             // 性别
    "balance": 0,         // 余额
    "headId": 1,          // 头像ID
    "profile": "string"   // 简介
  },
  "role_res": {
    "wood": 1000,
    "iron": 1000,
    "stone": 1000,
    "grain": 1000,
    "gold": 1000,
    "decree": 10,         // 政令
    "wood_yield": 100,    // 木材产量
    "iron_yield": 100,
    "stone_yield": 100,
    "grain_yield": 100,
    "gold_yield": 100,
    "depot_capacity": 10000  // 仓库容量
  },
  "time": 1234567890123,  // 服务器时间（毫秒）
  "token": "string"       // 角色会话令牌
}
```

---

#### 3.1.2 创建角色

**路由**: `role.create`

**请求** (`CreateRoleReq`):
```json
{
  "uid": 456,
  "nickName": "string",
  "sex": 0,               // 性别
  "sid": 1,               // 服务器ID
  "headId": 1             // 头像ID
}
```

**响应** (`CreateRoleRsp`):
```json
{
  "role": {
    "rid": 123,
    "uid": 456,
    "nickName": "string",
    "sex": 0,
    "balance": 0,
    "headId": 1,
    "profile": ""
  }
}
```

**错误码**: `RoleAlreadyCreate (8)`, `RoleNameExist (66)`

---

#### 3.1.3 角色列表

**路由**: `role.roleList`

**请求** (`RoleListReq`):
```json
{
  "uid": 456
}
```

**响应** (`RoleListRsp`):
```json
{
  "roles": [
    {
      "rid": 123,
      "uid": 456,
      "nickName": "string",
      "sex": 0,
      "balance": 0,
      "headId": 1,
      "profile": ""
    }
  ]
}
```

---

#### 3.1.4 我的城市

**路由**: `role.myCity`

**请求** (`MyCityReq`):
```json
{}
```

**响应** (`MyCityRsp`):
```json
{
  "citys": [
    {
      "cityId": 1,
      "rid": 123,
      "name": "string",
      "union_id": 0,      // 联盟ID
      "union_name": "",   // 联盟名字
      "parent_id": 0,     // 上级ID
      "x": 100,
      "y": 200,
      "is_main": true,    // 是否主城
      "level": 1,         // 城市等级
      "cur_durable": 1000,  // 当前耐久
      "max_durable": 1000,  // 最大耐久
      "occupy_time": 1234567890  // 占领时间（毫秒）
    }
  ]
}
```

---

#### 3.1.5 我的资源

**路由**: `role.myRoleRes`

**请求** (`MyRoleResReq`):
```json
{}
```

**响应** (`MyRoleResRsp`):
```json
{
  "role_res": {
    "wood": 1000,
    "iron": 1000,
    "stone": 1000,
    "grain": 1000,
    "gold": 1000,
    "decree": 10,
    "wood_yield": 100,
    "iron_yield": 100,
    "stone_yield": 100,
    "grain_yield": 100,
    "gold_yield": 100,
    "depot_capacity": 10000
  }
}
```

---

#### 3.1.6 我的建筑

**路由**: `role.myRoleBuild`

**请求** (`MyRoleBuildReq`):
```json
{}
```

**响应** (`MyRoleBuildRsp`):
```json
{
  "mr_builds": [
    {
      "rid": 123,
      "RNick": "string",   // 角色昵称
      "name": "string",
      "union_id": 0,
      "union_name": "",
      "parent_id": 0,
      "x": 100,
      "y": 200,
      "type": 1,          // 建筑类型
      "level": 1,
      "op_level": 0,      // 升级目标等级
      "cur_durable": 1000,
      "max_durable": 1000,
      "defender": 0,      // 防御等级
      "occupy_time": 1234567890,
      "end_time": 1234567890,    // 建造完成时间
      "giveUp_time": 0   // 放弃时间
    }
  ]
}
```

---

#### 3.1.7 我的属性（完整信息）

**路由**: `role.myProperty`

**请求** (`MyRolePropertyReq`):
```json
{}
```

**响应** (`MyRolePropertyRsp`):
```json
{
  "role_res": { /* 同 MyRoleResRsp */ },
  "mr_builds": [ /* 同 MyRoleBuildRsp */ ],
  "generals": [ /* 见 general 部分 */ ],
  "citys": [ /* 同 MyCityRsp */ ],
  "armys": [ /* 见 army 部分 */ ]
}
```

---

#### 3.1.8 更新位置

**路由**: `role.upPosition`

**请求** (`UpPositionReq`):
```json
{
  "x": 100,
  "y": 200
}
```

**响应** (`UpPositionRsp`):
```json
{
  "x": 100,
  "y": 200
}
```

---

#### 3.1.9 位置标记列表

**路由**: `role.posTagList`

**请求** (`PosTagListReq`):
```json
{}
```

**响应** (`PosTagListRsp`):
```json
{
  "pos_tags": [
    {
      "x": 100,
      "y": 200,
      "name": "标记名称"
    }
  ]
}
```

---

#### 3.1.10 操作位置标记

**路由**: `role.opPosTag`

**请求** (`PosTagReq`):
```json
{
  "type": 1,              // 1=标记, 0=取消标记
  "x": 100,
  "y": 200,
  "name": "string"
}
```

**响应** (`PosTagRsp`):
```json
{
  "type": 1,
  "x": 100,
  "y": 200,
  "name": "string"
}
```

**错误码**: `OutPosTagLimit (59)`

---

### 3.2 城市相关 (city)

所有协议路由前缀：`city.`

#### 3.2.1 设施列表

**路由**: `city.facilities`

**请求** (`FacilitiesReq`):
```json
{
  "cityId": 1
}
```

**响应** (`FacilitiesRsp`):
```json
{
  "cityId": 1,
  "facilities": [
    {
      "name": "string",
      "level": 1,
      "type": 1,          // 设施类型
      "up_time": 1234567890  // 升级时间戳，0表示已升级完成
    }
  ]
}
```

---

#### 3.2.2 升级设施

**路由**: `city.upFacility`

**请求** (`UpFacilityReq`):
```json
{
  "cityId": 1,
  "fType": 1             // 设施类型
}
```

**响应** (`UpFacilityRsp`):
```json
{
  "cityId": 1,
  "facility": {
    "name": "string",
    "level": 2,
    "type": 1,
    "up_time": 1234567890
  },
  "role_res": { /* 同 RoleRes */ }
}
```

---

### 3.3 武将相关 (general)

所有协议路由前缀：`general.`

#### 3.3.1 我的武将列表

**路由**: `general.myGenerals`

**请求** (`MyGeneralReq`):
```json
{}
```

**响应** (`MyGeneralRsp`):
```json
{
  "generals": [
    {
      "id": 1,
      "cfgId": 1001,      // 配置ID
      "physical_power": 100,  // 体力
      "order": 0,        // 0=未上阵, 1-5=队伍编号
      "level": 1,        // 等级
      "exp": 0,          // 经验
      "cityId": 1,
      "curArms": 1,      // 当前兵种
      "hasPrPoint": 0,   // 拥有属性点
      "usePrPoint": 0,   // 已使用属性点
      "attack_distance": 1,  // 攻击距离
      "force_added": 0,  // 武力加成
      "strategy_added": 0,   // 谋略加成
      "defense_added": 0,    // 防御加成
      "speed_added": 0,      // 速度加成
      "destroy_added": 0,    // 破坏加成
      "star_lv": 0,      // 星级等级
      "star": 5,         // 最大星级
      "parentId": 0,     // 父武将ID（合成用）
      "skills": [        // 技能列表
        {
          "id": 1,
          "lv": 1,
          "cfgId": 2001
        }
      ],
      "state": 0         // 状态
    }
  ]
}
```

---

#### 3.3.2 抽卡

**路由**: `general.drawGeneral`

**请求** (`DrawGeneralReq`):
```json
{
  "drawTimes": 1         // 抽卡次数
}
```

**响应** (`DrawGeneralRsp`):
```json
{
  "generals": [ /* 同 General 结构 */ ]
}
```

**错误码**: `GoldNotEnough (26)`, `OutGeneralLimit (57)`

---

#### 3.3.3 合成武将

**路由**: `general.composeGeneral`

**请求** (`ComposeGeneralReq`):
```json
{
  "compId": 1,           // 合成目标武将ID
  "gIds": [2, 3, 4]      // 合成材料武将ID列表
}
```

**响应** (`ComposeGeneralRsp`):
```json
{
  "generals": [ /* 更新后的武将列表 */ ]
}
```

**错误码**: `GeneralNoHas (29)`, `GeneralNoSame (30)`, `GeneralStarMax (33)`

---

#### 3.3.4 武将加点

**路由**: `general.addPrGeneral`

**请求** (`AddPrGeneralReq`):
```json
{
  "compId": 1,           // 武将ID
  "forceAdd": 10,        // 武力加点
  "strategyAdd": 10,     // 谋略加点
  "defenseAdd": 10,      // 防御加点
  "speedAdd": 10,        // 速度加点
  "destroyAdd": 10       // 破坏加点
}
```

**响应** (`AddPrGeneralRsp`):
```json
{
  "general": { /* 更新后的武将信息 */ }
}
```

---

#### 3.3.5 转换武将（回收）

**路由**: `general.convert`

**请求** (`ConvertReq`):
```json
{
  "gIds": [1, 2, 3]      // 要转换的武将ID列表
}
```

**响应** (`ConvertRsp`):
```json
{
  "gIds": [1, 2, 3],    // 成功转换的武将ID
  "gold": 1000,         // 当前金币
  "add_gold": 300       // 增加的金币
}
```

---

#### 3.3.6 装备技能

**路由**: `general.upSkill`

**请求** (`UpDownSkillReq`):
```json
{
  "gId": 1,              // 武将ID
  "cfgId": 2001,         // 技能配置ID
  "pos": 0               // 位置 0-2
}
```

**响应** (`UpDownSkillRsp`):
```json
{
  "gId": 1,
  "cfgId": 2001,
  "pos": 0
}
```

**错误码**: `OutSkillLimit (60)`, `UpSkillError (61)`, `OutArmNotMatch (63)`

---

#### 3.3.7 卸下技能

**路由**: `general.downSkill`

**请求** (`UpDownSkillReq`):
```json
{
  "gId": 1,
  "cfgId": 2001,
  "pos": 0
}
```

**响应** (`UpDownSkillRsp`):
```json
{
  "gId": 1,
  "cfgId": 2001,
  "pos": 0
}
```

**错误码**: `DownSkillError (62)`, `PosNotSkill (64)`

---

#### 3.3.8 升级技能

**路由**: `general.lvSkill`

**请求** (`LvSkillReq`):
```json
{
  "gId": 1,
  "pos": 0               // 技能位置
}
```

**响应** (`LvSkillRsp`):
```json
{
  "gId": 1,
  "pos": 0
}
```

**错误码**: `SkillLevelFull (65)`

---

### 3.4 军队相关 (army)

所有协议路由前缀：`army.`

#### 3.4.1 军队列表

**路由**: `army.myList`

**请求** (`ArmyListReq`):
```json
{
  "cityId": 1
}
```

**响应** (`ArmyListRsp`):
```json
{
  "cityId": 1,
  "armys": [
    {
      "id": 1,
      "cityId": 1,
      "union_id": 0,
      "order": 1,        // 第几队，1-5
      "generals": [1, 2, 0],  // 武将ID数组（3个位置）
      "soldiers": [1000, 2000, 0],  // 士兵数量数组
      "con_times": [1234567890, 0, 0],  // 征兵完成时间数组
      "con_cnts": [500, 0, 0],  // 征兵数量数组
      "cmd": 0,          // 命令：0=空闲, 1=攻击, 2=驻军, 3=返回, 4=开荒, 5=调兵
      "state": 0,        // 状态：0=running, 1=stop
      "from_x": 100,
      "from_y": 200,
      "to_x": 150,
      "to_y": 250,
      "start": 1234567890,  // 出征开始时间（Unix时间戳）
      "end": 1234567900     // 出征结束时间
    }
  ]
}
```

---

#### 3.4.2 单个军队

**路由**: `army.myOne`

**请求** (`ArmyOneReq`):
```json
{
  "cityId": 1,
  "order": 1             // 队伍编号
}
```

**响应** (`ArmyOneRsp`):
```json
{
  "army": { /* 同 Army 结构 */ }
}
```

---

#### 3.4.3 配置武将（上阵/下阵）

**路由**: `army.dispose`

**请求** (`DisposeReq`):
```json
{
  "cityId": 1,
  "generalId": 1,        // 武将ID
  "order": 1,            // 第几队
  "position": 0          // 位置：-1=下阵, 0-2=上阵位置
}
```

**响应** (`DisposeRsp`):
```json
{
  "army": { /* 更新后的军队信息 */ }
}
```

**错误码**: `ArmyNotEnough (31)`, `GeneralBusy (19)`, `GeneralRepeat (27)`, `CostNotEnough (28)`, `TongShuaiNotEnough (32)`

---

#### 3.4.4 征兵

**路由**: `army.conscript`

**请求** (`ConscriptReq`):
```json
{
  "armyId": 1,
  "cnts": [500, 300, 0]  // 每个位置的征兵数量
}
```

**响应** (`ConscriptRsp`):
```json
{
  "army": { /* 更新后的军队信息 */ },
  "role_res": { /* 更新后的资源 */ }
}
```

**错误码**: `ResNotEnough (16)`, `OutArmyLimit (17)`, `ArmyBusy (18)`, `BuildMBSNotFound (45)`, `ArmyConscript (47)`

---

#### 3.4.5 派遣队伍

**路由**: `army.assign`

**请求** (`AssignArmyReq`):
```json
{
  "armyId": 1,
  "cmd": 1,              // 命令：0=空闲, 1=攻击, 2=驻军, 3=返回, 4=开荒, 5=调兵
  "x": 150,
  "y": 250
}
```

**响应** (`AssignArmyRsp`):
```json
{
  "army": { /* 更新后的军队信息 */ }
}
```

**错误码**: `PhysicalPowerNotEnough (24)`, `DecreeNotEnough (25)`, `UnReachable (23)`, `BuildWarFree (46)`, `BuildCanNotAttack (44)`, `BuildCanNotDefend (43)`, `CanNotTransfer (50)`, `HoldIsFull (51)`

---

### 3.5 联盟相关 (union)

所有协议路由前缀：`union.`

#### 3.5.1 创建联盟

**路由**: `union.create`

**请求** (`CreateReq`):
```json
{
  "name": "联盟名称"
}
```

**响应** (`CreateRsp`):
```json
{
  "id": 1,               // 联盟ID
  "name": "联盟名称"
}
```

**错误码**: `UnionAlreadyHas (37)`, `UnionCreateError (34)`

---

#### 3.5.2 联盟列表

**路由**: `union.list`

**请求** (`ListReq`):
```json
{}
```

**响应** (`ListRsp`):
```json
{
  "list": [
    {
      "id": 1,
      "name": "联盟名称",
      "cnt": 10,         // 联盟人数
      "notice": "公告内容",
      "major": [         // 主要人物
        {
          "rid": 123,
          "name": "玩家昵称",
          "title": 0     // 0=盟主, 1=副盟主
        }
      ]
    }
  ]
}
```

---

#### 3.5.3 申请加入联盟

**路由**: `union.join`

**请求** (`JoinReq`):
```json
{
  "id": 1                // 联盟ID
}
```

**响应** (`JoinRsp`):
```json
{}
```

**错误码**: `UnionAlreadyHas (37)`, `UnionNotFound (35)`, `PeopleIsFull (41)`, `HasApply (42)`

---

#### 3.5.4 审核申请

**路由**: `union.verify`

**请求** (`VerifyReq`):
```json
{
  "id": 1,               // 申请ID
  "decide": 2            // 1=拒绝, 2=通过
}
```

**响应** (`VerifyRsp`):
```json
{
  "id": 1,
  "decide": 2
}
```

**错误码**: `PermissionDenied (36)`, `PeopleIsFull (41)`, `UnionAlreadyHas (37)`

---

#### 3.5.5 成员列表

**路由**: `union.member`

**请求** (`MemberReq`):
```json
{
  "id": 1                // 联盟ID
}
```

**响应** (`MemberRsp`):
```json
{
  "id": 1,
  "Members": [
    {
      "rid": 123,
      "name": "玩家昵称",
      "title": 0,        // 0=盟主, 1=副盟主, 2=普通成员
      "x": 100,
      "y": 200
    }
  ]
}
```

---

#### 3.5.6 申请列表

**路由**: `union.applyList`

**请求** (`ApplyReq`):
```json
{
  "id": 1                // 联盟ID
}
```

**响应** (`ApplyRsp`):
```json
{
  "id": 1,
  "applys": [
    {
      "id": 1,           // 申请ID
      "rid": 123,
      "nick_name": "玩家昵称"
    }
  ]
}
```

---

#### 3.5.7 退出联盟

**路由**: `union.exit`

**请求** (`ExitReq`):
```json
{}
```

**响应** (`ExitRsp`):
```json
{}
```

**错误码**: `UnionNotAllowExit (38)`

---

#### 3.5.8 解散联盟

**路由**: `union.dismiss`

**请求** (`DismissReq`):
```json
{}
```

**响应** (`DismissRsp`):
```json
{}
```

**错误码**: `PermissionDenied (36)`

---

#### 3.5.9 查看公告

**路由**: `union.notice`

**请求** (`NoticeReq`):
```json
{
  "id": 1
}
```

**响应** (`NoticeRsp`):
```json
{
  "text": "公告内容"
}
```

---

#### 3.5.10 修改公告

**路由**: `union.modNotice`

**请求** (`ModNoticeReq`):
```json
{
  "text": "新公告内容"
}
```

**响应** (`ModNoticeRsp`):
```json
{
  "id": 1,
  "text": "新公告内容"
}
```

**错误码**: `ContentTooLong (39)`, `PermissionDenied (36)`

---

#### 3.5.11 踢人

**路由**: `union.kick`

**请求** (`KickReq`):
```json
{
  "rid": 123
}
```

**响应** (`KickRsp`):
```json
{
  "rid": 123
}
```

**错误码**: `PermissionDenied (36)`, `NotBelongUnion (40)`

---

#### 3.5.12 任命

**路由**: `union.appoint`

**请求** (`AppointReq`):
```json
{
  "rid": 123,
  "title": 1             // 职位：0=盟主, 1=副盟主, 2=普通成员
}
```

**响应** (`AppointRsp`):
```json
{
  "rid": 123,
  "title": 1
}
```

**错误码**: `PermissionDenied (36)`, `NotBelongUnion (40)`

---

#### 3.5.13 禅让

**路由**: `union.abdicate`

**请求** (`AbdicateReq`):
```json
{
  "rid": 123            // 禅让给的rid
}
```

**响应** (`AbdicateRsp`):
```json
{}
```

**错误码**: `PermissionDenied (36)`, `NotBelongUnion (40)`

---

#### 3.5.14 联盟信息

**路由**: `union.info`

**请求** (`InfoReq`):
```json
{
  "id": 1
}
```

**响应** (`InfoRsp`):
```json
{
  "id": 1,
  "info": {
    "id": 1,
    "name": "联盟名称",
    "cnt": 10,
    "notice": "公告",
    "major": [ /* 同 major 结构 */ ]
  }
}
```

---

#### 3.5.15 联盟日志

**路由**: `union.log`

**请求** (`LogReq`):
```json
{}
```

**响应** (`LogRsp`):
```json
{
  "logs": [
    {
      "op_rid": 123,    // 操作者rid
      "target_id": 456, // 目标rid
      "state": 0,       // 状态
      "des": "描述",
      "ctime": 1234567890  // 时间戳
    }
  ]
}
```

---

### 3.6 战争相关 (war)

所有协议路由前缀：`war.`

#### 3.6.1 战报列表

**路由**: `war.report`

**请求** (`WarReportReq`):
```json
{}
```

**响应** (`WarReportRsp`):
```json
{
  "list": [
    {
      "id": 1,
      "a_rid": 123,      // 攻击者rid
      "d_rid": 456,      // 防御者rid
      "b_a_army": "string",  // 攻击方初始军队
      "b_d_army": "string",  // 防御方初始军队
      "e_a_army": "string",  // 攻击方结束军队
      "e_d_army": "string",  // 防御方结束军队
      "b_a_general": "string",  // 攻击方初始武将
      "b_d_general": "string",  // 防御方初始武将
      "e_a_general": "string",  // 攻击方结束武将
      "e_d_general": "string",  // 防御方结束武将
      "result": 2,       // 0=失败, 1=打平, 2=胜利
      "rounds": "string", // 回合详情
      "a_is_read": false,  // 攻击者是否已读
      "d_is_read": false,  // 防御者是否已读
      "destroy": 100,     // 破坏耐久
      "occupy": 0,        // 是否占领
      "x": 100,
      "y": 200,
      "ctime": 1234567890  // 时间戳（毫秒）
    }
  ]
}
```

---

#### 3.6.2 标记已读

**路由**: `war.read`

**请求** (`WarReadReq`):
```json
{
  "id": 1                // 0表示全部已读
}
```

**响应** (`WarReadRsp`):
```json
{
  "id": 1
}
```

---

### 3.7 技能相关 (skill)

所有协议路由前缀：`skill.`

#### 3.7.1 技能列表

**路由**: `skill.list`

**请求** (`SkillListReq`):
```json
{}
```

**响应** (`SkillListRsp`):
```json
{
  "list": [
    {
      "id": 1,
      "cfgId": 2001,     // 技能配置ID
      "generals": [1, 2, 3]  // 装备该技能的武将ID列表
    }
  ]
}
```

---

### 3.8 内政相关 (interior)

所有协议路由前缀：`interior.`

#### 3.8.1 征收

**路由**: `interior.collect`

**请求** (`CollectionReq`):
```json
{}
```

**响应** (`CollectionRsp`):
```json
{
  "gold": 100,           // 征收的金币
  "limit": 10,           // 每日征收次数上限
  "cur_times": 5,        // 当前已征收次数
  "next_time": 1234567890  // 下次可征收时间（毫秒）
}
```

**错误码**: `OutCollectTimesLimit (55)`, `InCdCanNotOperate (56)`

---

#### 3.8.2 打开征收界面

**路由**: `interior.openCollect`

**请求** (`OpenCollectionReq`):
```json
{}
```

**响应** (`OpenCollectionRsp`):
```json
{
  "limit": 10,
  "cur_times": 5,
  "next_time": 1234567890
}
```

---

#### 3.8.3 资源转换

**路由**: `interior.transform`

**请求** (`TransformReq`):
```json
{
  "from": [100, 0, 0, 0],  // 0=木材, 1=铁矿, 2=石头, 3=粮食
  "to": [0, 50, 0, 0]     // 转换目标
}
```

**响应** (`TransformRsp`):
```json
{}
```

**错误码**: `NotHasJiShi (58)`

---

### 3.9 国家地图相关 (nationMap)

所有协议路由前缀：`nationMap.`

#### 3.9.1 获取配置

**路由**: `nationMap.config`

**请求** (`ConfigReq`):
```json
{}
```

**响应** (`ConfigRsp`):
```json
{
  "confs": [
    {
      "type": 1,         // 建筑类型
      "level": 1,        // 等级
      "name": "建筑名称",
      "Wood": 100,       // 所需木材
      "iron": 100,       // 所需铁矿
      "stone": 100,      // 所需石头
      "grain": 100,      // 所需粮食
      "durable": 1000,   // 耐久
      "defender": 0      // 防御等级
    }
  ]
}
```

---

#### 3.9.2 扫描地图

**路由**: `nationMap.scan`

**请求** (`ScanReq`):
```json
{
  "x": 100,
  "y": 200
}
```

**响应** (`ScanRsp`):
```json
{
  "mr_builds": [ /* 同 MapRoleBuild 结构 */ ],
  "mc_builds": [ /* 同 MapRoleCity 结构 */ ],
  "armys": [ /* 同 Army 结构 */ ]
}
```

---

#### 3.9.3 扫描区域

**路由**: `nationMap.scanBlock`

**请求** (`ScanBlockReq`):
```json
{
  "x": 100,
  "y": 200,
  "length": 5           // 扫描范围
}
```

**响应** (`ScanRsp`):
```json
{
  "mr_builds": [ /* 同 MapRoleBuild 结构 */ ],
  "mc_builds": [ /* 同 MapRoleCity 结构 */ ],
  "armys": [ /* 同 Army 结构 */ ]
}
```

---

#### 3.9.4 放弃领地

**路由**: `nationMap.giveUp`

**请求** (`GiveUpReq`):
```json
{
  "x": 100,
  "y": 200
}
```

**响应** (`GiveUpRsp`):
```json
{
  "x": 100,
  "y": 200
}
```

**错误码**: `BuildNotMe (21)`, `CannotGiveUp (20)`

---

#### 3.9.5 建造

**路由**: `nationMap.build`

**请求** (`BuildReq`):
```json
{
  "x": 100,
  "y": 200,
  "type": 1             // 建筑类型
}
```

**响应** (`BuildRsp`):
```json
{
  "x": 100,
  "y": 200,
  "type": 1
}
```

**错误码**: `BuildNotMe (21)`, `CanNotBuildNew (49)`, `ResNotEnough (16)`

---

#### 3.9.6 升级建筑

**路由**: `nationMap.upBuild`

**请求** (`UpBuildReq`):
```json
{
  "x": 100,
  "y": 200
}
```

**响应** (`UpBuildRsp`):
```json
{
  "x": 100,
  "y": 200,
  "build": { /* 更新后的建筑信息 */ }
}
```

**错误码**: `BuildNotMe (21)`, `CanNotUpBuild (53)`, `ResNotEnough (16)`

---

#### 3.9.7 拆除建筑

**路由**: `nationMap.delBuild`

**请求** (`DelBuildReq`):
```json
{
  "x": 100,
  "y": 200
}
```

**响应** (`DelBuildRsp`):
```json
{
  "x": 100,
  "y": 200,
  "build": { /* 更新后的建筑信息 */ }
}
```

**错误码**: `BuildNotMe (21)`, `CanNotDestroy (54)`

---

## 四、服务器推送协议

所有推送协议都是服务器主动推送给客户端的，不需要客户端请求。

### 4.1 聊天消息推送

**路由**: `chat.push`

**推送内容** (`ChatMsg`):
```json
{
  "rid": 123,
  "nickName": "string",
  "type": 0,             // 0=世界聊天, 1=联盟聊天
  "msg": "string",
  "time": 1234567890
}
```

---

### 4.2 资源推送

**路由**: `roleRes.push`

**推送内容** (`RoleRes`):
```json
{
  "wood": 1000,
  "iron": 1000,
  "stone": 1000,
  "grain": 1000,
  "gold": 1000,
  "decree": 10,
  "wood_yield": 100,
  "iron_yield": 100,
  "stone_yield": 100,
  "grain_yield": 100,
  "gold_yield": 100,
  "depot_capacity": 10000
}
```

---

### 4.3 角色属性推送

**路由**: `roleAttr.push`

**推送内容**: `null` (仅通知更新，无具体数据)

---

### 4.4 城市推送

**路由**: `roleCity.push`

**推送内容** (`MapRoleCity`):
```json
{
  "cityId": 1,
  "rid": 123,
  "name": "string",
  "union_id": 0,
  "union_name": "",
  "parent_id": 0,
  "x": 100,
  "y": 200,
  "is_main": true,
  "level": 1,
  "cur_durable": 1000,
  "max_durable": 1000,
  "occupy_time": 1234567890
}
```

---

### 4.5 建筑推送

**路由**: `roleBuild.push`

**推送内容** (`MapRoleBuild`):
```json
{
  "rid": 123,
  "RNick": "string",
  "name": "string",
  "union_id": 0,
  "union_name": "",
  "parent_id": 0,
  "x": 100,
  "y": 200,
  "type": 1,
  "level": 1,
  "op_level": 0,
  "cur_durable": 1000,
  "max_durable": 1000,
  "defender": 0,
  "occupy_time": 1234567890,
  "end_time": 1234567890,
  "giveUp_time": 0
}
```

---

### 4.6 武将推送

**路由**: `general.push`

**推送内容** (`General`):
```json
{
  "id": 1,
  "cfgId": 1001,
  "physical_power": 100,
  "order": 0,
  "level": 1,
  "exp": 0,
  "cityId": 1,
  "curArms": 1,
  "hasPrPoint": 0,
  "usePrPoint": 0,
  "attack_distance": 1,
  "force_added": 0,
  "strategy_added": 0,
  "defense_added": 0,
  "speed_added": 0,
  "destroy_added": 0,
  "star_lv": 0,
  "star": 5,
  "parentId": 0,
  "skills": [
    {
      "id": 1,
      "lv": 1,
      "cfgId": 2001
    }
  ],
  "state": 0
}
```

---

### 4.7 军队推送

**路由**: `army.push`

**推送内容** (`Army`):
```json
{
  "id": 1,
  "cityId": 1,
  "union_id": 0,
  "order": 1,
  "generals": [1, 2, 0],
  "soldiers": [1000, 2000, 0],
  "con_times": [1234567890, 0, 0],
  "con_cnts": [500, 0, 0],
  "cmd": 0,
  "state": 0,
  "from_x": 100,
  "from_y": 200,
  "to_x": 150,
  "to_y": 250,
  "start": 1234567890,
  "end": 1234567900
}
```

---

### 4.8 联盟申请推送

**路由**: `unionApply.push`

**推送内容** (`ApplyItem`):
```json
{
  "id": 1,               // 申请ID
  "rid": 123,
  "nick_name": "玩家昵称"
}
```

---

### 4.9 战报推送

**路由**: `warReport.push`

**推送内容** (`WarReportPush`):
```json
{
  "list": [
    {
      "id": 1,
      "a_rid": 123,
      "d_rid": 456,
      "b_a_army": "string",
      "b_d_army": "string",
      "e_a_army": "string",
      "e_d_army": "string",
      "b_a_general": "string",
      "b_d_general": "string",
      "e_a_general": "string",
      "e_d_general": "string",
      "result": 2,
      "rounds": "string",
      "a_is_read": false,
      "d_is_read": false,
      "destroy": 100,
      "occupy": 0,
      "x": 100,
      "y": 200,
      "ctime": 1234567890
    }
  ]
}
```

---

### 4.10 技能推送

**路由**: `skill.push`

**推送内容** (`Skill`):
```json
{
  "id": 1,
  "cfgId": 2001,
  "generals": [1, 2, 3]
}
```

---

## 五、Gateserver 说明

Gateserver 作为网关服务器，不提供自己的业务协议，主要负责：

1. **协议转发**：根据消息路由前缀转发到对应的服务器
   - `account.*` → loginserver
   - `chat.*` → chatserver
   - 其他 → slgserver

2. **连接管理**：管理客户端连接和服务器代理连接

3. **消息推送**：将后端服务器的推送消息转发给客户端

---

## 六、协议路由总结

### 按进程分类

| 进程 | 路由前缀 | 协议数量 |
|------|---------|---------|
| loginserver | `account.` | 4 |
| chatserver | `chat.` | 6 |
| slgserver | `role.`, `city.`, `general.`, `army.`, `union.`, `war.`, `skill.`, `interior.`, `nationMap.` | 50+ |

### 推送协议

| 推送路由 | 说明 |
|---------|------|
| `chat.push` | 聊天消息 |
| `roleRes.push` | 资源更新 |
| `roleAttr.push` | 角色属性更新 |
| `roleCity.push` | 城市更新 |
| `roleBuild.push` | 建筑更新 |
| `general.push` | 武将更新 |
| `army.push` | 军队更新 |
| `unionApply.push` | 联盟申请 |
| `warReport.push` | 战报 |
| `skill.push` | 技能更新 |

---

## 七、错误码参考

详细错误码定义请参考 `constant/code.go`，常用错误码：

- `0`: 成功
- `1`: 参数错误
- `2`: 数据库错误
- `16`: 资源不足
- `17`: 超过带兵限制
- `18`: 军队忙碌
- `19`: 武将忙碌
- `24`: 体力不足
- `25`: 政令不足
- `26`: 金币不足
- `34`: 联盟创建失败
- `35`: 联盟不存在
- `36`: 权限不足
- `37`: 已经有联盟
- `39`: 内容太长
- `40`: 不属于该联盟
- `41`: 用户已满
- `42`: 已经申请过了

---

## 八、注意事项

1. **时间戳格式**：所有时间戳均为 Unix 时间戳（秒），部分接口使用毫秒时间戳
2. **数组长度**：武将数组、士兵数组等固定长度数组，未使用的位置为 0
3. **中间件**：大部分 slgserver 协议需要 `CheckRole()` 中间件验证角色
4. **推送机制**：推送基于视野系统，只有视野内的玩家才能收到相关推送
5. **协议路由**：所有协议通过 gateserver 转发，客户端只需连接 gateserver

---

**文档版本**: 1.0  
**最后更新**: 2024

