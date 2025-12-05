local skynet = require "skynet"
local redis = require "skynet.db.redis"
local cluster = require "skynet.cluster"
local cjson = require "cjson"
local dump = require "dump"
require "skynet.manager"
local table = table
local string = string
local math = math

local CMD = {}
local redis_conn
local cfg_cluster_type = skynet.getenv("cluster_type")
local cfg_cluster_name = skynet.getenv("cluster_name")
local cfg_cluster_addr = skynet.getenv("cluster_addr")
local discover_key = skynet.getenv("discover_key") or "skynet_discover"

local is_open = false

-- TODO 目前发现一个bug，如果redis断开，并没有重连机制

local HEARTBEAT_INTERVAL = 5 -- 心跳间隔(秒)
local NODE_TIMEOUT = 10 -- 节点超时时间(秒)
local REDIS_CONFIG = {
    host = skynet.getenv("redis_host"),
    port = skynet.getenv("redis_port"),
    db = 1,
    auth 	= skynet.getenv("redis_auth"),
}

-- 当前已知的节点列表
local cluster_nodes = {}   -- nodename = {}

-- 初始化Redis连接
local function init_redis()
    local ok,_redis_conn = pcall(redis.connect,REDIS_CONFIG)
    if not ok or not _redis_conn then
        skynet.error("Failed to connect to Redis",REDIS_CONFIG.host,REDIS_CONFIG.port,REDIS_CONFIG.db,REDIS_CONFIG.auth)
        return false
    end
    redis_conn = _redis_conn
    return true
end

-- 发布节点下线消息
local function publish_offline()
    redis_conn:publish(discover_key .. ":nodes:notify", string.format("offline %s", cfg_cluster_name))
end

-- 更新节点心跳时间
local function update_heartbeat()
    redis_conn:zadd(discover_key .. ":nodes:heartbeat", skynet.time(), cfg_cluster_name)
end

-- 获取存活的节点列表及其地址
local function get_alive_nodes_with_addr()

    local min_score = skynet.time() - NODE_TIMEOUT
    -- 清理过期节点（直接删除早于 min_score 的数据）
    redis_conn:zremrangebyscore(discover_key .. ":nodes:heartbeat", "-inf", min_score)

    local nodes = redis_conn:zrangebyscore(discover_key .. ":nodes:heartbeat", min_score, "+inf")
    
    local result = {}
    for _, node in ipairs(nodes) do
        local node_info = redis_conn:hget(discover_key .. ":nodes:info", node)
        if node_info then
            result[node] = cjson.decode(node_info)
        end
    end
    return result
end

-- 注册节点并发布上线通知(原子性操作)
local function register_node(share_data)
    -- 先注册节点信息(包括地址)
    redis_conn:hset(discover_key .. ":nodes:info", cfg_cluster_name, cjson.encode(share_data))
    
    -- 更新心跳时间
    redis_conn:zadd(discover_key .. ":nodes:heartbeat", skynet.time(), cfg_cluster_name)
    
    -- 最后发布上线通知
    redis_conn:publish(discover_key .. ":nodes:notify", string.format("online %s", cfg_cluster_name))
end



-- 更新集群节点  force_refresh=是否强制刷新
local function update_cluster_nodes(force_refresh)
    local alive_nodes = get_alive_nodes_with_addr()
    local new_nodes = {}
    local changed = false
    
    -- 检查新增节点
    for node_name,info in pairs(alive_nodes) do
        new_nodes[node_name] = info
        if not cluster_nodes[node_name] then
            skynet.error(string.format("New node online: %s", node_name))
            changed = true
        end
    end
    
    if not changed then --有变化就不用再判断下线节点了
        -- 检查下线节点
        for node in pairs(cluster_nodes) do
            if not new_nodes[node] then
                skynet.error(string.format("Node offline offline: %s", node))
                changed = true
                break
            end
        end
    end
    
    if changed or force_refresh then
        cluster_nodes = new_nodes
        -- 这里可以触发集群更新逻辑
        skynet.fork(function()
            -- 重新配置集群
            local nodes = {
                ["__nowaiting"] = true
            }
            for name,info in pairs(cluster_nodes) do
                nodes[name] = info.cluster_addr
                print(name,info.cluster_addr)
            end
            cluster.reload(nodes)
        end)
    end

    if is_open then return end
    is_open = true
    cluster.open(cfg_cluster_name)
    print("cluster open",cfg_cluster_name)
