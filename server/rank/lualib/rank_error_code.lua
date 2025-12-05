return {
    ok = 0,                 -- 成功
    method_error = 1,       -- HTTP方法错误
    rank_type_error = 2,        -- 排行类型错误
    playerid_error = 3,     -- 玩家ID错误
    score_type_error = 4,   -- 分数类型错误
    updates_type_error = 5, -- 用户列表数据类型错误
    extdata_type_error = 6, -- 扩展数据类型错误
    n_type_error = 7, -- n类型错误
    with_extras_type_error = 8, -- with_extras类型错误
    start_rank_type_error = 9, -- start_rank类型错误
    end_rank_type_error = 10, -- end_rank类型错误
    updates_data_not_be_none = 11, -- 待更新的用户数据不能为空
    delete_error = 11, -- 删除失败，可能原因为未找到该玩家
    player_ids_type_error = 12, -- player_ids类型错误
    player_ids_index_type_error = 13, -- player_ids子项必须为字符串
    min_score_type_error = 14, -- min_score类型错误
    cache_num_error = 15, -- cache_num数据错误
    allow_negative_type_error = 16, -- allow_negative数据错误
    set_config_error = 17, -- 设置排行榜参数失败
    internal_error = 99,    -- 内部错误
}