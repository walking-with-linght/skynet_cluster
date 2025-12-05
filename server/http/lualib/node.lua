
local skynet = require "skynet"
local base = require "base"
local utils = require "utils"
local dump = require "dump"
local yyjson = require "cjson"

local DATA = base.DATA --本服务使用的表
local CMD = base.CMD  --供其他服务调用的接口
local PUBLIC = base.PUBLIC --本服务调用的接口
local REQUEST = base.REQUEST


REQUEST["/geeker/get_node_list"] = function(path, method, header, body, query)
    local data = {}
    data.code = 200
    -- data.data = {
    --     {
    --         id = 1,
    --         name = "节点1",
    --         children = {
    --             {
    --                 id = "11",
    --                 name = "研发部11"
    --             },
    --             {
    --                 id = "12",
    --                 name = "研发部12"
    --             },
    --         },
    --     },
    --     {
    --         id = 2,
    --         name = "节点2",
    --         children = {
    --             {
    --                 id = "21",
    --                 name = "研发部21"
    --             },
    --             {
    --                 id = "22",
    --                 name = "研发部22"
    --             },
    --         },
    --     },
    -- }
    data.msg = "成功"
    data.data = {}


    local node_all = skynet.call(".node_discover","lua","get_all")
    print(dump(node_all))
    data.data[1] = {
        id = 1,
        name = "内网",
        children = {}
    }

    for key, value in pairs(node_all) do
        table.insert(data.data[1].children,{
            id = key,
            name = value.cluster_name,
        })
    end
	return 200,data
end

REQUEST["/api/skynet/nodedetail"] = function (path, method, header, body, query)
    print(dump(yyjson.decode(body)))
    return 200,{code = 0}
end