local skynet = require "skynet"
local redis = require "skynet.db.redis"
local mysql = require "skynet.db.mysql"
local cjson = require "cjson"
local queue = require "skynet.queue"
require "skynet.manager"

local redis_conn
local mysql_conn
local rank_config = {} -- 排行榜配置 {rank_type = {min_score, cache_num}}

local default_config = {
    min_score = 0,
    max_score = 999999999,
    cache_num = 100,
    allow_negative = true,
    open_min = false,
    open_max = false,
}
local CMD = {}

-- 创建 MySQL 操作队列
local mysql_queue = queue()

-- 封装 MySQL 操作为队列任务
local function mysql_execute(sql, callback)
    mysql_queue(function()
        local ok, result = pcall(function()
            return mysql_conn:query(sql)
        end)
        print("mysql_execute", dump( {ok, result}))
        if callback then
            callback(ok, result)
        end
        return ok, result
    end)
end

function CMD.init(redis_conf, mysql_conf)
    redis_conn = redis.connect(redis_conf)
    
    mysql_conn = mysql.connect(mysql_conf)
    
    -- 从数据库加载排行榜配置
    local res = mysql_conn:query("SELECT * FROM rank_config")
    for _, conf in ipairs(res) do
        local config_data = cjson.decode(conf.config_json)
        -- 合并默认配置和数据库配置
        rank_config[conf.rank_type] = {}
        for k, v in pairs(default_config) do
            rank_config[conf.rank_type][k] = config_data[k] ~= nil and config_data[k] or v
        end
    end
    
    return true
end

-- 设置排行榜配置
-- @param rank_type 排行榜类型
-- @param config_table 配置表，包含所有配置项
function CMD.set_config(rank_type, config_table)
    if not config_table or type(config_table) ~= "table" then
        return nil, "config_table must be a table"
    end
    
    -- 验证配置参数
    local new_config = {}
    for k, v in pairs(default_config) do
        new_config[k] = config_table[k] ~= nil and config_table[k] or v
    end
    
    -- 参数验证
    if type(new_config.min_score) ~= "number" then
        return nil, "min_score must be a number"
    end
    if type(new_config.max_score) ~= "number" then
        return nil, "max_score must be a number"
    end
    if type(new_config.cache_num) ~= "number" or new_config.cache_num < -1 then
        return nil, "cache_num must be a number >= -1"
    end
    if type(new_config.allow_negative) ~= "boolean" then
        return nil, "allow_negative must be a boolean"
    end
    if type(new_config.open_min) ~= "boolean" then
        return nil, "open_min must be a boolean"
    end
    if type(new_config.open_max) ~= "boolean" then
        return nil, "open_max must be a boolean"
    end

    rank_config[rank_type] = new_config
    
    if mysql_conn then
        local config_json = cjson.encode(new_config)
        mysql_conn:query(string.format(
            [[INSERT INTO rank_config 
              (rank_type, config_json) 
              VALUES ('%s', '%s') 
              ON DUPLICATE KEY UPDATE 
                config_json=VALUES(config_json)]],
            rank_type, config_json
        ))
    end
    
    return true
end

function CMD.get_config(rank_type)
    return rank_config[rank_type] or default_config
end
-- 数组map函数
local function array_map(t, fn)
    local res = {}
    for i, v in ipairs(t) do
        res[i] = fn(v, i)
    end
    return res
end

