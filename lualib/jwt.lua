local json = require("cjson")  -- 使用cjson库处理JSON
local openssl = require("openssl")  -- 使用openssl库处理加密签名
local base64 = require "base64"


local _M = {}

-- 生成JWT
function _M.create_jwt(payload, secret)
    -- payload转换为JSON并进行Base64URL编码
    local payload_b64 = base64.encode(json.encode(payload))


    -- 生成签名
    local unsigned_token = payload_b64
    local signature = openssl.hmac.new("sha256",secret):final(unsigned_token)
    local signature_b64 = base64.encode(signature)

    -- 拼接最终的JWT
    return base64.encode(payload_b64 .. "." .. signature_b64)
end

-- 验证JWT
function _M.verify_jwt(token, secret)
    -- 分割JWT为header, payload和signature
    local data = base64.decode(token)
    if not data then
        return false, "Invalid token format"
    end
    local payload_b64, signature_b64 = data:match("([^%.]+)%.([^%.]+)")
    if not payload_b64 or not signature_b64 then
        return false, "Invalid token format"
    end

    -- 重新计算签名
    local signature = openssl.hmac.new("sha256",secret):final(payload_b64)
    local expected_signature_b64 = base64.encode(signature)

    -- 验证签名是否匹配
    if signature_b64 ~= expected_signature_b64 then
        return false, "Invalid signature"
    end

    -- 解码header和payload
    local payload = json.decode(base64.decode(payload_b64))

    return true, payload
end


-- -- -- 示例使用
-- local header = { alg = "HS256", typ = "JWT" }
-- local payload = { sub = "1234567890", name = "John Doe", iat = 1516239022 }
-- local secret = "3375c394089667bf26c45863cd48abaf38f0abd76ae0b943a187d064d2daec9d"

-- local token = jwt.create_jwt( payload, secret)
-- print("JWT:", token)

-- local valid, payload =jwt.verify_jwt(token, secret)
-- if valid then
--     print("Token is valid!")
--     print("Payload:", cjson.encode(payload))
-- else
--     print("Token is invalid!")
-- end

return _M

