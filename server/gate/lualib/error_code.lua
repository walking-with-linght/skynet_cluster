Error_code = {
    [10001]  = "消息频繁,已断开",
    [10002]  = "第一条消息必须是登录",
    [10003]  = "登录超时，5秒后重新发送登录消息（不必断开连接）",
    [10004]  = "正在加载数据，请勿频繁登录",
    [10005]  = "账号在线，是否顶号",
    [10006]  = "登录异常，请稍后再试",
    [10007]  = "需要排队",
    [10008]  = "未找到该渠道登录验证",
    [10010]  = "密码错误，请重新输入",
    [10011]  = "协议解析错误",
    [10012]  = "暂不支持RESPONSE",
    [10013]  = "被禁止通信",
    [10014]  = "找不到相关处理函数",
    [10015]  = "加载数据异常",
    [10016]  = "登录服务器异常",
    [10017]  = "未找到对应游戏",
    [10018]  = "进入房间失败",
    [10019]  = "已经在房间内",
}

local error_code = {
    success = 0,            --ok
    sms_code_none = 10001,     --请先申请验证码
    sms_code_error = 10002,     --验证码错误
    sms_code_timeout = 10003,     --验证码超时
    sms_code_phone_error = 10005,     --手机号错误
    token_decode_error = 10010,     --token解析失败
    token_data_error = 10011,     --token数据错误
    token_invalid = 10012,     --token无效
    token_timeout = 10013,     --token超时
    token_frequently = 10014,     --获取token频繁
    login_no_role = 10020,      --登录时无rid
    login_account_not_valid = 10030,      --无效账号
    login_arg_not_valid = 10031,      --登录参数不合法
    login_pwd_not_valid = 10032,      --密码不合法
    login_pwd_tooshort = 10033,      --密码太短
    login_pwd_toolong = 10034,      --密码太长
    login_pwd_error = 10035,      --密码错误
    login_create_account_error = 10036,      --创建账号失败
    protoid_not_exit = 10040,      --协议号不存在
    data_not_enough_length = 10041,      --数据长度不够解析
    forbid_network = 10042,      --禁止发送数据
    msg_times_limit = 10043,      --消息过于频繁
    prof_not_found = 10050,      --职业未找到
    role_not_found = 10060,      --未找到该角色
    role_too_much = 10061,      --角色已达上限
    room_not_found_team = 10070,      --找不到该角色所在队伍
    room_already_in_room = 10071,      --已经在房间内禁止再次匹配
    room_already_in_match = 10072,      --已经在匹配中
    room_not_in_game = 10073,      --没有在游戏中



    --直播相关
    live_not_found_room = 20001,    --未找到对应直播间
    live_publish_max = 20002,    -- 开播数量上限
    live_watch_limit = 20003,    -- 直播观看人数上限
    live_permission_error = 20004,    --无权限开播
}

return error_code