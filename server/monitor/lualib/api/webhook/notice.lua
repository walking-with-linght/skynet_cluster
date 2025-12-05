local base = require "base"
local cjson = require "cjson"
local msgpack = require "msgpack"
local skynet= require "skynet"
cjson.encode_sparse_array(true)
local DATA = base.DATA     --本服务使用的表
local CMD = base.CMD       --供其他服务调用的接口
local PUBLIC = base.PUBLIC --本服务调用的接口
local utils = require "utils"

local REQUEST = base.REQUEST
local sms = require "api.sms"




-- 通用提示
REQUEST["/webhhok/notice"] = function(path, method, header, body, query)
    if method ~= "POST" then return 405 end
    local data = cjson.decode(body)
    if not data then
        return 400
    end
    print(dump(body))
    -- sms.send_sms_bao("=",)
    return 200
end
