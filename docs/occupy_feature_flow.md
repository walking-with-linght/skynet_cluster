# 占领功能完整流程文档

本文档详细说明玩家点击占领后，从客户端发送协议到军队回城的完整流程。

---

## 一、功能概述

**占领功能**：玩家选择一块土地，派遣军队前往占领。军队从城内出发，移动到目标地块，到达后立即进行战斗，战斗结束后自动回城。

---

## 二、完整流程

### 阶段1：客户端发送占领请求

#### 2.1 客户端操作
1. 玩家点击地图上的目标地块
2. 弹出操作菜单，选择"占领"
3. 选择要派遣的军队（队伍编号 1-5）
4. 客户端发送协议

#### 2.2 客户端发送的协议

**协议路由**: `army.assign`

**请求内容** (`AssignArmyReq`):
```json
{
  "armyId": 1,            // 军队ID
  "cmd": 1,              // 命令：1=攻击（占领）
  "x": 150,              // 目标地块X坐标
  "y": 250               // 目标地块Y坐标
}
```

**代码位置**: `server/slgserver/controller/army.go:357`

---

### 阶段2：服务器验证和预处理

#### 2.1 验证流程 (`__pre__`)

服务器执行以下验证：

1. **坐标验证**
   - 检查坐标是否在有效范围内
   - 检查目标位置是否有可攻击的建筑

2. **军队状态验证**
   - 检查军队是否空闲（`IsIdle()`）
   - 检查军队是否可以出征（`IsCanOutWar()`）
   - 检查军队是否忙碌

3. **路径验证**
   - 检查是否可以到达目标位置（`IsCanArrive()`）

4. **目标验证**
   - 检查目标是否免战（`IsWarFree()`）
   - 检查目标是否可以被攻击（`IsCanDefend()` - 不能是自己的领地）

**代码位置**: `server/slgserver/controller/army.go:393`

#### 2.2 攻击验证 (`__attack__`)

如果验证通过，继续执行：

1. **再次路径验证**
2. **免战检查** - 如果目标在免战期内，返回错误
3. **防御检查** - 如果是自己的领地，不能攻击

**代码位置**: `server/slgserver/controller/army.go:483`

---

### 阶段3：计算移动时间和速度

#### 3.1 速度计算 (`GetSpeed`)

**军队速度 = 队伍中最慢武将的速度 + 阵营加成**

计算步骤：

1. **获取队伍中所有武将的速度**
   ```go
   // 遍历队伍中的武将，取最小速度
   speed := 100000  // 初始值很大
   for _, g := range army.Gens {
       if g != nil {
           s := g.GetSpeed()  // 获取武将速度
           if s < speed {
               speed = s  // 取最小值（木桶效应）
           }
       }
   }
   ```

2. **武将速度计算** (`GetSpeed`)
   ```go
   // 武将速度 = 基础速度 + 等级成长 + 加点加成
   cfg.Speed + cfg.SpeedGrow * Level + SpeedAdded
   ```
   - `cfg.Speed`: 武将配置的基础速度
   - `cfg.SpeedGrow`: 每级成长速度
   - `Level`: 武将当前等级
   - `SpeedAdded`: 玩家手动加点的速度加成

3. **阵营加成**
   ```go
   // 根据武将阵营（汉、魏、蜀、吴、群）获取城市设施加成
   campAdds := RFMgr.GetAdditions(cityId, facility.TypeHanAddition-1+camp)
   speed = speed + campAdds[0]
   ```

**代码位置**: 
- `server/slgserver/logic/mgr/army_mgr.go:223`
- `server/slgserver/model/general.go:180`

#### 3.2 移动时间计算 (`TravelTime`)

**计算公式**:
```go
// 1. 计算两点间距离（欧几里得距离）
distance = sqrt((endX - begX)² + (endY - begY)²)

// 2. 计算移动时间（毫秒）
travelTime = (distance / speed) * 100000000
```

**说明**:
- 距离使用欧几里得距离公式（直线距离）
- 时间单位：毫秒
- 速度越大，时间越短
- 公式中的 `100000000` 是时间换算系数

