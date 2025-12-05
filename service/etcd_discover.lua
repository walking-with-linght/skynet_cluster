local skynet = require "skynet"
local etcd_util = require "etcd_util"
local cluster = require "skynet.cluster"
local dump = require "dump"
require "skynet.manager"

local CMD = {}
local cluster_config = {}               -- 在线的节点数据，name = addr
local cluster_data = {}
local cfg_cluster_type = skynet.getenv("cluster_type")
local cfg_cluster_name = skynet.getenv("cluster_name")
local cfg_cluster_addr = skynet.getenv("cluster_addr")


local is_open = false

function CMD.reload_cluster()
    -- 确保至少包含当前节点的配置
    if not cluster_config[cfg_cluster_name] then
        error(string.format("Missing self config for node %s", cfg_cluster_name))
    end
    print("cluster 执行一次",cfg_cluster_name,dump(cluster_config))
    -- 首次初始化
    cluster_config["__nowaiting"] = true
    cluster.reload(cluster_config)
    if is_open then return end
    is_open = true
    cluster.open(cfg_cluster_name)
end


function CMD.ping()
    return "pong"
end

function CMD.get_node(node_type)
    for key, data in pairs(cluster_data) do
        if data.cluster_type == node_type then
            return data.cluster_name
        end
    end
end

function CMD.get_node_all(node_type)
    local all = {}
    for key, data in pairs(cluster_data) do
        if data.cluster_type == node_type then
            all[key] = data
        end
    end
    return all
end

function CMD.get_all()
    return cluster_data
end

-- 节点加入处理
function CMD.node_join(node_name, node_info)
    skynet.error(string.format("[ETCD] Node joined: %s at %s", node_name, node_info.cluster_addr))
    -- 可以在这里做负载均衡等逻辑
    cluster_config[node_name] = node_info.cluster_addr
    cluster_data[node_name] = node_info
    
end

-- 节点离开处理
function CMD.node_leave(node_name)
    skynet.error(string.format("[ETCD] Node left: %s", node_name))
    -- 可以在这里做服务迁移等逻辑
    cluster_config[node_name] = nil
    cluster_data[node_name] = nil

end


-- 启动节点监听
function CMD.start(share_data)
    etcd_util.init()
    -- 初始化默认集群配置
    cluster_config[cfg_cluster_name] = cfg_cluster_addr
    -- 初始化cluster
    CMD.reload_cluster()
    if not share_data then
        share_data = {}
    end
    share_data.cluster_type = cfg_cluster_type
    share_data.cluster_name = cfg_cluster_name
    share_data.cluster_addr = cfg_cluster_addr
    
    share_data.timestamp = os.time()
    -- 先注册自己
    etcd_util.register_node(cfg_cluster_name, share_data)

    etcd_util.watch_nodes(function(changes,init)
        -- print(init,dump(changes))
        for node_name, change in pairs(changes) do
            if change.type == "join" then
                CMD.node_join(node_name, change.data)
            else
                CMD.node_leave(node_name)
            end
        end
        CMD.reload_cluster()
    end)
end


skynet.start(function()
    skynet.dispatch("lua", function(_, _, cmd, ...)
        local f = assert(CMD[cmd], cmd .. " not found")
        skynet.retpack(f(...))
    end)
    -- CMD.start()
    skynet.register(".node_discover")
end)