-- 直接设置玩家分数（非增减模式）
-- @param rank_type 排行榜类型
-- @param player_id 玩家ID
-- @param score 要设置的分数（直接值，非增量）
-- @param extra_data 额外数据（可选）
function CMD.update_score_direct(rank_type, player_id, score, extra_data)
    local config = CMD.get_config(rank_type)
    if not config then
        return false, "rank_type not exist"
    end
    
    -- 检查分数是否合法
    if not config.allow_negative and score < 0 then
        score = 0
    end
    
    -- 检查是否达到最高分数限制
    if config.open_max and score > config.max_score then
        score = config.max_score
    end
    
    -- 检查是否达到最低分数
    if config.open_min and score < config.min_score then
        -- 如果原来在榜上，需要移除
        local key = "rank:" .. rank_type
        local current_score = tonumber(redis_conn:zscore(key, player_id)) or 0
        if not config.open_min or current_score >= config.min_score then
            redis_conn:zrem(key, player_id)
            if mysql_conn then
                skynet.fork(function()
                    mysql_execute(string.format(
                        "DELETE FROM rank_data WHERE rank_type='%s' AND player_id='%s'",
                        rank_type, player_id
                    ))
                end)
            end
        end
        return false, "score too low"
    end
    local extra_str = type(extra_data) == "table" and cjson.encode(extra_data) or tostring(extra_data)

    local key = "rank:" .. rank_type
    local data_key = "rank_data:" .. rank_type .. ":" .. player_id
    
    -- 更新Redis分数
    redis_conn:zadd(key, score, player_id)
    
    -- 更新额外数据
    if extra_data then
        
        redis_conn:hset(data_key, "extra", extra_str)
        
        -- 使用队列执行MySQL更新
        if mysql_conn then
            skynet.fork(function()
                mysql_execute(string.format(
                    [[INSERT INTO rank_data 
                      (rank_type, player_id, score, extra_data) 
                      VALUES ('%s', '%s', %f, '%s') 
                      ON DUPLICATE KEY UPDATE 
                        score=VALUES(score), 
                        extra_data=VALUES(extra_data)]],
                    rank_type, player_id, score, extra_str
                ))
            end)
        end
    else
        -- 只更新分数
        if mysql_conn then
            skynet.fork(function()
                mysql_execute(string.format(
                    "UPDATE rank_data SET score=%f WHERE rank_type='%s' AND player_id='%s'",
                    score, rank_type, player_id
                ))
            end)
        end
    end
    
    -- 清除缓存
    if config.cache_num > 0 or config.cache_num == -1 then
        local rank = redis_conn:zrevrank(key, player_id)
        if rank and (config.cache_num == -1 or rank < config.cache_num) then
            redis_conn:del("rank_cache:" .. rank_type)
        end
    end
    
    return true, {score = score}
end

-- 批量直接设置玩家分数（非增减模式）
-- @param rank_type 排行榜类型
-- @param updates 更新列表，每个元素包含player_id, score, extra_data(可选)
-- @return 成功返回true，失败返回false和错误信息
function CMD.batch_update_score_direct(rank_type, updates)
    local config = CMD.get_config(rank_type)
    if not config then
        return false, "rank_type not exist"
    end

    local key = "rank:" .. rank_type
    local redis_zadd_args = {key}
    local mysql_updates = {}
    local need_clear_cache = false

    -- 准备Redis批量更新参数
    for _, update in ipairs(updates) do
        local player_id = update.player_id
        local score = update.score
        local extra_data = update.extra_data
        local data_key = "rank_data:" .. rank_type .. ":" .. player_id
        local extra_str = type(extra_data) == "table" and cjson.encode(extra_data) or tostring(extra_data)

        -- 检查分数是否合法
        if not config.allow_negative and score < 0 then
            score = 0
        end

        -- 检查是否达到最高分数限制
        if config.open_max and score > config.max_score then
            score = config.max_score
        end

        -- 检查是否达到最低分数
        if not config.open_min or score >= config.min_score then
            -- 准备Redis更新
            table.insert(redis_zadd_args, score)
            table.insert(redis_zadd_args, player_id)
            -- 准备额外数据更新
            if extra_str then
                redis_conn:hset(data_key, "extra", extra_str)
            end

            -- 准备MySQL更新
            if mysql_conn then
                table.insert(mysql_updates, {
                    player_id = player_id,
                    score = score,
                    extra_data = extra_str
                })
            end

            -- 检查是否需要清除缓存
            if config.cache_num > 0 or config.cache_num == -1 then
                local rank = redis_conn:zrevrank(key, player_id)
                if rank and (config.cache_num == -1 or rank < config.cache_num) then
                    need_clear_cache = true
                end
            end
        else
            -- 从排行榜移除不达标的玩家
            redis_conn:zrem(key, player_id)
            if mysql_conn then
                table.insert(mysql_updates, {
                    player_id = player_id,
                    remove = true
                })
            end
        end
    end

    -- 执行Redis批量更新
    if #redis_zadd_args > 1 then
        redis_conn:zadd(table.unpack(redis_zadd_args))
    end

    -- 异步执行MySQL批量更新
    if mysql_conn and #mysql_updates > 0 then
        skynet.fork(function()
            -- 处理批量插入/更新
            local values = {}
            for _, update in ipairs(mysql_updates) do
                if not update.remove and update.extra_data then
                    table.insert(values, string.format(
                        "('%s','%s',%f,'%s')",
                        rank_type, update.player_id, update.score, update.extra_data
                    ))
                elseif not update.remove then
                    -- 单独发送分数更新
                    mysql_execute(string.format(
                        "UPDATE rank_data SET score=%f WHERE rank_type='%s' AND player_id='%s'",
                        update.score, rank_type, update.player_id
                    ))
                end
            end

            -- 批量插入/更新有额外数据的记录
            if #values > 0 then
                mysql_execute(string.format(
                    [[INSERT INTO rank_data 
                      (rank_type, player_id, score, extra_data) 
                      VALUES %s 
                      ON DUPLICATE KEY UPDATE 
                        score=VALUES(score), 
                        extra_data=VALUES(extra_data)]],
                    table.concat(values, ",")
                ))
            end

            -- 处理批量删除
            for _, update in ipairs(mysql_updates) do
                if update.remove then
                    mysql_execute(string.format(
                        "DELETE FROM rank_data WHERE rank_type='%s' AND player_id='%s'",
                        rank_type, update.player_id
                    ))
                end
            end
        end)
    end

    -- 清除缓存
    if need_clear_cache then
        redis_conn:del("rank_cache:" .. rank_type)
    end

    return true