**代码位置**: `server/slgserver/logic/mgr/national_map_mgr.go:42`

#### 3.3 设置移动时间

```go
if global.IsDev() {
    // 开发模式：固定40秒
    army.Start = time.Now()
    army.End = time.Now().Add(40 * time.Second)
} else {
    // 正式模式：根据速度和距离计算
    speed := mgr.AMgr.GetSpeed(army)
    t := mgr.TravelTime(speed, army.FromX, army.FromY, army.ToX, army.ToY)
    army.Start = time.Now()
    army.End = time.Now().Add(time.Duration(t) * time.Millisecond)
}
```

**代码位置**: `server/slgserver/controller/army.go:449`

---

### 阶段4：消耗资源和启动移动

#### 4.1 资源消耗

1. **消耗体力**
   - 每个武将消耗固定体力值（`Basic.General.CostPhysicalPower`）
   - 检查所有武将体力是否足够

2. **更新军队状态**
   - `army.ToX = reqObj.X` - 设置目标X
   - `army.ToY = reqObj.Y` - 设置目标Y
   - `army.Cmd = model.ArmyCmdAttack` - 设置命令为攻击
   - `army.State = model.ArmyRunning` - 设置状态为运行中

**代码位置**: `server/slgserver/controller/army.go:425`

#### 4.2 启动移动

```go
logic.ArmyLogic.PushAction(army)
```

将军队加入行动队列，等待到达时间触发。

**代码位置**: `server/slgserver/controller/army.go:459`

---

### 阶段5：军队移动过程

#### 5.1 实时位置计算

服务器会持续计算军队的实时位置：

```go
// 计算已过时间比例
diffTime := End.Unix() - Start.Unix()  // 总时间
passTime := time.Now().Unix() - Start.Unix()  // 已过时间
rate := passTime / diffTime  // 进度比例

// 计算当前位置
diffX := ToX - FromX
diffY := ToY - FromY
currentX = FromX + diffX * rate
currentY = FromY + diffY * rate
```

**代码位置**: `server/slgserver/model/army.go:270`

#### 5.2 位置推送

- 当军队位置跨越格子边界时，会触发推送
- 推送协议：`army.push`
- 推送范围：视野内的玩家（8x6 格子范围）

**推送内容**:
```json
{
  "id": 1,
  "cmd": 1,              // 攻击命令
  "state": 0,            // 运行中
  "from_x": 100,
  "from_y": 200,
  "to_x": 150,
  "to_y": 250,
  "start": 1234567890,   // 开始时间戳
  "end": 1234568000      // 到达时间戳
}
```

**代码位置**: `server/slgserver/model/army.go:320`

---

### 阶段6：军队到达目标

#### 6.1 到达触发

当 `time.Now() >= army.End` 时，触发到达事件：

```go
func (this *ArmyLogic) exeArrive(army *model.Army) {
    if army.Cmd == model.ArmyCmdAttack {
        // 验证是否可以攻击
        if check.IsCanArrive(...) && 
           check.IsWarFree(...) == false && 
           check.IsCanDefend(...) == false {
            // 触发战斗
            war.NewBattle(army, this)
        } else {
            // 无法攻击，创建空战报
            emptyWar := war.NewEmptyWar(army)
            emptyWar.SyncExecute()
        }
        // 战斗结束后回城
        this.ArmyBack(army)
    }
}
```

**代码位置**: `server/slgserver/logic/army/army_logic.go:232`

#### 6.2 战斗流程

1. **查找防守方**
   - 如果是城市：查找城市内的驻守军队和空闲军队
   - 如果是建筑：查找建筑位置的驻守军队或系统军队

2. **执行战斗**
   - 如果有防守方：进行回合制战斗
   - 如果没有防守方：直接破坏耐久

3. **战斗结果处理**
   - 生成战报（`warReport.push`）
   - 如果胜利且耐久归零：占领建筑/城市
   - 如果失败：不占领

**代码位置**: `server/slgserver/logic/war/army_war.go:99`

---

### 阶段7：战斗结束和回城

#### 7.1 回城触发

战斗结束后，自动触发回城：

```go
this.ArmyBack(army)
```

