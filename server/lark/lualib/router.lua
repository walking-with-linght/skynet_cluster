local skynet = require "skynet"
local base = require "base"
local dump = require "dump"
local cjson = require "cjson"

local DATA = base.DATA --本服务使用的表
local CMD = base.CMD  --供其他服务调用的接口
local PUBLIC = base.PUBLIC --本服务调用的接口
local REQUEST = base.REQUEST

REQUEST["/lark/lark_callback"] = function(path, method, headers, body, query)
    if type(body) == "string" then
        body = cjson.decode(body)
    end
    print("收到 lark 事件",path, method)
    print("body",dump(body))
    -- 设置响应头
    local response_headers = {
        ["Content-Type"] = "application/json",
        -- ["Access-Control-Allow-Origin"] = "*", -- 这里写允许访问的域名就可以了，允许所有人访问的话就写*
        -- ["Access-Control-Allow-Credentials"] = false,   
        -- ["Access-Control-Allow-Headers"] = "*",
    }
    if body.challenge and body.type == "url_verification" then
        local ret_content = {
            challenge = body.challenge,
        }
        return 200,ret_content,response_headers
    else
        local event_type = body.event_type
        local deal = require ("lark_callback." .. event_type)
        if deal then
            return deal(body)
        else
            return 200
        end
    end

end
REQUEST["/lark/lark_event"] = function(path, method, headers, body, query)
    if type(body) == "string" then
        body = cjson.decode(body)
    end
    print("收到 lark 事件",path, method)
    -- 设置响应头
    local response_headers = {
        ["Content-Type"] = "application/json",
        -- ["Access-Control-Allow-Origin"] = "*", -- 这里写允许访问的域名就可以了，允许所有人访问的话就写*
        -- ["Access-Control-Allow-Credentials"] = false,   
        -- ["Access-Control-Allow-Headers"] = "*",
    }
    if body.challenge and body.type == "url_verification" then
        local ret_content = {
            challenge = body.challenge,
        }
        return 200,ret_content,response_headers
    else
        skynet.send(".lark_deal_msg", "lua", "lark_event", body)
    end
    return 200
end

return function (path, method, header, body, query)

    -- print(dump({path, method, header, body, query}))
    local f = REQUEST[path]
    if f then
        local code , ret, header = f(path, method, header, body, query)
        -- if not header then
        --     header = {
        --         ["Content-Type"] = "application/json",
        --     }
        -- end
        print("收到 lark 事件",code,ret, path, method)
        return code , ret, header
    end
    return 404
end
