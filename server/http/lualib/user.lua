local base = require "base"
local utils = require "utils"

local yyjson = require "cjson"

local DATA = base.DATA --本服务使用的表
local CMD = base.CMD  --供其他服务调用的接口
local PUBLIC = base.PUBLIC --本服务调用的接口
local REQUEST = base.REQUEST

-- 获取性别字典
REQUEST["/geeker/user/gender"] = function(path, method, header, body, query)
	local gender = {
        code = 200,
        data = {
            {
                genderLabel = "男",
                genderValue = 1,
            },
            {
                genderLabel = "女",
                genderValue = 2,
            },
        },
        msg = "成功",
    }
	return 200,gender
end

--获取用户状态字典
REQUEST["/geeker/user/status"] = function(path, method, header, body, query)
	local gender = {
        code = 200,
        data = {
            {
                userLabel = "启用",
                userStatus = 1,
                tagType = "success"
            },
            {
                userLabel = "禁用",
                userStatus = 0,
                tagType = "danger"
            },
        },
        msg = "成功",
    }
	return 200,gender
end

--获取用户列表
local user_list = nil
REQUEST["/geeker/user/list"] = function(path, method, header, body, query)
	if not user_list then
		local content = utils.read_file("./server/http/lualib/default_json/user.list.json", "r")
		if not content then
			return 200, "menu list not found"
		end
		user_list = yyjson.decode(content)
	end
	return 200,user_list
end