**代码位置**: `server/slgserver/logic/army/army_logic.go:242`

#### 7.2 回城时间计算

回城使用**相同的移动速度和时间**：

```go
// 计算回城时间
speed := mgr.AMgr.GetSpeed(army)
t := mgr.TravelTime(speed, army.FromX, army.FromY, army.ToX, army.ToY)
army.Start = time.Now()
army.End = time.Now().Add(time.Duration(t) * time.Millisecond)

// 设置回城命令
army.Cmd = model.ArmyCmdBack
army.State = model.ArmyRunning
```

**注意**: 
- 回城时 `FromX/FromY` 是目标位置
- 回城时 `ToX/ToY` 是城市位置
- 使用相同的速度计算

**代码位置**: `server/slgserver/logic/army/army_logic.go:466`

#### 7.3 回城移动

回城过程中：
- 持续推送位置更新（`army.push`）
- 命令变为 `cmd = 3`（返回）
- 状态保持 `state = 0`（运行中）

#### 7.4 回城到达

当军队回到城市时：
- 状态变为 `state = 1`（停止）
- 命令变为 `cmd = 0`（空闲）
- 推送最终状态（`army.push`）

---

## 三、关键数据结构和计算

### 3.1 速度计算公式

```
武将速度 = 基础速度 + (等级成长速度 × 等级) + 手动加点速度
军队速度 = min(所有武将速度) + 阵营加成
```

**示例**:
- 武将A：基础速度100，等级10，成长5，加点10
  - 速度 = 100 + (5 × 10) + 10 = 160
- 武将B：基础速度120，等级8，成长6，加点0
  - 速度 = 120 + (6 × 8) + 0 = 168
- 军队速度 = min(160, 168) = 160（取最小值）
- 加上阵营加成（假设+20）= 180

### 3.2 移动时间计算公式

```
距离 = sqrt((目标X - 起始X)² + (目标Y - 起始Y)²)
移动时间(毫秒) = (距离 / 军队速度) × 100000000
```

**示例**:
- 起始位置：(100, 200)
- 目标位置：(150, 250)
- 距离 = sqrt((150-100)² + (250-200)²) = sqrt(2500 + 2500) = 70.71
- 军队速度 = 180
- 移动时间 = (70.71 / 180) × 100000000 = 39,283,333 毫秒 ≈ 39.3 秒

### 3.3 实时位置计算

```
已过时间 = 当前时间 - 开始时间
总时间 = 结束时间 - 开始时间
进度比例 = 已过时间 / 总时间

当前位置X = 起始X + (目标X - 起始X) × 进度比例
当前位置Y = 起始Y + (目标Y - 起始Y) × 进度比例
```

---

## 四、服务器推送消息

在整个流程中，服务器会推送以下消息：

### 4.1 军队移动推送

**推送路由**: `army.push`

**推送时机**:
- 军队开始移动时
- 军队位置跨越格子边界时
- 军队到达目标时
- 军队开始回城时
- 军队回到城市时

**推送内容**:
```json
{
  "id": 1,
  "cityId": 1,
  "order": 1,
  "cmd": 1,              // 1=攻击, 3=返回
  "state": 0,            // 0=运行中, 1=停止
  "from_x": 100,
  "from_y": 200,
  "to_x": 150,
  "to_y": 250,
  "start": 1234567890,   // 开始时间戳（秒）
  "end": 1234567929      // 结束时间戳（秒）
}
```

### 4.2 战报推送

**推送路由**: `warReport.push`

**推送时机**: 战斗结束后

**推送内容**:
```json
{
  "list": [{
    "id": 1,
    "a_rid": 123,        // 攻击者
    "d_rid": 456,        // 防御者
    "result": 2,         // 0=失败, 1=打平, 2=胜利
    "destroy": 100,      // 破坏耐久
    "occupy": 1,         // 是否占领
    "x": 150,
    "y": 250,
    "ctime": 1234567929
  }]
}
```

### 4.3 建筑/城市更新推送

**推送路由**: `roleBuild.push` 或 `roleCity.push`

**推送时机**: 建筑/城市被占领或耐久变化时

