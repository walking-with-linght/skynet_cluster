local skynet = require "skynet"
local base = require "base"
local cjson = require "cjson"
local error_code = require "rank_error_code"

local DATA = base.DATA --本服务使用的表
local CMD = base.CMD  --供其他服务调用的接口
local PUBLIC = base.PUBLIC --本服务调用的接口
local REQUEST = base.REQUEST

--直接修改分数
REQUEST["/rank/update_score_direct"] = function(path, method, header, body, query)
    if method ~= "POST" then
        return 200,{code = error_code.method_error}
    end
    body = cjson.decode(body)
    local rank_type = body.rank_type
    local player_id = body.player_id
    local score = body.score
    local extdata = body.extdata
    if not rank_type or rank_type == "" then
        return 200,{code = error_code.rank_type_error, msg = "rank_type error" }
    end
    if not player_id or player_id == "" then
        return 200,{code = error_code.playerid_error , msg = "player_id error" }
    end
    if not score or type(score) ~= "number" then
        return 200,{code = error_code.score_type_error , msg = "score error" }
    end
    if extdata and type(extdata) ~= "string" then
        return 200,{code = error_code.extdata_type_error, msg = "extdata error" }
    end
    local ok,why = skynet.call(".common_rank","lua","update_score_direct",rank_type,player_id,score,extdata)
    if ok then
        return 200,{code = 0, score = why.score}
    end
    return 200,{code = 99,msg = why}
end

--更新分数，在原基础上增减
REQUEST["/rank/update_score"] = function(path, method, header, body, query)
    if method ~= "POST" then
        return 200,{code = error_code.method_error}
    end
    body = cjson.decode(body)
    local rank_type = body.rank_type
    local player_id = body.player_id
    local delta_score = body.delta_score
    local extdata = body.extdata
    if not rank_type or rank_type == "" then
        return 200,{code = error_code.rank_type_error , msg = "rank_type error" }
    end
    if not player_id or player_id == "" then
        return 200,{code = error_code.playerid_error , msg = "player_id error" }
    end
    if not delta_score or type(delta_score) ~= "number" then
        return 200,{code = error_code.score_type_error , msg = "delta_score error" }
    end
    if extdata and type(extdata) ~= "string" then
        return 200,{code = error_code.extdata_type_error, msg = "extdata error" }
    end
    local ok,why = skynet.call(".common_rank","lua","update_score",rank_type,player_id,delta_score,extdata)
    if ok then
        return 200,{code = 0, score = why.score}
    end
    return 200,{code = 99,msg = why}
end

--批量更新分数，在原基础上增减
REQUEST["/rank/batch_update_score"] = function(path, method, header, body, query)
    if method ~= "POST" then
        return 200,{code = error_code.method_error}
    end
    body = cjson.decode(body)
    local rank_type = body.rank_type
    if not rank_type or rank_type == "" then
        return 200,{code = error_code.rank_type_error , msg = "rank_type error" }
    end

    local updates = body.updates
    if not updates or type(updates) ~= "table" then
        return 200,{code = error_code.updates_type_error, msg = "updates error" }
    end
    if not updates[1] then
        return 200,{code = error_code.updates_data_not_be_none, msg = "updates 不能为空" }
    end
    for _, d in ipairs(updates) do
        if not d.player_id or d.player_id == "" then
            return 200,{code = error_code.playerid_error , msg = "player_id 必须为字符串" }
        end
        if not d.delta_score or type(d.delta_score) ~= "number" then
            return 200,{code = error_code.score_type_error , msg = "delta_score 必须是数字" }
        end
        if d.extra_data and type(d.extra_data) ~= "string" then
            return 200,{code = error_code.extdata_type_error, msg = "extdata 若设置必须是字符串" }
        end
    end
    
    local ok,why = skynet.call(".common_rank","lua","batch_update_score",rank_type, updates)
    if ok then
        return 200,{code = 0}
    end
    return 200,{code = error_code.internal_error,msg = why}
end

