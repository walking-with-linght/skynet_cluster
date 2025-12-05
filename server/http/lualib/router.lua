local base = require "base"
local dump = require "dump"
local yyjson = require "cjson"

local DATA = base.DATA --本服务使用的表
local CMD = base.CMD  --供其他服务调用的接口
local PUBLIC = base.PUBLIC --本服务调用的接口
local REQUEST = base.REQUEST

require "user"
require "login"
require "node"

return function (path, method, header, body, query)


    -- print("http request path=",path)
    -- print("http request method=", method)
    -- print("http request header=",header)
    -- print("http request body=",body)
    -- print("http request query=",query)
    print(dump({path, method, header, body, query}))
    local f = REQUEST[path]
    if f then
        return f(path, method, header, body, query)
    end
    return 200,"hello"
end