end

-- 更新玩家分数（增减模式）
-- @param delta_score 分数变化量（可正可负）
-- @param extra_data 额外数据（可选）
function CMD.update_score(rank_type, player_id, delta_score, extra_data)
    local config = CMD.get_config(rank_type)
    if not config then
        return false, "rank_type not exist"
    end
    local extra_str = type(extra_data) == "table" and cjson.encode(extra_data) or tostring(extra_data)
    local key = "rank:" .. rank_type
    local data_key = "rank_data:" .. rank_type .. ":" .. player_id
    
    -- 获取当前分数
    local current_score = tonumber(redis_conn:zscore(key, player_id)) or 0
    local new_score = current_score + delta_score
    
    -- 检查分数是否合法
    if not config.allow_negative and new_score < 0 then
        new_score = 0
    end
    
    -- 检查是否达到最高分数限制
    if config.open_max and new_score > config.max_score then
        new_score = config.max_score
    end
    
    -- 检查是否达到最低分数
    if config.open_min and new_score < config.min_score then
        -- 如果原来在榜上，需要移除
        if not config.open_min or current_score >= config.min_score then
            redis_conn:zrem(key, player_id)
            if mysql_conn then
                skynet.fork(function()
                    local sql = string.format(
                        "DELETE FROM rank_data WHERE rank_type='%s' AND player_id='%s'",
                        rank_type, player_id
                    )
                    mysql_execute(sql, function(ok, result)
                        if not ok then
                            skynet.error("MySQL update failed:", result)
                        end
                    end)
                end)
            end
        end
        return false, "score too low"
    end
    
    -- 更新Redis分数和数据
    redis_conn:zadd(key, new_score, player_id)
    
    -- 更新额外数据
    if extra_str then
        redis_conn:hset(data_key, "extra", extra_str)
        
        -- 异步更新MySQL
        if mysql_conn then
            skynet.fork(function()
                local sql = string.format(
                            [[INSERT INTO rank_data 
                        (rank_type, player_id, score, extra_data) 
                        VALUES ('%s', '%s', %f, '%s') 
                        ON DUPLICATE KEY UPDATE 
                            score=VALUES(score), 
                            extra_data=VALUES(extra_data)]],
                        rank_type, player_id, new_score, extra_str
                    )
                mysql_execute(sql, function(ok, result)
                    if not ok then
                        skynet.error("MySQL update failed:", result)
                    end
                end)

            end)
        end
    else
        -- 只更新分数
        if mysql_conn then
            skynet.fork(function()
                local sql = string.format(
                            "UPDATE rank_data SET score=%f WHERE rank_type='%s' AND player_id='%s'",
                    new_score, rank_type, player_id
                    )
                mysql_execute(sql, function(ok, result)
                    if not ok then
                        skynet.error("MySQL update failed:", result)
                    end
                end)
            end)
        else
            print("mysql_conn not exist")
        end
    end
    
    -- 清除缓存
    if config.cache_num > 0 or config.cache_num == -1 then
        local rank = redis_conn:zrevrank(key, player_id)
        if rank and (config.cache_num == -1 or rank < config.cache_num) then
            redis_conn:del("rank_cache:" .. rank_type)
        end
    end
    
    return true, {score = new_score}
