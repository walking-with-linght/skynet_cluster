local skynet = require "skynet"

local base = require "base"
local cjson = require "cjson"
local utils = require "utils"
local DATA = base.DATA     --本服务使用的表
local CMD = base.CMD       --供其他服务调用的接口
local PUBLIC = base.PUBLIC --本服务调用的接口



-- method 大写
function PUBLIC.http_request(host, url, header,method,body)
    if not host then
        return false, "host is nil"
    end
    local opts = {}
    opts.method = method or "GET"
    opts.headers = header or {}
    
    if type(body) == "table" then
        opts.body = cjson.encode(body)
        opts.headers["Content-Type"] = opts.headers["Content-Type"] or "application/json"
    end
    if body and (type(body) == "string" or type(body) == "number") then
        opts.body = body
    end
    opts.noBody = opts.body == nil
    opts.noHeader = table.count(opts.headers) == 0
    
    local ok,callok , code,ret = CMD.cluster_call_by_type("moon","http", "request", host .. url, opts)
    if not ok or not callok or code ~= 200 then
        skynet.error("http request fail",host, url, method, dump(opts), ok, callok, code, dump(ret))
        return code, "http request fail"
    end
    return code ,ret.body, ret.headers
end