end

-- 处理节点通知消息
local function handle_notify(msg)
    local action, node = string.match(msg, "(%a+)%s+(.+)")
    if not action or not node then return end
    print("watch message:", action, node)
    if action == "online" then
        skynet.error(string.format("Node online notification: %s", node))
        update_cluster_nodes(true)
    elseif action == "offline" then
        skynet.error(string.format("Node offline notification: %s", node))
        update_cluster_nodes(true)
    end
end

-- 心跳检测协程
local function heartbeat_loop()
    while true do
        local ok, err = pcall(update_heartbeat)
        if not ok then
            skynet.error("Heartbeat update failed:", err)
            -- 尝试重新连接Redis
            init_redis()
        end
        
        ok, err = pcall(update_cluster_nodes)
        if not ok then
            skynet.error("Cluster nodes update failed:", err)
        end
        
        skynet.sleep(HEARTBEAT_INTERVAL * 100)
    end
end

-- 订阅节点通知
local function subscribe_notifications()
    local sub_conn = redis.watch(REDIS_CONFIG)
    if not sub_conn then
        skynet.error("Failed to connect to Redis for subscription")
        return
    end
    
    sub_conn:subscribe(discover_key .. ":nodes:notify")
    local reconnect_count = 0
    while true do
        local ok,msg = pcall(sub_conn.message,sub_conn)
        if not ok then
            reconnect_count = reconnect_count + 1
            skynet.error("redis连接异常，正在尝试重新连接...",reconnect_count)
            sub_conn = redis.watch(REDIS_CONFIG)
            if sub_conn then
                skynet.error("redis重新连接成功...",reconnect_count)
                sub_conn:subscribe(discover_key .. ":nodes:notify")
                reconnect_count = 0
            else
                skynet.error("redis连接失败，2秒后将会再次重新连接...",reconnect_count)
                skynet.sleep(2 * 100)-- 等待两秒继续重连
            end
        else
            print("message:", dump(msg))
            pcall(handle_notify, msg)
        end
    end
end

function CMD.get_node(node_type)
    -- print("get_node", node_type,dump(cluster_nodes))
    for _, data in pairs(cluster_nodes) do
        if data.cluster_type == node_type then
            return data.cluster_name
        end
    end
end
function CMD.check_node_online(node_name)
    -- print("get_node_by_name", node_name,dump(cluster_nodes))
    return cluster_nodes[node_name]
end

function CMD.get_node_all(node_type)
    local all = {}
    for name, data in pairs(cluster_nodes) do
        if data.cluster_type == node_type then
            all[name] = data
        end
    end
    -- print("get_node", node_type,dump(cluster_nodes), dump(all))
    return all
end

function CMD.get_all()
    return cluster_nodes
end


function CMD.start(share_data)
    if not init_redis() then
        return false
    end
    if not share_data then
        share_data = {}
    end
    share_data.cluster_type = cfg_cluster_type
    share_data.cluster_name = cfg_cluster_name
    share_data.cluster_addr = cfg_cluster_addr
    
    share_data.timestamp = os.time()

    -- 原子性注册节点
    register_node(share_data)
    
    -- 启动心跳协程
    skynet.fork(heartbeat_loop)
    
    -- 启动订阅协程
    skynet.fork(subscribe_notifications)
    
    -- 初始节点列表更新
    update_cluster_nodes()
    print("redis_discover service started with cluster_name:", cfg_cluster_name)
    return true
end

function CMD.get_nodes()
    local nodes = {}
    for node in pairs(cluster_nodes) do
        table.insert(nodes, node)
    end
    return nodes
end

function CMD.exit()
    publish_offline()
    redis_conn:zrem(discover_key .. ":nodes:heartbeat", cfg_cluster_name)
    redis_conn:disconnect()
end

skynet.start(function()
    skynet.dispatch("lua", function(_, _, cmd, ...)
        local f = CMD[cmd]
        if f then
            skynet.ret(skynet.pack(f(...)))
        else
            skynet.error(string.format("Unknown command %s", cmd))
        end
    end)
    
    -- 注册退出钩子
    -- skynet.info_func(function()
    --     CMD.exit()
    -- end)
    skynet.register(".node_discover")
end)