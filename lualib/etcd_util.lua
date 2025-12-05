local skynet = require "skynet"
local etcd = require "etcd.etcd3"
local json = require "cjson"
local dump = require "dump"

local M = {}
local client

local etcd_hosts = skynet.getenv("etcd_hosts")  or "http://127.0.0.1:2379"
local etcd_user = skynet.getenv("etcd_user")    or "root"
local etcd_password = skynet.getenv("etcd_password")
local etcd_base_path = skynet.getenv("etcd_base_path") or "/data/"
local node_config_path = "/skynet/nodes/"

function M.init()
    client = etcd.new({
        http_host = etcd_hosts,
        user = etcd_user,
        password = etcd_password,
        protocol = "v3",
        timeout = 3,
        -- key_prefix = etcd_base_path,
        serializer = "json"  -- 默认使用json格式配置
    })
    print("etcd connect",client)
    M.client = client
end

-- 服务注册
function M.register_node(node_name, node_info)
    local key =  node_config_path .. node_name
    local res,err = client:grant(10)  -- 10秒租约
    print(res,err)
    local lease_id = res.body.ID
    local ok, err = client:set(key, json.encode(node_info), {lease = lease_id})
    if not ok then
        client:revoke(lease_id)
        return nil, err
    end
    
    -- 自动续约
    skynet.fork(function()
        while true do
            skynet.sleep(500)  -- 5秒续约一次
            client:keepalive(lease_id)
        end
    end)
    
    return lease_id
end
-- 获取所有节点
function M.get_nodes()
    local resp = client:readdir(node_config_path)
    local nodes = {}
    if resp and resp.body then
        for _, kv in ipairs(resp.body.kvs or {}) do
            local name = string.sub(kv.key, #node_config_path + 1)
            nodes[name] = {data = json.decode(kv.value),type = "join"}
        end
    end
    
    -- print("格式化所有节点",dump(nodes))
    return nodes
end
-- 监听节点变化
function M.watch_nodes(callback)
    local prefix = node_config_path
    
    -- 初始获取
    local init_nodes = M.get_nodes()
    callback(init_nodes, "init")
    
    skynet.fork(function()
        while true do
            local watch_fun <close>, err = client:watchdir(prefix)
            if err then
                skynet.error "watch hello failed."
                return
            end
            
            for ret, werr, stream in watch_fun do
                -- print("节点更新",dump(ret.result.events))
                local changes = {}
                for _, event in ipairs(ret.result.events or {}) do
                    local name = string.sub(event.kv.key, #prefix + 1)
                    if event.type == "PUT" then
                        changes[name] = {type = "join", data = json.decode(event.kv.value)}
                    else
                        changes[name] = {type = "leave"}
                    end
                    -- skynet.error(string.format("watch type:%s key:%s value:%s", ev.type, ev.kv.key, util_table.tostring(ev.kv.value)))
                end
                if next(changes) then
                    -- print("watch 更新节点",dump(changes))
                    callback(changes)
                end
            end
            
        end
    end)
end

-- 删除节点
function M.remove_node(node_name)
    return client:delete(node_config_path .. node_name)
end


return M