--批量直接更新分数
REQUEST["/rank/batch_update_score_direct"] = function(path, method, header, body, query)
    if method ~= "POST" then
        return 200,{code = error_code.method_error}
    end
    body = cjson.decode(body)
    local rank_type = body.rank_type
    if not rank_type or rank_type == "" then
        return 200,{code = error_code.rank_type_error , msg = "rank_type error" }
    end
    local updates = body.updates
    if not updates or type(updates) ~= "table" then
        return 200,{code = error_code.updates_type_error, msg = "updates 不能为空" }
    end
    if not updates[1] then
        return 200,{code = error_code.updates_data_not_be_none, msg =  "updates 不能为空" }
    end
    for _, d in ipairs(updates) do
        if not d.player_id or d.player_id == "" then
            return 200,{code = error_code.playerid_error , msg = "player_id 必须是字符串" }
        end
        if not d.score or type(d.score) ~= "number" then
            return 200,{code = error_code.score_type_error , msg = "score 必须是数字" }
        end
        if d.extra_data and type(d.extra_data) ~= "string" then
            return 200,{code = error_code.extdata_type_error, msg = "extdata 若设置必须是字符串" }
        end
    end
    
    local ok,why = skynet.call(".common_rank","lua","batch_update_score_direct",rank_type, updates)
    if ok then
        return 200,{code = 0}
    end
    return 200,{code = error_code.internal_error,msg = why}
end

--获取用户数据
REQUEST["/rank/get_player_info"] = function(path, method, header, body, query)
    if method ~= "POST" then
        return 200,{code = error_code.method_error}
    end
    body = cjson.decode(body)
    local rank_type = body.rank_type
    local player_id = body.player_id
    if not rank_type or rank_type == "" then
        return 200,{code = error_code.rank_type_error , msg = "rank_type error" }
    end
    if not player_id or player_id == "" then
        return 200,{code = error_code.playerid_error , msg = "player_id error" }
    end
    local ok,why = skynet.call(".common_rank","lua","get_player_info",rank_type,player_id)
    if ok then
        return 200,{code = 0, data = why}
    end
    return 200,{code = 99,msg = why}
end

--获取用户数据
REQUEST["/rank/get_top_n"] = function(path, method, header, body, query)
    if method ~= "POST" then
        return 200,{code = error_code.method_error}
    end
    body = cjson.decode(body)
    local rank_type = body.rank_type
    local n = body.n
    local with_extras = body.with_extras
    if not rank_type or rank_type == "" then
        return 200,{code = error_code.rank_type_error , msg = "rank_type error" }
    end
    if not n or type(n) ~= "number" or math.ceil(n) ~= n or n < 1 then
        return 200,{code = error_code.n_type_error , msg = "n 字段错误" }
    end
    if with_extras == nil then
        with_extras = true
    end
    if type(with_extras) ~= "boolean" then
        return 200,{code = error_code.with_extras_type_error , msg = "with_extras 若设置必须是布尔类型" }
    end
    local ok,why = skynet.call(".common_rank", "lua","get_top_n",rank_type,n,with_extras)
    print(dump({ok,why}))
    if ok then
        return 200,{code = 0, data = why}
    end
    return 200,{code = 99,msg = why}
end

--获取指定排名范围内用户
REQUEST["/rank/get_range"] = function(path, method, header, body, query)
    if method ~= "POST" then
        return 200,{code = error_code.method_error}
    end
    body = cjson.decode(body)
    local rank_type = body.rank_type
    local start_rank = body.start_rank or 1
    local end_rank = body.end_rank or start_rank
    local with_extras = body.with_extras
    if not rank_type or rank_type == "" then
        return 200,{code = error_code.rank_type_error , msg = "rank_type error" }
    end
    if not start_rank or type(start_rank) ~= "number" or math.ceil(start_rank) ~= start_rank or start_rank < 1 then
        return 200,{code = error_code.start_rank_type_error , msg = "start_rank 字段无效" }
    end
    if not end_rank or type(end_rank) ~= "number" or math.ceil(end_rank) ~= end_rank or end_rank < 1 or end_rank < start_rank then
        return 200,{code = error_code.end_rank_type_error , msg = "end_rank 字段无效" }
    end
    if with_extras == nil then
        with_extras = true
    end
    if type(with_extras) ~= "boolean" then
        return 200,{code = error_code.with_extras_type_error , msg = "with_extras 若设置必须是布尔类型" }
    end
    local ok,why = skynet.call(".common_rank","lua","get_range",rank_type,start_rank, end_rank, with_extras)
    if ok then
        return 200,{code = 0, data = why}
    end
    return 200,{code = 99,msg = why}
end

