return {
    robot = "robot",
    app_id = "cli_a994c**********3",-- 修改为你的 App ID
    app_secret = "t4Q********a22mL2MYK********JJde",-- 修改为你的 App Secret



    -- 获取 token 链接地址
    token_host = "https://open.larksuite.com",
    token_url = "/open-apis/auth/v3/tenant_access_token/internal",
    token_expire = 60 * 10, -- 10分钟  预留时间

    -- 管理员 openid
    admin_openid = "ou_672883de4d76a12ffe32**********33",

    --允许的消息格式
    allow_msg_type = {
        text = true,
    },

    --默认回复的消息格式
    default_reply_msg_type = "text",

    --默认消息超时不处理时间
    default_msg_timeout = 300 * 1000, -- 300秒


    --回复消息地址
    reply_host = "https://open.larksuite.com",
    reply_url = "/open-apis/im/v1/messages/%s/reply",


    --主动发送消息
    send_message_host = "https://open.larksuite.com",
    send_message_url = "/open-apis/im/v1/messages?receive_id_type=%s",
    send_message_default_receive_id_type = "email",
    send_message_default_receive_id = "***@gmail.com", -- 修改为你的默认接收者游戏账号
}