end

-- 批量更新分数 变化值
function CMD.batch_update_score(rank_type, updates)
    local config = CMD.get_config(rank_type)
    if not config then
        return false, "rank_type not exist"
    end
    
    local key = "rank:" .. rank_type
    local redis_zadd_args = {key}
    local mysql_updates = {}
    local need_clear_cache = false
    
    -- 处理每个更新
    for _, update in ipairs(updates) do
        local player_id = update.player_id
        local delta_score = update.delta_score
        local extra_data = update.extra_data
        local data_key = "rank_data:" .. rank_type .. ":" .. player_id
        local extra_str = type(extra_data) == "table" and cjson.encode(extra_data) or tostring(extra_data)
        -- 获取当前分数
        local current_score = tonumber(redis_conn:zscore(key, player_id)) or 0
        local new_score = current_score + delta_score
        
        -- 检查分数是否合法
        if not config.allow_negative and new_score < 0 then
            new_score = 0
        end
        
        -- 检查是否达到最高分数限制
        if config.open_max and new_score > config.max_score then
            new_score = config.max_score
        end
        
        -- 检查是否达到最低分数
        if not config.open_min or new_score >= config.min_score then
            -- 准备Redis更新
            table.insert(redis_zadd_args, new_score)
            table.insert(redis_zadd_args, player_id)
            
            -- 准备额外数据更新
            if extra_str then
                redis_conn:hset(data_key, "extra", extra_str)
            end
            
            -- 准备MySQL更新
            if mysql_conn then
                table.insert(mysql_updates, {
                    player_id = player_id,
                    new_score = new_score,
                    extra_data = extra_str
                })
            end
            
            -- 检查是否需要清除缓存
            if config.cache_num > 0 or config.cache_num == -1 then
                local rank = redis_conn:zrevrank(key, player_id)
                if rank and (config.cache_num == -1 or rank < config.cache_num) then
                    need_clear_cache = true
                end
            end
        elseif not config.open_min or current_score >= config.min_score then
            -- 从排行榜移除
            redis_conn:zrem(key, player_id)
            if mysql_conn then
                table.insert(mysql_updates, {
                    player_id = player_id,
                    remove = true
                })
            end
        end
    end
    
    -- 执行Redis批量更新
    if #redis_zadd_args > 1 then
        redis_conn:zadd(table.unpack(redis_zadd_args))
    end
    
    -- 使用队列执行 MySQL 批量操作
    if mysql_conn and #mysql_updates > 0 then
        skynet.fork(function()
            -- 先处理单独更新
            for _, update in ipairs(mysql_updates) do
                if not update.remove and not update.extra_data then
                    local sql = string.format(
                        "UPDATE rank_data SET score=%f WHERE rank_type='%s' AND player_id='%s'",
                        update.new_score, rank_type, update.player_id
                    )
                    mysql_execute(sql)
                end
            end
            
            -- 批量处理有额外数据的更新
            local values = {}
            for _, update in ipairs(mysql_updates) do
                if not update.remove and update.extra_data then
                    table.insert(values, string.format(
                        "('%s','%s',%f,'%s')",
                        rank_type, update.player_id, update.new_score, update.extra_data
                    ))
                end
            end
            
            if #values > 0 then
                local sql = string.format(
                    [[INSERT INTO rank_data 
                      (rank_type, player_id, score, extra_data) 
                      VALUES %s 
                      ON DUPLICATE KEY UPDATE 
                        score=VALUES(score), 
                        extra_data=VALUES(extra_data)]],
                    table.concat(values, ",")
                )
                mysql_execute(sql)
            end
            
            -- 处理删除操作
            for _, update in ipairs(mysql_updates) do
                if update.remove then
                    local sql = string.format(
                        "DELETE FROM rank_data WHERE rank_type='%s' AND player_id='%s'",
                        rank_type, update.player_id
                    )
                    mysql_execute(sql)
                end
            end
        end)
    end
    
    -- 清除缓存
    if need_clear_cache then
        redis_conn:del("rank_cache:" .. rank_type)
    end
    
    return true