---

## 五、完整时序图

```
客户端                    服务器
  |                         |
  |-- army.assign (攻击) -->|
  |                         | 1. 验证请求
  |                         | 2. 计算速度和时间
  |                         | 3. 消耗体力
  |                         | 4. 启动移动
  |<-- army.push (开始) ---|
  |                         |
  |<-- army.push (移动中) --| (持续推送位置)
  |                         |
  |                         | 5. 到达目标
  |                         | 6. 触发战斗
  |                         | 7. 执行战斗逻辑
  |<-- warReport.push -----| 8. 推送战报
  |                         | 9. 处理占领结果
  |<-- roleBuild.push -----| (如果占领成功)
  |                         | 10. 启动回城
  |<-- army.push (回城) ---|
  |                         |
  |<-- army.push (回城中) --| (持续推送位置)
  |                         |
  |                         | 11. 回到城市
  |<-- army.push (到达) ---|
  |                         |
```

---

## 六、需要实现的功能点

### 6.1 客户端需要实现

1. **UI交互**
   - 地块点击检测
   - 操作菜单显示
   - 军队选择界面

2. **协议发送**
   - 发送 `army.assign` 请求
   - 处理响应和错误码

3. **移动表现**
   - 接收 `army.push` 推送
   - 根据 `start` 和 `end` 时间计算实时位置
   - 平滑移动动画（从 `from_x/from_y` 到 `to_x/to_y`）
   - 显示移动进度

4. **战斗表现**
   - 接收 `warReport.push` 推送
   - 显示战斗结果
   - 显示占领结果

5. **回城表现**
   - 接收回城的 `army.push` 推送
   - 从目标位置平滑移动回城市
   - 显示回城进度

### 6.2 服务器已实现

1. ✅ 协议验证
2. ✅ 速度计算
3. ✅ 移动时间计算
4. ✅ 实时位置计算
5. ✅ 战斗逻辑
6. ✅ 占领逻辑
7. ✅ 回城逻辑
8. ✅ 推送机制

---

## 七、注意事项

### 7.1 速度计算要点

1. **木桶效应**: 军队速度 = 最慢武将的速度
2. **阵营加成**: 根据武将阵营和城市设施计算
3. **速度影响**: 速度越高，移动时间越短

### 7.2 时间计算要点

1. **开发模式**: 固定40秒（方便测试）
2. **正式模式**: 根据速度和距离动态计算
3. **时间单位**: 毫秒
4. **实时计算**: 服务器会根据当前时间计算实时位置

### 7.3 推送机制要点

1. **位置推送**: 当位置跨越格子边界时推送
2. **视野系统**: 只有视野内的玩家才能收到推送
3. **推送频率**: 可能很频繁，客户端需要做节流

### 7.4 战斗要点

1. **立即战斗**: 到达后立即战斗，不等待
2. **战斗结果**: 胜利且耐久归零才能占领
3. **自动回城**: 无论胜负都会自动回城

---

## 八、示例代码（客户端伪代码）

```javascript
// 1. 发送占领请求
function occupyLand(x, y, armyId) {
    sendRequest('army.assign', {
        armyId: armyId,
        cmd: 1,  // 攻击
        x: x,
        y: y
    });
}

// 2. 处理军队推送
function handleArmyPush(army) {
    if (army.cmd === 1) {  // 攻击中
        // 计算实时位置
        const now = Date.now() / 1000;
        const start = army.start;
        const end = army.end;
        const progress = (now - start) / (end - start);
        
        const currentX = army.from_x + (army.to_x - army.from_x) * progress;
        const currentY = army.from_y + (army.to_y - army.from_y) * progress;
        
        // 更新军队位置显示
        updateArmyPosition(army.id, currentX, currentY);
    } else if (army.cmd === 3) {  // 回城中
        // 同样的位置计算逻辑
        // ...
    }
}

// 3. 处理战报推送
function handleWarReportPush(report) {
    showBattleResult(report.list[0]);
    if (report.list[0].occupy === 1) {
        showOccupySuccess();
    }
}
```

---

**文档版本**: 1.0  
**最后更新**: 2024