--删除玩家
REQUEST["/rank/remove_player"] = function(path, method, header, body, query)
    if method ~= "POST" then
        return 200,{code = error_code.method_error}
    end
    body = cjson.decode(body)
    local rank_type = body.rank_type
    local player_id = body.player_id
    if not rank_type or rank_type == "" then
        return 200,{code = error_code.rank_type_error , msg = "rank_type error" }
    end
    if not player_id or player_id == "" then
        return 200,{code = error_code.playerid_error , msg = "player_id error" }
    end
    local ok,why = skynet.call(".common_rank","lua","remove_player",rank_type, player_id)
    if ok then
        return 200,{code = ok and error_code.ok or error_code.delete_error}
    end
    return 200,{code = 99,msg = why}
end

--批量删除玩家
REQUEST["/rank/batch_remove_player"] = function(path, method, header, body, query)
    if method ~= "POST" then
        return 200,{code = error_code.method_error}
    end
    body = cjson.decode(body)
    local rank_type = body.rank_type
    local player_ids = body.player_ids
    if not rank_type or rank_type == "" then
        return 200,{code = error_code.rank_type_error , msg = "rank_type error" }
    end
    if not player_ids or type(player_ids) ~= "table" then
        return 200,{code = error_code.player_ids_type_error , msg = "player_ids error" }
    end
    for _, value in ipairs(player_ids) do
        if type(value) ~= "string" then
            return 200,{code = error_code.player_ids_index_type_error , msg = "player_ids 中每一项应当为字符串" }
        end
    end
    local ok,why = skynet.call(".common_rank","lua","batch_remove_player",rank_type, player_ids)
    if ok then
        return 200,{code = ok and error_code.ok or error_code.delete_error}
    end
    return 200,{code = 99,msg = why}
end
--设置排行榜参数
REQUEST["/rank/set_config"] = function(path, method, header, body, query)
    if method ~= "POST" then
        return 200,{code = error_code.method_error}
    end
    body = cjson.decode(body)
    local rank_type = body.rank_type
    local min_score = body.min_score or 0
    local max_score = body.max_score or 0
    local cache_num = body.cache_num or 0
    local allow_negative = body.allow_negative or true --允许负数
    local open_min = body.open_min or false --开启最小值限制
    local open_max = body.open_max or false --开启最大值限制
    if not rank_type or rank_type == "" then
        return 200,{code = error_code.rank_type_error , msg = "rank_type error" }
    end
    if not min_score or type(min_score) ~= "number" then
        return 200,{code = error_code.min_score_type_error , msg = "min_score error" }
    end
    if not max_score or type(max_score) ~= "number"  then
        return 200,{code = error_code.min_score_type_error , msg = "min_score error" }
    end

    if not cache_num or type(cache_num) ~= "number" or math.ceil(cache_num) ~= cache_num or cache_num < 1 then
        return 200,{code = error_code.cache_num_error , msg = "cache_num error" }
    end
    if type(allow_negative) ~= "boolean" then
        return 200,{code = error_code.allow_negative_type_error , msg = "allow_negative 必须是布尔类型" }
    end
     if type(open_min) ~= "boolean" then
        return 200,{code = error_code.allow_negative_type_error , msg = "open_min 必须是布尔类型" }
    end
     if type(open_max) ~= "boolean" then
        return 200,{code = error_code.allow_negative_type_error , msg = "open_max 必须是布尔类型" }
    end
    local ok,why = skynet.call(".common_rank","lua","set_config",rank_type, body)
    if ok then
        return 200,{code = ok and error_code.ok or error_code.set_config_error}
    end
    return 200,{code = 99,msg = why}
end
--获取排行榜参数
REQUEST["/rank/get_config"] = function(path, method, header, body, query)
    if method ~= "POST" then
        return 200,{code = error_code.method_error}
    end
    body = cjson.decode(body)
    local rank_type = body.rank_type
    local ok,why = skynet.call(".common_rank","lua","get_config",rank_type)
    if ok then
        return 200,{code = error_code.ok ,data = ok}
    end
    return 200,{code = 99,msg = why}
end

return function (path, method, header, body, query)
    local f = REQUEST[path]
    if f then
        local ok,code,data,h = pcall(f, path, method, header, body, query)
        if path ~= "/rank/get_top_n" and path ~= "/rank/get_range" then
            print(dump({body,ok,code,data,h}))
        end
        if not ok then
            return 200,{code = error_code.internal_error, msg = code}
        end
        return code,data,h
    end
    return 404
end