end

-- 获取玩家排名和详细信息
function CMD.get_player_info(rank_type, player_id)
    local config = CMD.get_config(rank_type)
    if not config then
        return nil, "rank_type not exist"
    end
    
    local key = "rank:" .. rank_type
    local data_key = "rank_data:" .. rank_type .. ":" .. player_id
    
    -- 获取分数和排名
    local score = redis_conn:zscore(key, player_id)
    if not score then
        return nil, "player not in rank"
    end
    
    local rank = redis_conn:zrevrank(key, player_id)
    
    -- 获取额外数据
    local extra_data_str = redis_conn:hget(data_key, "extra")
    
    return true,{
        rank = rank and rank + 1 or nil, -- 转换为1-based
        score = tonumber(score),
        player_id = player_id,
        extra = extra_data_str
    }
end

-- 增强的获取排行榜前N名接口（带额外数据）
function CMD.get_top_n(rank_type, n, with_extras)
    local config = CMD.get_config(rank_type)
    if not config then
        return nil, "rank_type not exist"
    end
    
    n = n or (config.cache_num > 0 and config.cache_num or 100)
    with_extras = with_extras ~= false -- 默认true
    
    -- 检查缓存
    local cache_key = "rank_cache:" .. rank_type
    if config.cache_num and (config.cache_num == -1 or n <= config.cache_num) then
        local cached = redis_conn:get(cache_key)
        if cached then
            local cache_all = cjson.decode(cached)
            local data = {}
            for i = 1, n, 1 do
                data[i] = cache_all[i]
            end
            return true,data
        end
    end
    
    -- 从Redis获取排名和分数
    local key = "rank:" .. rank_type
    local result = redis_conn:zrevrange(key, 0, n - 1, "WITHSCORES")
    
    -- 收集玩家ID用于批量获取额外数据
    local player_ids = {}
    for i = 1, #result, 2 do
        table.insert(player_ids, result[i])
    end
    
    -- 批量获取额外数据
    local extras = {}
    local ops = {}
    if with_extras and #player_ids > 0 then
        for _, player_id in ipairs(player_ids) do
            table.insert(ops,{"hget","rank_data:" .. rank_type .. ":" .. player_id, "extra"})
        end
        redis_conn:pipeline(ops,extras)
    end
    print(dump(extras))
    -- 组装结果
    local ranks = {}
    for i = 1, #result, 2 do
        local player_id = result[i]
        local score = tonumber(result[i + 1])
        local extra_idx = math.floor((i + 1) / 2)
        local extra = nil
        if with_extras and extras[extra_idx] and extras[extra_idx].ok and extras[extra_idx].out then
            extra = extras[extra_idx].out
        end
        table.insert(ranks, {
            rank = math.floor(i / 2) + 1, -- 转换为1-based
            player_id = player_id,
            score = score,
            extra = extra
        })
    end
    
    -- 设置缓存（只缓存带额外数据的结果）
    if with_extras and config.cache_num and (config.cache_num == -1 or n <= config.cache_num) then
        redis_conn:setex(cache_key, 300, cjson.encode(ranks)) -- 缓存5分钟
    end
    
    return true,ranks
end

