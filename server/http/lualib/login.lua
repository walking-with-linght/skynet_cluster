local base = require "base"
local yyjson = require "cjson"
local DATA = base.DATA     --本服务使用的表
local CMD = base.CMD       --供其他服务调用的接口
local PUBLIC = base.PUBLIC --本服务调用的接口
local dump = require "dump"
local utils = require "utils"
local REQUEST = base.REQUEST

local default_tokens = {
	admin = {
		token = 'bqddxxwqmfncffacvbpkuxvwvqrhln'
	},
	editor = {
		token = 'editor-token'
	}
}

-- 登录
REQUEST["/geeker/login"] = function(path, method, header, body, query)
	local b = yyjson.decode(body)
	local ret = {
		code = 60204,
		data = {
			token = "Account and password are incorrect."
		},
	}
	if default_tokens[b.username] then
		ret.code = 200
		ret.data.access_token = default_tokens[b.username].token
	end

	return 200, ret
end

-- 获取菜单
local cache_menu_list = nil
REQUEST["/geeker/menu/list"] = function(path, method, header, body, query)
	if not cache_menu_list then
		local content = utils.read_file("./server/http/lualib/default_json/authMenuList.json", "r")
		if not content then
			return 200, "menu list not found"
		end
		cache_menu_list = yyjson.decode(content)
	end
	return 200,cache_menu_list
end

-- 获取菜单
local cache_buttons = nil
REQUEST["/geeker/auth/buttons"] = function(path, method, header, body, query)
	if not cache_buttons then
		local content = utils.read_file("./server/http/lualib/default_json/authButtonList.json", "r")
		if not content then
			return 200, "menu list not found"
		end
		cache_buttons = yyjson.decode(content)
	end
	return 200,cache_buttons
end

