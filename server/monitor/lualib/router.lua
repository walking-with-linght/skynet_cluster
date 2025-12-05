local skynet = require "skynet"
local base = require "base"
local dump = require "dump"
local yyjson = require "cjson"
local router
local DATA = base.DATA --本服务使用的表
local CMD = base.CMD  --供其他服务调用的接口
local PUBLIC = base.PUBLIC --本服务调用的接口
local REQUEST = base.REQUEST

require "api.web.login"
require "api.node.cybet"
require "api.webhook.notice"

return function (path, method, header, body, query)

    print(dump({path, method, header, body, query}))
    local f = REQUEST[path]
    if f then
        local code , ret, header = f(path, method, header, body, query)
        if not header then
            header = {
                ["Content-Type"] = "application/json",
            }
        end
        return code , ret, header
    end
    return 404
end