-- 增强的获取范围接口（带额外数据）
function CMD.get_range(rank_type, start_rank, end_rank, with_extras)
    local config = CMD.get_config(rank_type)
    if not config then
        return nil, "rank_type not exist"
    end
    start_rank = start_rank or 1
    end_rank = end_rank or start_rank
    -- 参数校验
    if type(start_rank) ~= "number" or start_rank ~= math.ceil(start_rank) or start_rank < 1 or start_rank > end_rank then
        return nil,"start_type error"
    end
    if type(end_rank) ~= "number" or end_rank ~= math.ceil(end_rank) or end_rank < 1 or start_rank > end_rank then
        return nil,"end_rank error"
    end
    if with_extras == nil then
        with_extras = true
    end
    if type(with_extras) ~= "boolean" then
        return nil,"with_extras error"
    end
    
    -- 检查是否全部在缓存范围内
    local cache_key = "rank_cache:" .. rank_type
    if config.cache_num and (config.cache_num == -1 or end_rank <= config.cache_num) then
        local cached = redis_conn:get(cache_key)
        if cached then
            local all_ranks = cjson.decode(cached)
            local result = {}
            for i = start_rank, math.min(end_rank, #all_ranks) do
                table.insert(result, all_ranks[i])
            end
            -- print("从cache返回数据")
            return true,result
        end
    end
    
    -- 从Redis获取排名和分数
    local key = "rank:" .. rank_type
    local redis_result = redis_conn:zrevrange(key, start_rank - 1, end_rank - 1, "WITHSCORES")
    
    -- 收集玩家ID用于批量获取额外数据
    local player_ids = {}
    for i = 1, #redis_result, 2 do
        table.insert(player_ids, redis_result[i])
    end
    
    -- 批量获取额外数据
    local extras = {}
    if with_extras and #player_ids > 0 then
        local ops = {}
        for _, player_id in ipairs(player_ids) do
            table.insert(ops,{"hget","rank_data:" .. rank_type .. ":" .. player_id, "extra"})
        end
        redis_conn:pipeline(ops,extras)
    end
    -- print(dump(extras))
    -- 组装结果
    local ranks = {}
    for i = 1, #redis_result, 2 do
        local player_id = redis_result[i]
        local score = tonumber(redis_result[i + 1])
        local extra_idx = math.floor((i + 1) / 2)
        local extra = nil
        if with_extras and extras[extra_idx] and extras[extra_idx].ok and extras[extra_idx].out then
            extra = extras[extra_idx].out
        end
        table.insert(ranks, {
            rank = start_rank + math.floor((i - 1) / 2),
            player_id = player_id,
            score = score,
            extra = extra
        })
    end
    
    return true,ranks
end



-- 删除玩家排名
function CMD.remove_player(rank_type, player_id)
    local key = "rank:" .. rank_type
    local removed = redis_conn:zrem(key, player_id)
    
    local data_key = "rank_data:" .. rank_type .. ":" .. player_id
    redis_conn:del(data_key)
    -- 使用队列执行 MySQL 删除
    if mysql_conn and removed > 0 then
        skynet.fork(function()
            mysql_execute(string.format(
                "DELETE FROM rank_data WHERE rank_type='%s' AND player_id='%s'",
                rank_type, player_id
            ))
        end)
    end
    
    -- 清除缓存
    local config = CMD.get_config(rank_type)
    if config and config.cache_num > 0 then
        redis_conn:del("rank_cache:" .. rank_type)
    end
    
    return removed > 0
end

-- 批量删除玩家
function CMD.batch_remove_player(rank_type, player_ids)
    local key = "rank:" .. rank_type
    local redis_args = {key}
    
    for _, player_id in ipairs(player_ids) do
        table.insert(redis_args, player_id)
        local data_key = "rank_data:" .. rank_type .. ":" .. player_id
        redis_conn:del(data_key)
    end
    
    local removed = redis_conn:zrem(table.unpack(redis_args))
    
    -- 使用队列执行 MySQL 批量删除
    if mysql_conn and removed > 0 then
        skynet.fork(function()
            local in_clause = table.concat(
                array_map(player_ids, function(id) return "'" .. id .. "'" end),
                ","
            )
            mysql_execute(string.format(
                "DELETE FROM rank_data WHERE rank_type='%s' AND player_id IN (%s)",
                rank_type, in_clause
            ))
        end)
    end
    
    -- 清除缓存
    local config = CMD.get_config(rank_type)
    if config and config.cache_num > 0 then
        redis_conn:del("rank_cache:" .. rank_type)
    end
    
    return removed
end


-- 服务主入口
skynet.start(function()
    skynet.dispatch("lua", function(_, _, cmd, ...)
        local f = CMD[cmd]
        if not f then
            skynet.ret(skynet.pack(nil, "command not found"))
            return
        end
        
        local ok, ret,ret2,ret3,ret4 = pcall(f, ...)
        if ok then
            skynet.retpack(ret,ret2,ret3,ret4)
        else
            print("err",ret)
            skynet.ret(skynet.pack(nil, ret))
        end
    end)
    skynet.register(".common_rank")
end)


