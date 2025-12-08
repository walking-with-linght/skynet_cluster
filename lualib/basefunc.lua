--
-- Author: lyx
-- Date: 2018/3/10
-- Time: 17:10
-- 说明：常用功能函数
--

local md5 = require "md5"
local cjson = require "cjson"

local basefunc = {
	path={},
	math={},
	physics={},
	string = {},
	debug = {},
	table = {}
}

local lm = math
local lstr_format = string.format
local oneday_sec = 24 * 60 * 60 --一天的秒数
local meta_weak_key = {__mode="k" }
local meta_weak_value = {__mode="v" }
local meta_weak_kv = {__mode="kv" }
local unpack = table.unpack
local pack = table.pack
local random = math.random
local floor = math.floor

local seq_number = 0

-- 转成字符串。参数 _nofunction 默认为 true ， 必须明确传 false
function STR(_v,_nofunction)
    return basefunc.dump(_v,nil,_nofunction ~= false)
end

local loadstring = rawget(_G, "loadstring") or load

if not fault then
	fault = print
end

function basefunc.error_handle(msg)
	local _err_info = tostring(msg) .. "\n" .. tostring(debug.traceback())
	fault(_err_info)
	print(_err_info)
	return _err_info
end
local error_handle = basefunc.error_handle
----------------------------
-- 通用函数库

local typeinfo_map = {}

-- 可热更新的 类： name => class
basefunc.hot_class = {}

-- 创建一个类
function basefunc.class(base,name)
	local cls = {}
	local obj_meta = {__index=cls}
	if base then
		cls.super=base
		setmetatable(cls,{__index=base})
	end

	function cls.new(...)
		local ret = setmetatable({class=cls},obj_meta)

		if cls.ctor then
			ret:ctor(...)
		end

		return ret
	end

	cls.typeinfo = {class=cls,name=name }

	if name then

		if typeinfo_map[name] then
			print(string.format("!!!! warning:class name '%s' is conflict!",name))
		end

		typeinfo_map[name] = cls.typeinfo
	end

	return cls
end

-- 创建可热更新 的类
-- 基类 base 可以是类，也可以是类名
function basefunc.create_hot_class(name,base)

	if not name then
		error("hot class must has name!")
	end

	-- 有了直接返回
	local _cls = basefunc.classbyname(name)
	if  _cls then

		basefunc.hot_class[name] = _cls
		return _cls
	end

	if type(base) == "string" then
		base = basefunc.classbyname(base) -- 转换类名为真正的类
		if not base then
			error("base class name '" .. tostring(base) .. "' not found!")
		end
	end

	basefunc.hot_class[name] = basefunc.class(base,name)
	return basefunc.hot_class[name]
end

-- 得到父类
-- 参数 obj ： 可以是类 或 对象
function basefunc.parent(obj)

	if not obj then return nil end

	local ti = rawget(obj,"typeinfo")

	-- obj 是类
	if ti then
		return rawget(ti.cls,"super")
	end

	-- obj 是对象
	local cls = rawget(obj,"class")
	return cls and rawget(cls,"super")
end

-- 判断类 或 对象 是否 派生自 指定的类
-- 参数 obj ： 可以是类 或 对象
-- 参数 class ： 可以是类 、 对象 、或类名
function basefunc.iskindof(obj,class)

	local classname = nil
	if type(class) == "string" then
		classname = class
		class = basefunc.classbyname(class)
	else
		classname = basefunc.classname(class)
	end

	-- obj 是不是类
	local ti = rawget(obj,"typeinfo")
	local objcls = ti and obj

	-- obj 是类
	if not objcls then
		objcls = rawget(obj,"class")
		if not objcls then
			return false
		end

		ti = rawget(objcls,"typeinfo")
	end

	-- 逐级查找
	while objcls and ti do

		if objcls == class or ti.name == classname then
			return true
		end

		-- 继续找 父类
		objcls = rawget(objcls,"super")
		ti = rawget(objcls,"typeinfo")
	end

	return false
end

-- 根据名字得到类
function basefunc.classbyname(name)
	local t = typeinfo_map[name]
	return t and t.class
end

-- 设置类的别名，返回一个派生的类
function basefunc.classalias(name,alias)
	local cls = basefunc.classbyname(name)
	if not cls then return nil end

	return basefunc.class(cls,alias)
end

-- 得到类名
-- 参数 name ： 可以是类 、 对象 、或类名
function basefunc.classname(obj)
	if not obj then return nil end

	if type(obj) == "string" then return obj end

	if type(obj) ~= "table" then return nil end

	local ti = rawget(obj,"typeinfo")

	-- obj 是类
	if ti then
		return ti.name
	end

	-- obj 是对象
	local cls = rawget(obj,"class")
	ti = cls and rawget(cls,"typeinfo")
	return ti and ti.name
end

-- 根据参数创建对象 or 空表
function basefunc.create(creator,...)

	if not creator then
		return {}
	end

	if "function" == type(creator) then
		return creator(...)
	end

	if "string" == type(creator) then
		return basefunc.classbyname(creator).new(...)
	end

	if "table" == type(creator) and creator.new then
		return creator.new(...)
	end

	return nil
end


function basefunc.weakValue(t)
	return setmetatable(t or {}, meta_weak_value)
end

function basefunc.weakKey(t)
	return setmetatable(t or {}, meta_weak_key)
end

function basefunc.weakKV(t)
	return setmetatable(t or {}, meta_weak_kv)
end




local function debug_call_return(ok,msg,...)
	if ok then
		return msg,...
	else
		error(msg) -- 继续抛出错误
	end
end

local _debug_error_id = 0

-- 失败则调用回调
function basefunc.debug_call(_catch,_func,...)
	return debug_call_return(xpcall(_func,function(msg)
		_debug_error_id = _debug_error_id + 1

		_catch("[dbg id:" .. _debug_error_id .. "] " .. tostring(msg))
		print("[dbg id:" .. _debug_error_id .. "] stack:" .. tostring(msg),debug.traceback())
		return "[dbg id:" .. _debug_error_id .. "] error:" .. msg
	end,...))
end

function basefunc.seq_number()
	seq_number = seq_number + 1
	return seq_number
end


--[[
    -- 序列化值为 lua 字符串
	其结果格式
	1.value是字符串：
	".........."

	2.value是数字：
	1

	3.value是table没有环
	do
		local ret = {....}
		return ret
	end

	4.value是table带有环
	do
		local ret = {....}
		ret.a[1].c = ret.a
		ret.a[2].b[2] = ret.a[3]
		return ret
	end

]]
function basefunc.serialize(value)

	if type(value)~="table" then
		return type(value)=="string" and "\""..value.."\"" or tostring(value)
	end

	local mark={}
	local assign={}
	local loopRef = false

	local function ser_table(tbl,parent)
		mark[tbl]=parent
		local tmp={}
		for k,v in pairs(tbl) do
			local key= type(k)=="number" and "["..k.."]" or k
			if type(v)=="table" then
				local dotkey= parent..(type(k)=="number" and key or "."..tostring(key))
				if mark[v] then
					loopRef = true
					table.insert(assign,dotkey.."="..mark[v])
				else
					table.insert(tmp, tostring(key).."="..ser_table(v,dotkey))
				end
			else
				table.insert(tmp, tostring(key).."="..(type(v)=="string" and "\""..v.."\"" or tostring(v)))
			end
		end
		return "{"..table.concat(tmp,",").."}"
	end

	local str = ser_table(value,"ret")
	if loopRef then		-- 有循环引用，则需要赋值
		return "do local ret="..str..table.concat(assign," ").." return ret end"
	else
		return str		-- 无循环引用，直接返回
	end
end

--[[安全的序列化 处理需要再加载的数据代码使用
	字符串用 [[ ] ] 进行包裹 若出现]后面会加空格
	不支持循环引用
]]
function basefunc.safe_serialize(value)

    if type(value)~="table" then
        return type(value)=="string" and "\""..value.."\"" or tostring(value)
    end

    local mark={}

    local function v2s(str)

        --检测两个]
        local ret = str
        local num = 0
        ret , num = string.gsub(str,"]]","] ]")
        while num>0 do
            ret , num = string.gsub(ret,"]]","] ]")
        end

        --最后一个
        if string.sub(ret,-1,-1) == "]" then
            ret = ret .. " "
        end

        ret = "[[" .. ret .. "]]"

        return ret
    end

    local function t(n)
        return string.rep("\t",n)
    end
    local function ser_table(tbl,parent,lv)
        mark[tbl]=parent
        local tmp={}
        for k,v in pairs(tbl) do
            local key= type(k)=="number" and "["..k.."]" or k
            if type(v)=="table" then
                local dotkey= parent..(type(k)=="number" and key or "."..key)
                if mark[v] then
                    error("error!!! safe_serialize args has loopRef")
                    return "error!!!"
                else
                    table.insert(tmp, t(lv+1)..key.."="..ser_table(v,dotkey,lv+1))
                end
            else
                table.insert(tmp, t(lv+1)..key.."="..(type(v)=="string" and v2s(v) or tostring(v)))
            end
        end
        return "\n"..t(lv).."{\n"..table.concat(tmp,",\n").."\n"..t(lv).."}"
    end

    local str = ser_table(value,"ret",0)
    return str
end


--解析邮件数据
function basefunc.parse_lua_table_str(_data)

	local code = "return " .. _data
	local ok, ret = xpcall(function ()
		local data = loadstring(code)()
		if type(data) ~= 'table' then
			data = {}
			fault("parse_lua_table_str error : is not table")
		end
		return data
	end
	,function (err)
		local errStr = "parse_lua_table_str error : ".._data
		fault(errStr)
		fault(err)
	end)

	if not ok then
		ret = {}
	end

	return ret or {},ok
end



-- 成员函数 转换为普通函数
function basefunc.handler(obj, method)
	if not obj or not method then
		error("handle:obj or method is nil",2)
	end

    return function(...)
        return method(obj, ...)
    end
end

-- 判断变化：
-- 		1、针对 _new 中不为 nil 的值 和 _old 比较
--		如果 _new 的值 和 _old 不同，则 加入到返回表中； 
-- 参数 _merge ： 如果为 true ，则新值 更新到 _old
-- 返回： 变化表； 返回 nil 表示 无变化
function basefunc.changes(_old,_new,_merge)
	local _ret
	for k,v in pairs(_new) do
		if v ~= _old[k] then
			_ret = _ret or {}
			_ret[k] = v
			if _merge then
				_old[k] = v
			end
		end
	end

	return _ret
end
-- 浅拷贝
-- 参数 includes ： 包含列表，包含在这里面的才会被拷贝
function basefunc.copy(value,includes)

    if type(value) ~= "table" then
        return value
    end

	local ret = {}
	for k, v in pairs(value) do
		if not includes or includes[k] then
			ret[k] = v
		end
	end
	return ret
end

function basefunc.array_copy(_src,_dest)
	if _src and _dest then
		for _,v in ipairs(_src) do
			_dest[#_dest + 1] = v
		end
	end
	return _dest
end

-- 合并表内容
-- 参数 dest 可为 nil
-- 参数 includes ： 包含列表，在这里面的键 才会被拷贝
-- 参数 excludes ： 排除列表，在这里面的键 不会被拷贝（即使在 includes 中 ）
-- 返回合并后的表
function basefunc.merge(src,dest,includes,excludes)

	dest = dest or {}
	if src then
		for k,v in pairs(src) do
			if (not includes or includes[k]) and (not excludes or not excludes[k]) then
				dest[k] = v
			end
		end
	end

	return dest
end

-- 合并表内容
-- 参数 dest 可为 nil
-- 参数 filter ： 过滤器（可选），包含在这里面的键 不会被拷贝
-- 返回合并后的表
-- function basefunc.merge_filter(src,dest,filter)

-- 	dest = dest or {}
-- 	for k,v in pairs(src) do
-- 		if not filter or not filter[k] then
-- 			dest[k] = v
-- 		end
-- 	end

-- 	return dest
-- end

-- 深合并
-- excl_types 不包含的类型，例如 'function'
function basefunc.deepmerge(value,dest,excl_types)

    if type(value) ~= "table" then
        return value
    end

	-- 已拷贝对象
	local copedSet = {}

	local function _copy(src_,dest_)

		local ret = dest_ or {}
		copedSet[src_] = ret

		for k, v in pairs(src_) do
			if not excl_types or not excl_types[type(v)] then
				if type(v) ~= "table" then
					ret[k] = v
				else
					if copedSet[v] then
						-- 重复表 仅仅引用
						ret[k] = copedSet[v]
					else
						ret[k] = _copy(v,dest_ and dest_[k])
					end
				end
			end
		end
		return ret
	end

	return _copy(value,dest)
end

-- 表反序
function basefunc.reverse(_t)
	local _c = floor(#_t/2)
	for i=1,_c do
		local _tmp = _t[i]
		_t[i] = _t[#_t-i+1]
		_t[#_t-i+1] = _tmp
	end
end

-- 计算表中的 key 数量
function basefunc.key_count(_t)
	local _count = 0
	for _,_ in pairs(_t) do
		_count = _count + 1
	end

	return _count
end

function basefunc.value_count(_t)
	local _count = 0
	if _t and next(_t) then
		for _, v in pairs(_t) do
			_count = _count + v
		end
	end
	return _count
end

-- 表中的多级 key 定位
function basefunc.from_keys(_t,...)

	local n = select("#",...)

	for i=1,n do
		_t = _t[select(i,...)]

		if i~=n and type(_t) ~= "table" then -- 没找到
			return nil
		end
	end

	return _t

end
local from_keys = basefunc.from_keys

-- 表中多级 key 赋值， _v 为 nil 表示删除
function basefunc.to_keys(_t,_v,...)

	local n = select("#",...)

	for i=1,n do
		local k = select(i,...)
		if i == n then
			_t[k] = _v
		else

			if nil == _t[k] then

				if nil == _v then -- 删除，则不再找下去
					break
				end

				_t[k] = {}
			end

			_t = _t[k]
		end
	end

end

local function _try_pcall_result(_ok,_err,...)
    if _ok then
        return nil,_err,...   -- 无错误，返回 nil + 正常返回值
    else
        return _err or "[try error]" -- 返回错误信息
    end
end

--[[ 
    模拟 C++ 的 try...catch 机制
    参数：
        _deal_func   function() 正常要处理的代码块
        _final_func  function(_err_msg,...) 无论 _deal_func 是否出错，结束时总会被调用的代码块; 
                    _err_msg 为 nil 表示无错误（语言层面的崩溃）
                    ... 表示 _deal_func 的返回值
                注意： _final_func 函数本身 不能再有错误

    返回：_final_func 的返回值 原样返回
    
--]]
function basefunc.try(_deal_func,_final_func)

    return _final_func(_try_pcall_result(xpcall(_deal_func,error_handle)))
    
end

-- 确保表中包含 多层键， 没有则 加入值 _v
function basefunc.safe_keys(_t,_v,...)
	local _old = basefunc.from_keys(_t,...)
	if _old then
		return _old
	else
        _v = _v or {}
		basefunc.to_keys(_t,_v,...)
		return _v
	end
end

-- 确保表中包含 多层键， 没有则 加入值 _cb()
function basefunc.safe_keys_cb(_t,_cb,...)
	local _old = basefunc.from_keys(_t,...)
	if _old then
		return _old
	else
        local _v = _cb()
		basefunc.to_keys(_t,_v,...)
		return _v
	end
end

-- 安全含 清除多层键
function basefunc.del_keys(_t,...)
	local _old = basefunc.from_keys(_t,...)
	if _old then
		basefunc.to_keys(_t,nil,...)
	end
end

function basefunc.random_pop(_t)

	local _count = #_t

	if _count == 0 then
		return nil
	end

	local _index = random(_count)

	local ret = _t[_index]

	-- 用最后一个 补位
	_t[_index] = _t[_count]
	_t[_count] = nil

	return ret

end

-- 随机打乱数组： 在原来的基础上打乱
function basefunc.ruffle_list(_t)
    if type(_t) ~= "table" then
        return _t
    end

    local _tmp = basefunc.copy(_t)
    
    for i=1,#_t do
        _t[i] = basefunc.random_pop(_tmp)
    end

    return _t
end

-- 从 表中随机选择一项
-- 参数：
-- 	_percent ： 每一项中 概率百分比的 字段名； nil 表示 概率均等
-- 	_percent_sum ： 所有项目的概率和， 默认为 100 ； 特殊的，如果为 1 ， 则不带参数调用 random()
-- 返回： 项目,index
function basefunc.random_select(_t,_percent,_percent_sum)
	if not _t or not _t[1] then
		return nil
	end

	local _sum = 0
	if _percent then
		local _prob
		if _percent_sum then
			_prob = _percent_sum == 1 and random() or random(_percent_sum)
		else
		 	_prob = random(100)
		end

		for i,_item in ipairs(_t) do
			_sum = _sum + (_item[_percent] or 0)
			if _prob <= _sum then
				return _item,i
			end
		end

		return _t[#_t],#_t
	else
		local _index = random(#_t)
		return _t[_index],_index
	end
end

-- 从概率数组（百分比）中返回 数组下标
function basefunc.ranodm_array_i(_array)
	if not _array or not _array[1] then
		return nil
	end

	local _sum = 0
	local _prob = random(100)
	for i,_cur in ipairs(_array) do
		_sum = _sum + _cur
		if _prob <= _sum then
			return i
		end
	end

	return nil
end

-- 将参数 用 tab 分割 连接到一起
function basefunc.concat_param(...)

	local _st = pack(...)
	for i=1,_st.n do
		_st[i] = tostring(_st[i])
	end

	return table.concat(_st,"\t")
end

local function readonly_get_v(_t,_k)

	local _ro = rawget(_t,"__ro_data")

	local _v = _ro.orig_t[_k]

	if "table" == type(_v) then

		-- 成员值已经变化，重新生成 readonly 数据
		if _ro.orig_children[_k] ~= _v then
			_ro.orig_children[_k] = _v
			_ro.wrap_children[_k] = basefunc.readonly(_v)
		end

		return _ro.wrap_children[_k]
	else
		return _v
	end
end

local function readonly_set_v(_gv_t,_gv_k)
	error("table is readonly!")
end

-- 返回一个表的只读引用
function basefunc.readonly(_t)

	return setmetatable(

		{__ro_data={orig_t=_t,wrap_children={},orig_children={}}},

		{__index=readonly_get_v,__newindex=readonly_set_v}

		)
end

-- 得到多级子孙，中间任何位置为 nil 则返回 nil
function basefunc.offspring(_t,...)
	local _l = _t
	for _,_k in ipairs({...}) do
		if not _l[_k] then
			return nil
		else
			_l = _l[_k]
		end
	end

	return _l
end

-- 键/值交换
-- 如果 值重复，则只放一个
-- 参数 _new_v ： 如果不为 nil ，则 作为所有值的填充内容
function basefunc.exchange_kv(_t,_new_v)
	if type(_t) ~= "table" then
		return _t
	end

	local ret = {}
	for _k,_v in pairs(_t) do
		ret[_v] = ret[_v] or _new_v or _k
	end

	return ret
end

function basefunc.is_array_table(t)
    if type(t) ~= "table" then
        return false
    end

    local n = #t
    for i,v in pairs(t) do
        if type(i) ~= "number" then
            return false
        end

        if i > n then
            return false
        end
    end

    return true
end

-- 替换字符串中的嵌入变量
function basefunc.repl_str_var(_str,_vars,_default)

	local _s,_

	if _default then
		_s,_ = string.gsub(_str,"@(%g-)@",function(_name)
			return _vars[_name] or _default
		end)
	else
		_s,_ = string.gsub(_str,"@(%g-)@",_vars)
	end

	return _s
end

local function trans_text_base(_text,_func,_level,_max_level)
	local _s,_

    local _is_fun = type(_func) == "function"

    local _context  -- 当前递归层次的上下文
    if _is_fun then
        _context = {}
    end

    _s,_ = string.gsub(_text,"{(%g-)}",function(_name)

        local _ret = _is_fun and _func(_name,_context) or _func[_name]

        if not _ret then
            return nil
        elseif _level < _max_level then
            return trans_text_base(_ret,_func,_level+1,_max_level)
        else
            return _ret
        end
    end)

	return _s
end

--[[
    替换字符串，支持多层嵌套（repl_str_var的增强）
    参数 ：
        _text ： 带变量的字符串，变量格式 {name}
        _func : 回调函数 function(_name)
                参数：
                    _name    变量名
                    _context 上下文（同一递归层次共享数据）， 可以不使用
                返回值：
                    返回 nil/false 表示 不替换，用原始字串
        _max_level : 最大递归层次
--]]
function basefunc.trans_text(_text,_func,_max_level)
    _max_level = _max_level or 5
    return trans_text_base(_text,_func,1,_max_level)
end

-- 将 value 转换成一个可读的调试字符串
function basefunc.tostring( value, recMax,_lineFeed ,_max_len,_nofunction)

    if _nofunction ~= false then -- 默认为 true ，明确 传递 false 才不屏蔽 函数
        _nofunction = true
    end

	-- by lyx
	if type(value) ~= "table" then
		return tostring(value)
	end

	_lineFeed = _lineFeed or "\n"

	recMax = recMax or 30
	local stringBuffer = {}

	local _len = 0
	local _str_too_long = false

    -- 已处理的表
    local dealTable = {}

	local function __tab_string( count )
		local tabl = {}
		for i = 1, count do
			table.insert( tabl, "  " )
		end
		return table.concat( tabl, "" )
	end

	local function insert_string(_str)
		if _max_len and (string.len(_str) + _len > _max_len) then
			table.insert( stringBuffer, "<<<<string is too long!>>>>" )
			_str_too_long = true
			return false
		else
			_len = string.len(_str) + _len
			table.insert( stringBuffer, _str )
			return true
		end
	end

	local function __var_to_string(_v)
		if "string" == type(_v) then
			return "\"" .. _v .. "\""
		else
			return tostring(_v)
		end
	end
	local function __key_to_string(_v)
		if "string" == type(_v) then
			return _v
		else
			return "[" .. tostring(_v) .. "]"
		end
	end

	local function __table_to_string( tableNow, recNow )

		-- by lyx
		if value == nil then 
            return "nil" 
        end

        -- 重复引用
        if dealTable[tableNow] then
            insert_string( "ref:" .. tostring( tableNow ) .. "," .. _lineFeed)
            return
        end
        dealTable[tableNow] = true

		if( recNow > recMax ) then
			insert_string( tostring( tableNow ) .. "," .. _lineFeed)
			return
		end

		if not insert_string("{" .. _lineFeed) then
			return
		end
		for k, v in pairs( tableNow ) do
            if not _nofunction or type(v) ~= "function" then
                if not insert_string(__tab_string(recNow) .. __key_to_string( k ) .. "=" ) then
                    return
                end
            
                if( "table" ~= type(v) ) then
                    if not insert_string(__var_to_string( v ) .. "," .. _lineFeed) then
                        return
                    end
                else
                    __table_to_string( v, recNow + 1 )

                    if _str_too_long then
                        return
                    end
                end
            end
		end

		insert_string(__tab_string(recNow-1) .. "}," .. _lineFeed)
	end

	__table_to_string( value, 1 )
	return table.concat( stringBuffer, "" )
end

function basefunc.table_to_prettyjsonstring( aTable, recMax )
	recMax = recMax or 20
	local stringBuffer = {}
	local function __tab_string( count )
		if( not count ) then
			return ""
		else
			return string.rep( "  ", count )
		end
	end
	local function __validateStr( str )
		local s = str
		s = string.gsub(s,'\\','\\\\')
		s = string.gsub(s,'"','\\"')
		s = string.gsub(s,"'","\\'")
		s = string.gsub(s,'\n','\\n')
		s = string.gsub(s,'\t','\\t')
		return s
	end
	local function __innert( tableNow, recNow )
		if( recNow > recMax ) then
			table.insert( stringBuffer, '"'..__validateStr( tostring(tableNow)..'"' ) )
			return
		end
		local isArray = basefunc.is_array_table( tableNow )
		local lastStr = stringBuffer[#stringBuffer]
		if( lastStr and lastStr[#lastStr] ~= "\n") then
			stringBuffer[#stringBuffer+1] = "\n"
		end

		if( isArray ) then
			stringBuffer[#stringBuffer+1] = __tab_string(recNow).."[\n"
			for i, v in ipairs( tableNow ) do
				if( "table" == type(v) ) then
					__innert( v, recNow+1 )
				else
					local valueStr = tostring(v)
					if( type(v) == "string" ) then
						valueStr = '"'..__validateStr( valueStr )..'"'
					end
					stringBuffer[#stringBuffer+1] = __tab_string(recNow+1)..valueStr..",\n"
				end
			end
		else
			table.insert( stringBuffer, __tab_string(recNow).."{\n" )
			for k, v in pairs( tableNow ) do
				local keyStr = tostring(k)--key 不做__validateStr
				stringBuffer[#stringBuffer+1] = __tab_string(recNow+1) .. string.format( [["%s" : ]], keyStr )
				if( "table" == type(v) ) then
					__innert( v, recNow+1 )
				else
					local valueStr = tostring( v )
					if( type(v) == "string" ) then
						valueStr = '"'..__validateStr( valueStr )..'"'
					end
					stringBuffer[#stringBuffer+1] = valueStr..",\n"
				end
			end
		end

		local lastStr = stringBuffer[#stringBuffer]
		stringBuffer[#stringBuffer] = string.sub( lastStr, 1, #lastStr-2 ).."\n"
		if( isArray ) then
			stringBuffer[#stringBuffer+1] = __tab_string(recNow).. "],\n"
		else
			table.insert( stringBuffer, __tab_string(recNow) .. "},\n" )
		end
	end

	__innert( aTable, 0 )
	local lastStr = stringBuffer[#stringBuffer]
	stringBuffer[#stringBuffer] = string.sub( lastStr, 1, #lastStr-2 ).."\n"
	return table.concat( stringBuffer )
end



-- 深拷贝
-- excl_types : 不拷贝的类型，比如 'function'
function basefunc.deepcopy(value,excl_types)

    if type(value) ~= "table" then
        return value
    end

	-- 已拷贝对象
	local copedSet = {}

	local function _copy(src_)

		local ret = {}
		copedSet[src_] = ret

		for k, v in pairs(src_) do
			if not excl_types or not excl_types[type(v)] then
				if type(v) ~= "table" then
					ret[k] = v
				else
					if copedSet[v] then
						-- 重复表 仅仅引用
						ret[k] = copedSet[v]
					else
						ret[k] = _copy(v)
					end
				end
			end
		end
		return ret
	end

	return _copy(value)
end

-- update 时间同步
-- 参数：
--	time 本地时间
--	refer 参考时间，如果 为 nil ，则不需要同步
--	speed 同步速度，每秒 贴近 时间
-- 返回： 新的本地时间,参考时间
local math_min = math.min
function basefunc.sync_update(dt,time,refer,speed)

	if not refer then
		return time+dt,nil
	end

	-- 修正量：不能超过 1 秒，否则会出现时间倒退
	local corr = math_min((speed or 0.5),1) * dt

	-- 差异
	local diff = refer - time

	if diff > 0 then
		if corr >= diff then
			return refer + dt,nil				-- 下次无需再修正
		else
			return time + dt + corr,refer + dt	-- 追 refer 时间
		end
	elseif diff < 0 then
		if corr >= -diff then
			return refer + dt,nil				-- 下次无需再修正
		else
			return time + dt - corr,refer + dt	-- 等 refer 时间
		end
	end
end

-- 删除多个表元素：从 pos 开始 n 个
function basefunc.tremove(t,pos,n)
	if n == 0 then return end

	for i=pos,999999,1 do
		t[i]=t[i+n]
		if not t[i] and not t[i+1] then
			break
		end
	end
end


-- 将表中 pos1 到 pos2 设置为 nil
function basefunc.tsetnil(t,pos1,pos2)
	pos1 = pos1 or 1
	pos2 = pos2 or #t
	for i=pos1,pos2 do
		t[i] = nil
	end
end


-- 安全的得到字典 t 中的值
function basefunc.getitem(t,k,creator,...)
	local v = t[k]
	if v then
		return v
	else
		v = basefunc.create(creator,...)
		t[k] = v
		return v
	end
end

local function _dump_value_(v)
    if type(v) == "string" then
        v = "\"" .. v .. "\""
    end

    return tostring(v)
end

local function _dump_key_(v)
    if type(v) == "number" then
        return "[" .. tostring(v) .. "]"
    elseif type(v) == "string" and string.match(v,"^[%a_][%a%d_]*$") then
        return v
    end

    return "[\"" .. tostring(v) .. "\"]"
end

function basefunc.dump(value, nesting,nofunction)

    if type(nesting) ~= "number" then nesting = 30 end

    local refTableIndex = 0

    -- 表 hash => {line=,refTableIndex=}
    local lookupTable = {}

    local result = {}

    local function dump_(value, description, indent, nest, keylen)
        local spc = ""
        if type(keylen) == "number" then
            spc = string.rep(" ", keylen - (description and string.len(_dump_key_(description)) or 0))
        end
        if type(value) ~= "table" then
            if description then
                result[#result +1 ] = string.format("%s%s%s = %s", indent, _dump_key_(description), spc, _dump_value_(value))
            else
                result[#result +1 ] = indent .. _dump_value_(value)
            end
        elseif lookupTable[tostring(value)] then

            -- 引用表 序号
            if not lookupTable[tostring(value)].refTableIndex then
                refTableIndex = refTableIndex + 1
                lookupTable[tostring(value)].refTableIndex = refTableIndex

                result[lookupTable[tostring(value)].line] = result[lookupTable[tostring(value)].line] .. "    -- *REF:" .. tostring(refTableIndex) .. "*"
            end

            if description then
                result[#result +1 ] = string.format("%s%s%s = *REF:%s*", indent, _dump_key_(description), spc,tostring(lookupTable[tostring(value)].refTableIndex))
            else
                result[#result +1 ] = indent .. "*REF:" .. tostring(lookupTable[tostring(value)].refTableIndex) .. "*"
            end
        else
            lookupTable[tostring(value)] = {line=#result+1}
            if nest > nesting then
                if description then
                    result[#result +1 ] = string.format("%s%s = *MAX NESTING*", indent, _dump_key_(description))
                else
                    result[#result +1 ] = indent .. "*MAX NESTING*"
                end
            else
                if description then
                    result[#result +1 ] = string.format("%s%s = {", indent, _dump_key_(description))
                else
                    result[#result +1 ] = indent .. "{"
                end
                local indent2 = indent.."    "
                local keys = {}
                local keylen = 0
                local values = {}
                for k, v in pairs(value) do
                    if not nofunction or type(v) ~= "function" then
                        keys[#keys + 1] = k
                        local vk = _dump_value_(k)
                        local vkl = string.len(vk)
                        if vkl > keylen then keylen = vkl end
                        values[k] = v
                    end
                end
                table.sort(keys, function(a, b)
                    if type(a) == "number" and type(b) == "number" then
                        return a < b
                    else
                        return tostring(a) < tostring(b)
                    end
                end)
                local _array_len = 0
                for i, k in ipairs(keys) do
                    if type(k) == "number" and k > 0 and k <= _array_len then
                        
                        dump_(values[k], nil, indent2, nest + 1, keylen)
                    else
                        dump_(values[k], k, indent2, nest + 1, keylen)
                    end
                    result[#result] = result[#result] .. ","
                end
                result[#result +1] = string.format("%s}", indent)
            end
        end
    end
    dump_(value, nil , " ", 1)

    return table.concat(result,"\n")
end

function basefunc.array_partial( array, predicate, iBegin, iEnd )
	local function  __swap( idx1, idx2 )
		local temp = array[idx1]
		array[idx1] = array[idx2]
		array[idx2] = temp
	end
	if iBegin >= iEnd then return  end
	local i = iBegin
	local j = iEnd
	repeat
		if i >= j then
			break
		end
		repeat
			if i == j then break end
			if not predicate(array[i]) then break end
			i = i + 1
		until false
		repeat
			if i == j then break end
			if predicate(array[j]) then break end
			j = j-1
		until false
		__swap( i, j )
	until false
	assert( i == j )
	if predicate(array[i]) then
		return i+1
	else
		return i
	end
end

local function __test_array_partial()
	local array = {}
	for i = 1, 10000 do
		array[#array+1] = random( 1, 10 )
	end

	local function __predicate( item )
		return item < 5
	end

	local mid = basefunc.array_partial( array, __predicate, 1, #array )
	for i = 1, mid-1 do
		print( "premid:", array[i] )
		assert( __predicate(array[i]) )
	end
	for i = mid, #array do
		print( "aftmid:", array[i] )
		assert( not __predicate(array[i]) )
	end
end



--[[
	将一个数组给定的区间随机打乱,[iBegin, iEnd]
	@iBegin 起始下标，默认为1
	@iEnd 结束下标，默认 = 数组长度
]]
function basefunc.array_shuffle( _array, _begin, _end )

	_begin = _begin or 1
	_end = _end or #_array

	if #_array < 2 then return end
	if _end <= _begin then return end
	if _begin < 1 then return end

	for i = _begin, _end-1 do

		local r = random( i, _end )

		if r>i then
			_array[i],_array[r]=_array[r],_array[i]
		end

	end

end

function basefunc.array_filter_i( array, iBegin, iEnd, predicate )
	local newArray = {}
	for i = iBegin, iEnd do
		if not predicate( array[i] ) then
			newArray[#newArray+1] = array[i]
		end
	end
	return newArray
end

function basefunc.array_filter( array, predicate )
	return basefunc.array_filter_i(array,1,#array,predicate)
end

function basefunc.array_map_i(array,iBegin,iEnd,func)
	local newArray = {}
	for i = iBegin, iEnd do
		newArray[#newArray+1] = func( array[i] )
	end
	return newArray
end

function basefunc.array_map( array, func  )
	return basefunc.array_map_i(array,1,#array,func)
end

----------------------------
-- datable 数据表格


basefunc.datable = basefunc.class()

function basefunc.datable:ctor()

	-- 列名数组
	self.columns = {}

	-- 列名 => 列序号
	self.colindex = {}

	-- 数据行
	self.rows = {}

	-- 行拷贝函数
	self._rowCopyRow = function(selfRow)
		return self:copyrow(selfRow)
	end

	-- 行的元表：自动判断 下标 or 名称 方式的访问
	self._rowmeta = {
		__index = function(row,name)
			if "number" == type(name) then
				return rawget(row,name)
			else
				if "copyrow" == name then
					return self._rowCopyRow
				else
					return rawget(row,self.colindex[name])
				end
			end
	end}
end

function basefunc.datable:addcolumn(name)
	table.insert(self.columns,name)

	self.colindex[name] = #self.columns
end

-- 加入行：自动识别 字典和数组，字典优先
function basefunc.datable:addrow(row)
	local rowdata = {}
	for icol,ncol in ipairs(self.columns) do
		table.insert(rowdata,row[ncol] or row[icol])
	end

	table.insert(self.rows,setmetatable(rowdata,self._rowmeta))
end

-- 拷贝一行
function basefunc.datable:copyrow(row)
	local rowdata = {}
	for i,name in ipairs(self.columns) do
		rowdata[name] = row[i]
	end

	return rowdata
end

-- 拷贝为普通lua表
function basefunc.datable:copydata()
	local rows = {}

	for i,row in ipairs(self.rows) do
		rows[#rows + 1] = self:copyrow(row)
	end

	return rows
end


----------------------------
-- datagrid 按行列查询的数据网格


basefunc.datagrid = basefunc.class()

function basefunc.datagrid:ctor(head,data)

	self.head = head

	self._colIndex = {}
	self._rowIndex = {}

	self._rows = data

	for i,colname in ipairs(head) do
		self._colIndex[colname] = i
	end

	for i,row in ipairs(data) do
		self._rowIndex[row[1]] = i
	end

end

function basefunc.datagrid:getcell(rowName,colName)
	local irow = self._rowIndex[rowName]
	local icol = self._colIndex[colName]

	return irow and icol and self._rows[irow][icol]
end

function basefunc.datagrid:dump()
	for _,row in ipairs(self._rows) do
		for _,colname in ipairs(self.head) do
			print(row[1],colname,self:getcell(row[1],colname))
		end
	end

end

----------------------------
-- queue 队列（仅允许从首尾增删）


basefunc.queue = basefunc.class()


function basefunc.queue:ctor()

	self._front = 0
	self._back = -1

end

function basefunc.queue:size()
	return self._back-self._front +1
end

-- 是否为空
function basefunc.queue:empty()
	return self._front > self._back
end

function basefunc.queue:clear()
	if self:empty() then return end

	for i=self._front,self._back do
		self[i] = nil
	end

	self._front = 0
	self._back = -1
end

function basefunc.queue:push_front(obj)
	self._front = self._front - 1
	self[self._front] = obj
end

function basefunc.queue:push_back(obj)
	self._back = self._back + 1
	self[self._back] = obj
end

function basefunc.queue:front()

	return self[self._front]
end

function basefunc.queue:back()
	return self[self._back]
end

function basefunc.queue:clear()
	if self:empty() then return end

	for i=self._front,self._back do
		self[i] = nil
	end

	self._front = 0
	self._back = -1
end

function basefunc.queue:pop_front()
	if self._front > self._back then return nil end

	local ret = self[self._front]
	self[self._front] = nil
	self._front = self._front + 1
	return ret
end

function basefunc.queue:pop_back()
	if self._front > self._back then return nil end

	local ret = self[self._back]
	self[self._back] = nil
	self._back = self._back - 1
	return ret
end

function basefunc.queue:front_id()
	return self._front
end

function basefunc.queue:back_id()
	return self._back
end

-- 迭代器
function basefunc.queue:values()
	local i = self._front - 1
	return function() i = i + 1 return self[i] end
end

-- 反向迭代器
function basefunc.queue:rvalues()
	local i = self._back + 1
	return function() i = i - 1 return self[i] end
end

-- 清空
function basefunc.queue:clear()
	while self:pop_back() do end
    self._front = 0
	self._back = -1
end

-------------------------------
-- csv 写入类

basefunc.csvwriter = basefunc.class()

--[[
    参数： 
        _file_name 文件名
        _title 标题列表： 数组
        _format 格式化字符串(可选)， 例如： "%s,%f,%d"
--]]
function basefunc.csvwriter:ctor(_file_name,_title,_format)

    self.file_name = _file_name
    self.file = io.open(self.file_name,"a")

    self.title = _title
    self.format = _format

    -- 还没有标题，  写入标题
    if self.file:seek("end") < 5 then
        self.file:write(table.concat(self.title,",") .. "\n")
    end
end

function basefunc.csvwriter:add(_v1,...)
    local _t 
    if type(_v1) == "table" then
        _t = _v1
    else
        _t = table.pack(_v1,...)
    end

    local _s
    if self.format then
        _s = string.format(self.format,table.unpack(_t))
    else
        local _ss = {}
        for i=1,#self.title do
            table.insert(_ss,tostring(_t[i]))
        end
        _s = table.concat(_ss,",")
    end

    self.file:write(_s .. "\n")
end

function basefunc.csvwriter:flush()

    self.file:flush()
end

function basefunc.csvwriter:close()
	self.file:close()
end

-------------------------------
-- list 链表（允许从任意位置增删）

basefunc.list = basefunc.class()


function basefunc.list:ctor()

	self._front = nil
	self._back = nil

	self._size = 0
end

-- 是否为空
function basefunc.list:empty()
	return nil == self._front
end

-- 清空
function basefunc.list:reset()
	self._front = nil
	self._back = nil
	self._size = 0
end

-- 计算长度，注意：采用遍历的方法统计
function basefunc.list:size()

	return self._size
end

-- 计算尺寸是否大于 给定的数值
function basefunc.list:greater(size)
	local cur = self._front
	local count = 0
	while cur do
		count = count + 1

		if count > size then
			return true
		end

		cur=cur.next
	end

	return false
end

function basefunc.list:push_front(obj)

	self:push_front_item({obj})
end

function basefunc.list:push_front_item(_item)
	local cur = self._front

	_item.prev = nil
	_item.next = cur

	self._front = _item
	if cur then
		cur.prev = self._front
	else
		self._back = self._front
	end

	self._size = self._size + 1
end

function basefunc.list:push_back(obj)

	self:push_back_item({obj})
end

function basefunc.list:push_back_item(_item)

	local cur = self._back

	_item.prev = cur
	_item.next = nil

	self._back = _item
	if cur then
		cur.next = self._back
	else
		self._front = self._back
	end

	self._size = self._size + 1
end

-- 将另一个 list 合并到前面，other 将被清空
function basefunc.list:merge_front(other)

	if other and not other:empty() then
		local cur = self._front
		self._front = other._front
		if cur then
			cur.prev = other._back
			other._back.next = cur
		else
			self._back = other._back
		end

		self._size = self._size + other._size

		other:reset()
	end
end

-- 将另一个 list 合并到后面，other 将被清空
function basefunc.list:merge_back(other)

	if other and not other:empty() then

		local cur = self._back
		self._back = other._back
		if cur then
			cur.next = other._front
			other._front.prev = cur
		else
			self._front = other._front
		end

		self._size = self._size + other._size

		other:reset()
	end
end

function basefunc.list:front()

	return self._front and self._front[1]
end

function basefunc.list:back()
	return self._back and self._back[1]
end

-- 得到内部迭代器
function basefunc.list:front_item()
	return self._front
end
function basefunc.list:back_item()
	return self._back
end

function basefunc.list:pop_front()
	if not self._front then return nil end

	local ret = self._front[1]

	self:erase(self._front)

	return ret
end

function basefunc.list:pop_back()
	if not self._back then return nil end

	local ret = self._back[1]

	self:erase(self._back)

	return ret
end

function basefunc.list:pop_back_item()
	if not self._back then return nil end

	local ret = self._back

	self:erase(self._back)

	return ret
end

function basefunc.list:erase(item)

	-- 更新前一个
	if item.prev then
		item.prev.next = item.next
	else
		self._front = item.next
	end

	-- 更新下一个
	if item.next then
		item.next.prev = item.prev
	else
		self._back = item.prev
	end

	self._size = self._size - 1

	-- 返回下一个
	return item.next

	-- 移除引用
	-- 这个可能也正在 闭包中使用(2014-4-26) item[1] = nil

	-- （★★★ 注意，绝对不能移除 next,prev，这个 item 如果在迭代器闭包中使用 将导致遍历终止；）
--	item.next = nil
--	item.prev = nil
end

-- 插入元素
function basefunc.list:insert(obj,where)
	if where then
		local objItem = {obj,prev=where.prev,next=where}
		where.prev = objItem
		if objItem.prev then
			objItem.prev.next = objItem
		end
		self._size = self._size + 1
	else
		self:push_back(obj)
	end

end

-- 迭代器
function basefunc.list:values()
	local i = {next=self._front}
	return function() i = i.next return i and i[1] end
end

-- 反向迭代器
function basefunc.list:rvalues()
	local i = {prev=self._back}
	return function() i = i.prev return i and i[1] end
end

-- 迭代器（返回 item,value）
function basefunc.list:pairs()
	local i = {next=self._front}

	return function()
		i = i.next
		if i then
			return i,i[1]
		else
			return nil,nil
		end
	end
end

-- 反向迭代器（返回 item,value）
function basefunc.list:rpairs()
	local i = {prev=self._back}
	return function()
		i = i.prev
		if i then
			return i,i[1]
		else
			return nil,nil
		end
	end
end


----------------------------
-- 链表 和 映射的组合，支持 任意位置插入 及 快速查找、删除
-- 内部 链表 通过 basefunc.list 实现
-- 使用注意： 所有修改的方法都必须调用 listmap 的成员；读取、查询、遍历的 方法可以直接 调用 list 或 map 成员中的方法

basefunc.listmap = basefunc.class()

function basefunc.listmap:ctor()

	-- 数据链表： value
	self.list = basefunc.list.new()

	-- 键映射： key => listitem
	self.map = {}

end

-- 是否为空
function basefunc.listmap:empty()
	return nil == self.list._front
end

function basefunc.listmap:size()
	return self.list:size()
end

function basefunc.listmap:push_front(key,value)

	assert(key,"listmap key is nil!")
	assert(not self.map[key],"listmap key is conflicted !")

	self.list:push_front(value)
	local item = self.list:front_item()
	item[2] = key	-- 记录键的标记
	self.map[key] = item
end

function basefunc.listmap:push_back(key,value)
	assert(key,"listmap key is nil!")
	assert(not self.map[key],"listmap key is conflicted !")

	self.list:push_back(value)
	local item = self.list:back_item()
	item[2] = key	-- 记录键的标记
	self.map[key] = item
end

function basefunc.listmap:insert(key,value,where)
	assert(key,"listmap key is nil!")
	assert(not self.map[key],"listmap key is conflicted !")

	self.list:insert(value,where)
	where.prev[2] = key	-- 记录键的标记
	self.map[key] = where.prev
end

function basefunc.listmap:erase(key)
	local item = self.map[key]

	if item then
		self.list:erase(item)
		self.map[key] = nil
	end
end

function basefunc.listmap:at(key)
	local item = self.map[key]
	return item and item[1]
end

function basefunc.listmap:set(key,value)
	local item = self.map[key]
	if item then
		item[1] = value
	end
end

function basefunc.listmap:pop_front()

	local item = self.list:front_item()
	if not item then
		return nil,nil
	end

	self.map[item[2]] = nil
	self.list:pop_front()

	-- 返回 key , value
	return item[2],item[1]
end

function basefunc.listmap:pop_back()

	local item = self.list:back_item()
	if not item then
		return nil,nil
	end
	
	self.map[item[2]] = nil
	self.list:pop_back()

	-- 返回 key , value
	return item[2],item[1]
end

----------------------------
-- 数组 和 映射的组合，支持 快速从数组尾部增加 和 删除
-- 内部 数组 采用 lua 表
-- 使用注意：如果 是 从数组中间 插入 或删除 复杂度为 O(n)

basefunc.vectormap = basefunc.class()

function basefunc.vectormap:ctor()

	-- 数组
	self.vector = {}

	-- 键映射： key => 下标
	self.map = {}

end

-- 是否为空
function basefunc.vectormap:empty()
	return self.vector[1] ~= nil
end

function basefunc.vectormap:push_back(key,value)

	assert(key,"listmap key is nil!")
	assert(not self.map[key],"listmap key is conflicted !")

	self.vector[#self.vector + 1] = value
	self.map[key] = #self.vector
end

function basefunc.vectormap:insert(key,value,index)
	assert(key,"listmap key is nil!")
	assert(not self.map[key],"listmap key is conflicted !")

	if index > #self.vector then
		self:push_back(key,value)
	elseif index > 0 then
		table.insert(self.vector,index,value)
		for _k,_i in pairs(self.map) do
			if _i >= index then
				self.map[_k] = _i + 1
			end
		end

		self.map[key] = index
	end
end

function basefunc.vectormap:erase_at(index)

	if index and index > 0 and index <= #self.vector then

		table.remove(self.vector,index)
		for _k,_i in pairs(self.map) do
			if _i == index then
				self.map[_k] = nil
			elseif _i > index then
				self.map[_k] = _i - 1
			end
		end
	end
end

function basefunc.vectormap:erase(key)
	self:erase_at(self.map[key])
end


----------------------------
-- 共享布尔对象：1个以上的对象设置为 true ，则为 true ；各对象采用名称标识
-- 可以链接 信号，当值变化为 false 时，能收到信号

basefunc.sharebool = basefunc.class()
function basefunc.sharebool:ctor()
	self._objects = {}
	self._count = 0

	self._signal = nil
end

-- 如果 name 不为 nil ，则判断该名字设否已设置
function basefunc.sharebool:value(name)
	return name and self._objects[name] or (self._count > 0)
end

-- 按名字设置
function basefunc.sharebool:set(name)
	if not self._objects[name] then
		self._count = self._count + 1
		self._objects[name] = true
	end
end

-- 按名字清除
function basefunc.sharebool:clear(name)
	if self._objects[name] then
		self._count = self._count - 1
		self._objects[name] = nil

		-- 第一次变为 false ，触发事件
		if self._signal and 0 == self._count then
			self._signal:trigger(false)
		end
	end
end

-- 重置为 false
function basefunc.sharebool:reset()
	self._objects = {}
	self._count = 0
end

-- 连接事件
function basefunc.sharebool:bind(obj,func)
	if not self._signal then
		self._signal = basefunc.signal.new()
	end

	self._signal:bind(obj,func)
end

-- 断开事件
function basefunc.sharebool:unbind(obj)
	if self._signal then
		self._signal:unbind(obj)
	end
end


----------------------------
-- 信号对象，允许对象 bind 上来，以便收取消息

basefunc.signal = basefunc.class()

function basefunc.signal:ctor()

	self._recviers = basefunc.listmap.new()

end

--[[
-- 将函数连接到 信号
-- 参数 ：
	obj		- 对象、字符串等可作为键的变量；此参数可选，如果不需要 unbind， 则可以不提供
	func	- 函数
--]]
local _next_obj_key = 0
function basefunc.signal:bind(obj,func)

	if not func then
		_next_obj_key = _next_obj_key + 1
		self:bind("_obj_key_" .. tostring(_next_obj_key),obj)
	else

		if not obj then
			error("signal: obj is nil!",2)
		end

		if not func then
			error("signal: func is nil!",2)
		end

		assert(func,"bind func is nil!")

		if self._recviers.map[obj] then
			self._recviers:set(obj,func)
		else
			self._recviers:push_back(obj,func)
		end
	end

end

-- 断开事件连接
function basefunc.signal:unbind(obj)

	self._recviers:erase(obj)

end

-- 是否空的（没有连接者）
function basefunc.signal:empty()
	return self._recviers.list:empty()
end

-- 修改已链接的函数（作为对调用次数敏感的某些特殊应用）
function basefunc.signal:alterconnect(obj,funcNew)
	self._recviers:set(obj,funcNew)
end

-- 触发事件
function basefunc.signal:trigger(...)

	local cur = self._recviers.list:front_item()
	while cur do
		xpcall(cur[1],error_handle,...)
		cur = cur.next
	end
end

-- 连接器对象
local signalConnector = basefunc.class()

-- 通过 ‘连接器’ 连接，断开时使用该‘连接器’对象
-- 此方法适用于 不方便提供对象 key 的情景
function basefunc.signal:withconnector(func)
	return signalConnector.new(self,func)
end

function signalConnector:ctor(signal,func)

	self._signal = signal
	signal:bind(self,func)
end

function signalConnector:alterconnect(funcNew)
	self._signal:alterconnect(self,funcNew)

	return self
end

function signalConnector:unbind()
	self._signal:unbind(self)
end

----------------------------
-- 消息分发器
-- 说明：
--	1、将消息按 名字分发给不同的对象
--	2、如果消息被多个对象处理，则第一个不返回 nil 的处理者的值会被返回。

basefunc.dispatcher = basefunc.class()

function basefunc.dispatcher:ctor()

	self._recviers={} 			-- 已连接的接收者，key=object ,value=msgtable
	self._namemap={}			-- 映射：消息名字 -> 接收者的列表, key=name,value=listmap(key=object,value=func)

end

function basefunc.dispatcher:dump(info)
	print(info or ("======== basefunc.dispatcher(" .. tostring(self) .. ") ========="))
	print("_recviers:")
	for k,v in pairs(self._recviers) do
		print("","obj=" .. tostring(k) .. ",msgtable="..tostring(v))
		for name,func in pairs(v) do
			print("","",name,func)
		end
	end
	print("_namemap:")
	for name,listmap in pairs(self._namemap) do
		print("",name)
		local cur = listmap.list:front_item()

		while cur do
			print("","","fun=" .. tostring(cur[1]),"obj=" .. tostring(cur[2]))
			cur = cur.next
		end

	end

end

--[[
-- 将函数连接到 信号
-- 参数 ：
	obj			- 对象
	msgtable	- 消息表，其中包含消息处理函数
--]]
function basefunc.dispatcher:register(obj,msgtable)

	if self._recviers[obj] then
		self:unregister(obj)
	end

	self._recviers[obj] = msgtable

	-- print("add dispatcher ",obj)

	for k,v in pairs(msgtable) do
		--print("",k,type(v))
		if "function" == type(v) then

			local funcmap = basefunc.getitem(self._namemap,k,basefunc.listmap)
			if funcmap.map[obj] then
				print("warning:register msg repeat",obj,k)
			else
--				print("",k,v)
            	funcmap:push_back(obj,v)
            end


		end
	end

	--self:dump()
end

-- 断开事件连接
function basefunc.dispatcher:unregister(obj)

	-- print("remove dispatcher",obj)

	local msgtable = self._recviers[obj]

	-- 清除名字映射
	if msgtable then

		for k,v in pairs(msgtable) do
			local funcmap = self._namemap[k]
			if funcmap then
--				print("",k,obj)
				funcmap:erase(obj)
			end
		end

		-- 清除对象
		self._recviers[obj] = nil
--	else
--		print("","no msgname")
	end

	--self:dump()
end

-- 判断指定的消息名字是否注册
function basefunc.dispatcher:registered(name)
	local limp = self._namemap[name]
	return limp and not limp:empty()
end

-- 调用消息
-- 参数 name ： 消息名字
function basefunc.dispatcher:call(name,...)

	local funcmap = self._namemap[name]
	local ok
	if funcmap then
		local r1 -- 仅支持一个返回值，否则 返回 多值 如果直接作为参数可能会出问题。,r2,r3,r4 -- 最多支持 4 个返回值
		--local tmp1--,tmp2,tmp3,tmp4

		local cur = funcmap.list:front_item()
		while cur do

			--tmp1 = cur[1](cur[2],...)

			-- 对于分发到多个接收这的返回值处理： 只处理第一个返回值不是 nil 接收者！
			if nil == r1 then
				ok,r1 = xpcall(cur[1],error_handle,cur[2],...)
			else
				xpcall(cur[1],error_handle,cur[2],...)
			end

			cur = cur.next
		end

		return r1
	end

	return nil
end

----------------------------
-- 缓存数据管理器
-- 说明：内部不保存数据，仅提供 cache 数据的冷热程度参考

basefunc.cache = basefunc.class()

function basefunc.cache:ctor()

	-- 访问队列
	self.visit_queue = basefunc.list.new()

	-- 多级 键映射： key1,key2,.. => listitem
	self.keys_map = {}

	self.size = 0
end

function basefunc.cache:__get_item(...)

	local n = select("#",...)

	local _t = self.keys_map
	for i=1,n do
		_t = _t[select(i,...)]
		if type(_t) ~= "table" and i~=n then -- 没找到
			return nil
		end
	end

	return _t
end

-- 如果 _item 为 nil ，则为删除
function basefunc.cache:__set_item(_item,...)

	local n = select("#",...)

	local _t = self.keys_map
	for i=1,n do
		local k = select(i,...)
		if i == n then
			_t[k] = _item
		else

			if nil == _t[k] then

				if nil == _item then -- 删除，则不再找下去
					break
				end

				_t[k] = {}
			end

			_t = _t[k]
		end
	end
end

function basefunc.cache:empty()
	return self.size < 1
end

-- ‘加热’ 数据
-- 参数：多级键列表
function basefunc.cache:hot(...)

	local _item = basefunc.from_keys(self.keys_map,...)

	if _item then

		-- 记下时间
		_item[1].ts = os.time()

		-- 移到队列头部
		self.visit_queue:erase(_item)
		self.visit_queue:push_front_item(_item)
	else
		self.size = self.size + 1

		self.visit_queue:push_front({ts=os.time(),keys=table.pack(...)})
		basefunc.to_keys(self.keys_map,self.visit_queue:front_item(),...)
	end
end

-- 得到尾部（最 ‘冷’） 的 key
-- 返回：时间戳 + key(如果是多级key，则返回多个)
function basefunc.cache:tail()

	local _back = self.visit_queue:back()
	if not _back then
		return nil
	end

	return _back.ts,table.unpack(_back.keys,_back.keys.n)
end

-- 弹出尾部（最 ‘冷’） key
function basefunc.cache:pop()
	local _back = self.visit_queue:back()
	if _back then
		basefunc.to_keys(self.keys_map,nil,table.unpack(_back.keys,_back.keys.n))
		self.visit_queue:pop_back()

		self.size = self.size - 1
	end
end

----------------------------
-- 文件路径相关函数库

-- 得到文件名
function basefunc.path.name(path)
	return string.match(path,"([^/\\]+)$")
end

-- 扩展名
function basefunc.path.extname(path)
	return string.match(path,".+(%.[^%.]+)$")
end

-- 分解扩展名
-- 参数 single_ext ： 单一扩展名，如果为 true，则 多个扩展名只取最后一个
-- 返回： 根名 , 扩展名
function basefunc.path.split_ext(path,single_ext)

	if not path then
		return nil,nil
	end

	if single_ext then
		local _p,_n = string.match(path,"(.*)(%.[^%.]+)$")
		if not _p then
			return path,"" -- 没有匹配到扩展名
		else
			return _p,_n
		end
	else
		return string.match(path,"([^%.]*)(.*)$")
	end

end

-- 文件是否存在
-- 返回值：是否存在(true/false)
function basefunc.path.exists(path)
	local f = io.open(path)
	if f then
		f:close()
		return true
	else
		return false
	end
end

local function isdirsep(c)
	return "/" == c or "\\" == c
end

-- 连接路径：空格会被忽略；只改变中间的分隔符，不会破坏头尾的
function basefunc.path.join(...)
	local args = {... }

	local count = #args

	if count == 1 then return args[1] end
	if count == 0 then return nil end
	if count == 2 then
		if args[1]:len() < 1 then return args[2] end
		if args[2]:len() < 1 then return args[1] end

		if isdirsep(args[1]:sub(-1)) then
			if isdirsep(args[2]:sub(1,1)) then
				return args[1]:sub(1) .. args[2]:sub(2)
			else
				return args[1] .. args[2]
			end
		else
			if isdirsep(args[2]:sub(1,1)) then
				return args[1] .. args[2]
			else
				return args[1] .. "/" .. args[2]
			end
		end
	end

	local ret = args[1]
	for i=2,#args,1 do
		ret = basefunc.path.join(ret,args[i])
	end

	return ret
end

function basefunc.path.read(file)
	local f = io.open(file)
	if f then
		local ret
		if _VERSION == "Lua 5.3" then
			ret = f:read("a")
		else
			ret = f:read("*a")
		end

		f:close()
		return ret
	else
		return nil
	end
end

function basefunc.path.write(filename,data,mode)
	local file ,err = io.open(filename,mode or "w")
	if not file then
		local _err_txt = "file data error:" .. err
		print(_err_txt)
		return false,_err_txt
	end
	file:write(data)
	file:close()

	return true
end

-- 得到带时间的备份文件名
-- 例如： xxx.lua => xxx_20200320_183455_1.lua
-- _index 为 nil 或 0 ，则 不加序号
-- _time 为nil 则取当前时间
-- _fmt 格式化串，默认为 %Y%m%d_%H%M%S
function basefunc.path.back_name(filename,_index,_time,_fmt)
	local _name,_ext = basefunc.path.split_ext(filename,true)

	_fmt = _fmt or "%Y%m%d_%H%M%S"
	if _index and _index > 0 then
		return (_name or "") .. os.date("_" .. _fmt .. "_",_time) .. _index .. (_ext or "")
	else
		return (_name or "") .. os.date("_" .. _fmt,_time) .. (_ext or "")
	end
end

-- 更新文件，旧文件按时间编号备份
function basefunc.path.update(filename,data)

	-- 没有，直接写
	if not basefunc.path.exists(filename) then
		return basefunc.path.write(filename,data)
	end

	-- 计算备份文件名
	local _now = os.time()
	local _bak_name
	for i=0,9999 do -- 依次尝试文件是否存在
		local tmp = basefunc.path.back_name(filename,i,_now,"%Y%m%d")
		if not basefunc.path.exists(tmp) then
			_bak_name = tmp
			break
		end
	end

	if not _bak_name then
		print("connt get backup file name:",filename)
	end

	local ok,err = os.rename(filename,_bak_name)
	if not ok then
		print("backup old error:",filename,err)
	end

	return basefunc.path.write(filename,data)
end

-- 规范化路径： 分隔符统一为 "/" ，转换 .. 和 .
function basefunc.path.normalize(path)
	local s = string.gsub(path,"\\","/")
	local dirs = basefunc.string.split(s, "/")
	if not dirs then
		return path
	end

	local i = #dirs
	while i > 0 do
		if dirs[i] == "" or dirs[i] == "." then
			table.remove(dirs,i)
			i = i - 1
		elseif dirs[i] == ".." then
			if i > 1 then
				table.remove(dirs,i-1)
				table.remove(dirs,i-1)

				i = i - 2

			elseif i == 1 then
				table.remove(dirs,i)
				i = i - 1
			end
		else
			i = i - 1
		end
	end

	return table.concat(dirs,"/")
end

-- 得到文件夹：去掉文件名部分
function basefunc.path.dir(file)
	local s = string.gsub(file,"\\","/")
	s = string.gsub(s,"///","/")
	s = string.gsub(s,"//","/")
	local pos = basefunc.string.rfind(s,"/")
	if pos then
		return string.sub(s,1,pos)
	else
		return ""
	end
end

-- 重新加载 lua 文件
-- 注意： file 必须给完整路径
function basefunc.path.reload_lua(file)
	local _text = basefunc.path.read(file)

	if not _text then
		error(string.format("reload_lua '%s' ,not found!",tostring(file)),2)
	end

	local chunk,err = load(_text,file)
	if not chunk then
		error(string.format("reload_lua '%s' :%s ",tostring(file),tostring(err)),2)
	end

	return chunk() or true
end
basefunc.reload_lua = basefunc.path.reload_lua

-- 递归创建文件夹（需要 lfs 支持）
local lfs
function basefunc.path.mkdirs(dir)

	if basefunc.path.exists(dir) then return true end

	if isdirsep(string.sub(dir,-1)) then
		if not basefunc.path.mkdirs(basefunc.path.dir(string.sub(dir,1,-2))) then return false end
	else
		if not basefunc.path.mkdirs(basefunc.path.dir(dir)) then return false end
	end

	if not lfs then
		lfs = require "lfs"
	end

	if not lfs then return false end

	return lfs.mkdir(dir)
end

----------------------------
-- 字符串相关

-- 字符串分割
-- 来自 http://blog.163.com/chatter@126/blog/static/127665661201451983036767/
function basefunc.string.split(str, sepa)
	if str==nil or str=='' then
		return nil
	end

	sepa = sepa or ","

    local result = {}
    for match in (str..sepa):gmatch("(.-)"..sepa) do
        result[#result+1] = match
    end
    return result
end
local string_split = basefunc.string.split

-- 字符串分割 ，解析为 map
function basefunc.string.split_map(str, sepa,num_key)
	if str==nil or str=='' then
		return nil
	end

	sepa = sepa or ","

    local result = {}
    for match in (str..sepa):gmatch("(.-)"..sepa) do
        if num_key and tonumber(match) then
            result[tonumber(match)] = true
        else
            result[match] = true
        end
    end
    return result
end

--[[
 解析 字符串表示到 参数。
 格式： name1:value1&name2:value2&name3&name4 ...
 说明： 
    1、用 & 分隔为多个部分；
    2、每个部分表示一个变量；
    3、包含 ":" 则有一个具体值，否则为布尔值（存在即表示true）;
--]]
function basefunc.string.parse_param_str(_str)
    if type(_str) ~= "string" then
        return nil
    end
    local _vars = string_split(_str, "&")
    if not _vars then
        return nil
    end

    local _ret = {}
    for _,v in ipairs(_vars) do
        local _pos = string.find(v,":",1,true)
        if _pos then
            _ret[string.sub(v,1,_pos-1)] = string.sub(v,_pos+1)
        else
            _ret[v] = true
        end
    end

    return _ret
end

--[[
	分割 url
	返回：
		{
			proto  : 协议，如 http,https 等。。
			host : 主机
			uri : 路径，包含 起始的 / ,例如： /auth/qq_check_token
		}
--]]
function basefunc.string.split_url(_url)

	local p1 = string.find(_url,"//",1,true)
	if not p1 then
		return {uri=_url} -- 没找到 // ，则认为整个都是 uri
	end

	local ret = {}
	if ":" == string.sub(_url,p1-1,p1-1) then
		ret.proto = string.sub(_url,1,p1-2)
	else
		ret.proto = string.sub(_url,1,p1-1)
	end

	local p2 = string.find(_url,"/",p1+2,true)
	if p2 then
		ret.host = string.sub(_url,p1+2,p2-1)
		ret.uri = string.sub(_url,p2)
	else
		ret.host = string.sub(_url,p1+2)
	end

	return ret
end

--- add by wss
--- 把一个字符串打到一个列表中
function basefunc.string.string_to_vec(str)
	local vec = {}
	if #str == 0 then
		return vec
	end

	local length = 0
	local i = 1
	while true do
		local curByte = string.byte( str , i )
		local byteCount = 1
        if curByte > 239 then
            byteCount = 4  -- 4字节字符
        elseif curByte > 223 then
            byteCount = 3  -- 汉字
        elseif curByte > 128 then
            byteCount = 2  -- 双字节字符
        else
            byteCount = 1  -- 单字节字符
        end
        local char = string.sub(str, i, i + byteCount - 1)
        i = i + byteCount

        vec[#vec + 1] = char
        length = length + 1
        if i > #str then
            break
        end
	end

	return vec
end


function basefunc.string.split_num(str, sepa)
	sepa = sepa or ","
	if str==nil or str=='' then
		return nil
	end

    local result = {}
    for match in (str..sepa):gmatch("(.-)"..sepa) do
        table.insert(result, tonumber(match))
    end
    return result
end

-- 反向查找（简单查找，不支持模式匹配）
-- 找到则起始及终点位置的索引； 否则，返回 nil。
function basefunc.string.rfind(str,find)

	-- 倒序查找
	local rstr = string.reverse(str)
	local rfind = string.reverse(find)

	local r1,r2 = string.find(rstr,rfind,1,true)
	if not r1 then return nil end

	-- 换算成正序
	local len = string.len(str)
	return len - r2 + 1,len - r1 + 1
end
function basefunc.string.ltrim(input)
    return string.gsub(input, "^[ \t\n\r]+", "")
end
function basefunc.string.rtrim(input)
    return string.gsub(input, "[ \t\n\r]+$", "")
end
function basefunc.string.trim(input)
    return string.gsub(input, "^%s*(.-)%s*$", "%1")
end

function basefunc.string.c_str(input)
    if nil == input then
        return nil
    end

    return string.match(tostring(input),"^([^%z]*)")
end
-- 先 trim ，如果 为 "" 则返回 nil
function basefunc.string.trim_nil(input)
	if nil == input then
		return nil
	end

	local tmp = string.gsub(input, "^%s*(.-)%s*$", "%1")
	if "" == tmp then
		return nil
	else
		return tmp
	end
end


--@param {int} len -- 要随机的字符串长度
--@Return {String} rankStr --生成的随机字符串
function basefunc.randomStr(len)
	local rankStr = ""
	local randNum = 0
	for i=1,len,1 do
		if math.random(1,3)==1 then
			randNum=string.char(math.random(0,25)+65)
		elseif math.random(1,3)==2 then
			randNum=string.char(math.random(0,25)+97)
		else
			randNum=math.random(0,9)
		end
		rankStr=rankStr..randNum
	end
	return rankStr
end
----------------------------
-- 物理运动相关

-- 求匀加速 运动 的距离
-- 方程：d = v * t + 0.5 * a * t * t
-- 参数 pos0：可以为 nil
function basefunc.physics.accmove(v0,t,a,pos0)
	return {
		x=(pos0 and pos0.x or 0) + v0.x * t + 0.5 * a.x * t * t,
		y=(pos0 and pos0.y or 0) + v0.y * t + 0.5 * a.y * t * t
	}
end

-- 已知 距离 ，求匀加速 直线 运动的时间
-- 返回：
-- 	nil 	- 无解，或没有合法解
--	t1,t2	- 如果有两个有效解（负数解视为无效），则保证 t1 是两个解中最小的
function basefunc.physics.acctime(v0,a,d)

	-- d 太小
	if lm.abs(d) <= 0.00001 then return 0 end

	-- 匀速运动的情况
	if lm.abs(a) <= 0.00001 then
		if lm.abs(v0) <= 0.00001 then
			return nil -- 初速度 加速度 均为 0 ，无解
		else
			local ret = d/v0
			return ret >= 0 and ret or nil
		end
	end

	local delta = v0 * v0 + 2 * a * d
	if delta < 0 then return nil end
	local sqrt_delta = lm.sqrt(delta)
	local tmp1 = - v0 / a
	local tmp2 = sqrt_delta / a

	-- 丢弃负数解
	local r1 = (tmp1 + tmp2) >=0 and (tmp1 + tmp2) or nil
	local r2 = (tmp1 - tmp2) >=0 and (tmp1 - tmp2) or nil

	if not r1 then return r2 end
	if not r2 then return r1 end

	return lm.min(r1,r2)	-- 都合法，返回最小的
end

-- 特定参考方向上的运算 函数集
basefunc.physics.plus = {direct=1}		-- 正方向 函数集
basefunc.physics.minus = {direct=-1}		-- 负方向 函数集

-- 根据符号得到函数集
function basefunc.physics.funcsFromSign(sign)
	return sign < 0 and basefunc.physics.minus or basefunc.physics.plus
end

-- 前进 : l1 + l2
-- 含义： 在 l1 基础上前进（后退为负）距离 l2 后的新位置
function basefunc.physics.plus.forward(l1,l2)
	return l1+l2
end
function basefunc.physics.minus.forward(l1,l2)
	return l1-l2
end

-- 比较 运算: l1 - l2
-- 含义： 在当前方向上，l1 比 l2 领先的距离（落后为负）
function basefunc.physics.plus.compare(l1,l2)
	return l1 - l2
end
function basefunc.physics.minus.compare(l1,l2)
	return l2 - l1
end

-- 取前面的点
function basefunc.physics.plus.front(l1,l2)
	return l1 > l2 and l1 or l2
end
function basefunc.physics.minus.front(l1,l2)
	return l1 < l2 and l1 or l2
end

-- 取后面的点
function basefunc.physics.plus.back(l1,l2)
	return l1 >= l2 and l2 or l1
end
function basefunc.physics.minus.back(l1,l2)
	return l1 <= l2 and l2 or l1
end

-- 根据位置和宽度，计算 开始点和结束点（可用于计算 rect 的前边缘、后边缘）
function basefunc.physics.plus.startpoint(l,w)
	return l
end
function basefunc.physics.minus.startpoint(l,w)
	return l+w
end
function basefunc.physics.plus.endpoint(l,w)
	return l+w
end
function basefunc.physics.minus.endpoint(l,w)
	return l
end


----------------------------
-- 数学函数库

-- 根据概率 进行选择
-- 返回: 选中的项 , 数组下标
-- 参数：
--		array ：待选择的数组
--		chance ：数组元素中存放的 概率 字段名；如果为 nil ，则机会平均
--		chance_total : 概率总数，默认为 100
function basefunc.math.choose(array,chance,chance_total)

	if not array[1] then return nil,nil end

	-- 没有 chance ，则机会平均
	if not chance then
		return array[random(#array)]
	end

	local sum = 0
	local total = chance_total or 100
	for i,v in ipairs(array) do
		if v[chance] and tonumber(v[chance]) then
			sum = sum + v[chance]
			if random(total) <= sum then
				return v,i
			end
		end
	end

	return array[#array],#array
end

-- 零 坐标
basefunc.zeroPoint = {x=0,y=0 }

-- 零 尺寸
basefunc.zeroSize = {width=0,height=0}

-- 零 矩形
basefunc.zeroRect = {x=0,y=0,width=0,height=0}

-- 拷贝点
function basefunc.math.p(x,y)
    return y and {x=x,y=y} or {x=x.x,y=x.y}
end

-- 点 取负数
function basefunc.math.pminus(x,y)
	return y and {x=-x,y=-y} or {x=-x.x,y=-x.y}
end
function basefunc.math.pminus_(p)
	p.x = -p.x
	p.y = -p.y
	return p
end

function basefunc.math.padd(p1,p2)
	return {x = p1.x + p2.x , y = p1.y + p2.y }
end
function basefunc.math.psub(p1,p2)
	return {x = p1.x - p2.x , y = p1.y - p2.y }
end
function basefunc.math.pzoom(p,m)
	return {x=p.x * m,y=p.y * m}
end

-- 点 自增
function basefunc.math.pinc(p,x,y)

	if y then
		p.x = p.x + x
		p.y = p.y + y
	else
		p.x = p.x + x.x
		p.y = p.y + x.y
	end

	return p
end

-- 点 自减
function basefunc.math.pdec(p,x,y)

	if y then
		p.x = p.x - x
		p.y = p.y - y
	else
		p.x = p.x - x.x
		p.y = p.y - x.y
	end

	return p
end


-- 点 自乘以一个系数
function basefunc.math.pfactor(p,m)
	p.x = p.x * m
	p.y = p.y * m
	return p
end

-- 点到原点距离
function basefunc.math.plength(p)
	return lm.sqrt( p.x * p.x + p.y * p.y )
end

-- 两点距离
function basefunc.math.pdist(p1,p2)
	return basefunc.math.plength(basefunc.math.psub(p1,p2))
end
-- 获取gps距离 参数1：a点纬度 参数2：a点经度 参数3：b点维度 参数4：b点经度
function basefunc.math.get_gps_distance(la1, lo1, la2, lo2)
	local rla1 = lm.rad(la1)
	local rla2 = lm.rad(la2)
	local a = rla1 - rla2
	local b = lm.rad(lo1) - lm.rad(lo2)
	local sa = lm.sin(a / 2)
	local sb = lm.sin(b / 2)
	local s = 2 * 6378137 * lm.asin(lm.sqrt(sa * sa + lm.cos(rla1) * lm.cos(rla2) * sb * sb))
	return lm.floor(s)
end

-- 角度
function basefunc.math.pangle(p)
	if _VERSION == "Lua 5.3" then
		return lm.atan(p.y, p.x)
	else
		return lm.atan2(p.x,p.y)
	end
end

-- 拷贝尺寸
function basefunc.math.size(width,height)
    return height and {width=width,height=height} or {width=width.width,height=width.height}
end

-- 拷贝 rect
function basefunc.math.r(x,y,w,h)
	return y and {x=x,y=y,width=w,height=h} or {x=x.x,y=x.y,width=x.width,height=x.height}
end

-- 移动 rect
function basefunc.math.rmove(r,p)
	return {x=r.x+p.x,y=r.y+p.y,width=r.width,height=r.height}
end

-- rect 自乘以一个系数
function basefunc.math.rfactor(r,m)
	r.x = r.x * m
	r.y = r.y * m
	r.width = r.width * m
	r.height = r.height * m
	return r
end

-- 自膨胀 rect，如果 inf 为 nil，则不变化 rect
function basefunc.math.rinflate(r,inf)

	if inf then
		r.x = r.x-inf
		r.y = r.y-inf
		r.width = r.width + inf + inf
		r.height = r.height + inf + inf
	end

	return r
end


-- 得到矩形的 右上角坐标
function basefunc.math.rtopright(r)
	return {x=r.x + r.width,y=r.y + r.height}
end

-- rect 的中心点
function basefunc.math.rcenter(r)
	return {x=r.x + r.width * 0.5,y=r.y+r.height * 0.5}
end

-- 计算 射线 p1 -> p2 上给定的 百分比位置
function basefunc.math.prayPosByPer(p1,p2,per)
	return {x=p1.x + per * (p2.x-p1.x),y = p1.y + per * (p2.y-p1.y)}
end

-- 根据长度，计算 射线 p1 -> p2 上的点位置
function basefunc.math.prayPos(p1,p2,dist)
	local dist0 = basefunc.math.pdist(p1,p2)
	if dist0 == 0 then
		return {x=p1.x,y=p1.y }
	end
	return basefunc.math.prayPosByPer(p1,p2,dist/dist0)
end

-- 检查点是否在矩形内
function basefunc.math.pinRect(p,rect)
	return p.x >= rect.x and p.x < (rect.x + rect.width) and p.y >= rect.y and p.y < (rect.y + rect.height)
end

-- aabb 碰撞检测
function basefunc.math.pcollide(rect1,rect2)
	-- x 交错
	if rect1.x > rect2.x + rect2.width then return false end
	if rect2.x > rect1.x + rect1.width then return false end

	-- y 交错
	if rect1.y > rect2.y + rect2.height then return false end
	if rect2.y > rect1.y + rect1.height then return false end

	return true
end

-- 四舍五入到整数
function basefunc.math.round(n)
	local v = floor(n)
	return n-v > 0.5 and v + 1 or v
end

-- 在数组中查找 第一个 小于等于 给定值的下标
-- 参数：
--	vec 数组，已按升序排列
--	var 要查找的变量
--	comp 比较函数，可选，小于则返回 true
-- 返回值：
--	如果 var 小于 第一个值，则返回 0
--	如果数组为空，则返回 nil
function basefunc.math.findrange(vec,var,comp)

	if not vec or not vec[1] then
		return nil
	end

	local compfunc = comp and comp or function(v1,v2) return v1 < v2 end

	local i1=1
	local i2=#vec
	while true do
		local i = lm.modf((i1 + i2) * 0.5)
		if compfunc(var,vec[i]) then
			if i == i1 then -- i2 从右向左移动到重合, var 必然小于 i1，且 i1 为第一个
				return 0
			end

			i2 = i
		else
			if i == i1 then	-- i1 无法移动, i1 , i2 紧贴或相同
				if i1 == i2 then 	-- i , i1 ,i2 相等
					return i1
				else				-- i1,i2 紧贴
					if compfunc(vec[i2],var) then
						return i2	-- vec[i2] < var
					else
						return i1	-- var <= vec[i2]
					end
				end
			end

			i1 = i
		end
	end

	assert(false)
	return nil
end

-- 监视 update 的状态
local debug_upm_data = {}
function basefunc.debug.updateMonitor(name,dt,interval,...)
	local data = basefunc.getitem(debug_upm_data,name)

	data.printCd = data.printCd or 0
	data.printCd = data.printCd - dt
	if data.printCd-dt <= 0 then
		data.printCd = interval
		print("updateMonitor:",name,...)
	end

end

--[[
	服务器用
	通用xpcall错误捕获函数,
	打印出發生異常時的堆棧
]]
function basefunc.debug.common_xpcall_handler_type1( errorMessage )
    print("----------------------------------------")
    print("LUA ERROR: " .. tostring(errorMessage) .. "\n")
    print(debug.traceback())
    print("----------------------------------------")
    return errorMessage
end

--[[
	服務器用
	通用xpcall錯誤捕獲函數
	打印堆棧，並且將記錄堆棧詳細信息
]]
function basefunc.debug.common_xpcall_handler_type2( errorMessage ,simpleFilePath, detailFilePath)
	print("----------------------------------------")
    print("LUA ERROR: " .. tostring(errorMessage))
    print(debug.traceback())
    print( string.format( "time is: %s\n", os.date() ) )
    print( "see log file for more detail" )
    print("----------------------------------------")

    if( basefunc.debug.stackdetail ) then
    	basefunc.debug.stackdetail(simpleFilePath, detailFilePath)
    end
    return errorMessage
end

--[[
	服务器用
	将当前堆栈中的所有信息添加写入到指定文件中
	@simpleFilePath 堆栈信息保存文件 默认dreamgame/stack_simple.txt
	@detailFilePath 详细信息保存文件，主要是保存简单文件中的table变量, stack_detail.txt
	@detailDepth table数据类型的记录深度，有一个默认值
]]
function basefunc.debug.stackdetail( simpleFilePath, detailFilePath, detailDepth)
	simpleFilePath = simpleFilePath or "stack_simple.txt"
	detailFilePath = detailFilePath or "stack_detail.txt"
	detailDepth = detailDepth or 7
	assert( type( simpleFilePath ) == "string" )
	assert( type( detailFilePath ) == "string" )
	assert( type( detailDepth ) == "number" )

	--begin for table id
	local chars = {}
	for i = 0, 9 do
	    chars[#chars+1] = tostring( i )
	end
	for i = 97, 97+5 do
	    chars[#chars+1] = string.char( i )
	end
	local function __genTableId()
	    local tb = {}
	    for i = 1, 32 do
	        tb[#tb+1] = chars[random( 1, 16 )]
	    end
	    return table.concat( tb )
	end
	--end for table id

	local function __is_need_log_var( v ) --根据变量的类型决定是否需要记录此变量的信息

	    return true -- 鉴于对lua使用的多样性，所有类型的数据都记录。

	    -- return type(v) ~= "function" and type( v ) ~= "userdata"
	    --     and type( v ) ~= "thread" and type(v) ~= "lightuserdata"
	end
	local function table_to_string( aTable, recMax )

		-- by lyx
		if aTable == nil then return "nil" end

	    recMax = recMax or 3
	    local stringBuffer = {}
	    local function __tab_string( count )
	        local tabl = {}
	        for i = 1, count do
	            table.insert( tabl, "  " )
	        end
	        return table.concat( tabl, "" )
	    end
	    local function __table_to_string( tableNow, recNow )
	        if( recNow > recMax ) then
	            table.insert( stringBuffer, tostring( tableNow ) .. ",\n" )
	            return
	        end
	        table.insert( stringBuffer, "{\n" )
	        for k, v in pairs( tableNow ) do
	            if( __is_need_log_var(v) ) then
	                table.insert( stringBuffer, __tab_string(recNow) .. tostring( k ) .. "=" )
	                if( "table" ~= type(v) ) then
	                    table.insert( stringBuffer, tostring( v ) .. ",\n" )
	                else
	                    __table_to_string( v, recNow + 1 )
	                end
	            end
	        end
	        table.insert( stringBuffer, __tab_string(recNow-1) .. "},\n" )
	    end
	    __table_to_string( aTable, 1 )
	    return table.concat( stringBuffer, "" )
	end


	--实现
	local function __imp()
		local complexVarMap = {} --复杂变量存放处
	    local simpleLogBuffer = {
	        string.format( "time is: %s\n", os.date() )
	    }
	    for level = 3, math.huge do
	        local stackInfo = debug.getinfo( level )
	        if( not stackInfo ) then
	            break
	        end
	        simpleLogBuffer[#simpleLogBuffer+1] = string.format( "stack level:[%d], funcname:[%s], file:[%s], begin at:[%d], at:[%d]\n",
	            level or -100, stackInfo.name or "unknow", stackInfo.source or "unknow",
	                stackInfo.linedefined or -100, stackInfo.currentline or -100)
	        simpleLogBuffer[#simpleLogBuffer+1] = string.format( "there are some local variables:\n" )
	        --local variable 信息
	        for i = 1, math.huge do
	            local vName, vValue = debug.getlocal( level, i )
	            if( nil == vName ) then
	                break
	            end
	            if( __is_need_log_var( vValue ) ) then
	                if( type(vValue) == "table" ) then
	                    local tableId = __genTableId()
	                    complexVarMap[tableId] = vValue
	                    simpleLogBuffer[#simpleLogBuffer+1] = string.format( "name:[%s]\ttableid:[%s]\n", vName, tableId )
	                else
	                    simpleLogBuffer[#simpleLogBuffer+1] = string.format( "name:[%s]\tvalue:[%s]\ttype:[%s]\n",
	                        vName, tostring(vValue), type(vValue))
	                end
	            end
	        end
	        simpleLogBuffer[#simpleLogBuffer+1] = string.format( "there are some upvalue:\n" )
	        --upvalue 信息
	        for i = 1, math.huge do
	            local vName, vValue = debug.getupvalue( stackInfo.func, i )
	            if( nil == vName ) then
	                break
	            end
	            if( __is_need_log_var( vValue ) ) then
	                if( type(vValue) == "table" ) then
	                    local tableId = __genTableId()
	                    complexVarMap[tableId] = vValue
	                    simpleLogBuffer[#simpleLogBuffer+1] = string.format( "name:[%s]\ttableid:[%s]\n", vName, tableId )
	                else
	                    simpleLogBuffer[#simpleLogBuffer+1] = string.format( "name:[%s]\tvalue:[%s]\ttype:[%s]\n",
	                        vName, tostring(vValue), type(vValue))
	                end
	            end
	        end
	        simpleLogBuffer[#simpleLogBuffer+1] = string.format("---end stack level:[%d]\n\n", level)
	    end
	    simpleLogBuffer[#simpleLogBuffer+1] = string.rep( "\n", 5 )
	    --write simple log
	    local sFile, sFileOpenErr = io.open( simpleFilePath, "a" )
	    if( sFile ) then
	        sFile:write( table.concat( simpleLogBuffer ) )
	        sFile:close()
	    else
	        local forPrint = string.format( "__stack_detail__:open log file [%s] faild, beccause [%s]",simpleFilePath, sFileOpenErr )
	        return -- do not need write complex log
	    end

	    --write complex log
	    local dFile, dFileOpenErr = io.open( detailFilePath, "a")
	    if( dFile ) then
	        for k, v in pairs(complexVarMap) do
	            dFile:write( tostring( k ) )
	            dFile:write( " = " )
	            if( type(v) == "table" ) then
	                dFile:write( table_to_string( v, detailDepth ) )
	            end
	            dFile:write( "\n" )
	        end
	        dFile:close()
	    else
	        local forPrint = string.format( "__stack_detail__:open log file [%s] faild, beccause [%s]",detailFilePath, dFileOpenErr )
	        print( forPrint )
	    end
	end -- end imp

	local noError, errorMsg = pcall( __imp )
	if( not noError ) then
		print( string.format( "stackdetail: 发生异常，已经安全退出，检查函数的实现，错误信息：\n%s", errorMsg ) )
	end

end

-- 以实用的默认格式 转换时间戳为字符串
function basefunc.date(_fmt,_time)
	return os.date(_fmt or "%Y-%m-%d %H:%M:%S",_time)
end

-- 计算两个时间之间相差的月份： _t1 - _t2
function basefunc.month_diff(_t1,_t2)
	_t1 = _t1 or os.date("*t")
	_t2 = _t2 or os.date("*t")

	if type(_t1) == "number" then
		_t1 = os.date("*t",_t1)
	end
	if type(_t2) == "number" then
		_t2 = os.date("*t",_t2)
	end

	return (_t1.year - _t2.year) * 12 + (_t1.month - _t2.month)
end

function basefunc.getDateTime(ts)

	local ttb = {}
	_,_,ttb.year,ttb.month,ttb.day,ttb.hour,ttb.min,ttb.sec = 
	    string.find(ts,"^(%d+)-(%d+)-(%d+) (%d+):(%d+):(%d+)$")

	return ttb
end

function basefunc.setDateTime(tiemTable)
	return ""..tiemTable.year .. "-" .. tiemTable.month .. "-" .. tiemTable.day .. " " .. tiemTable.hour .. ":" .. tiemTable.min .. ":" .. tiemTable.sec
end


function basefunc.table.map( t, func )
	local newt = {}
	for k, v in pairs( t ) do
		newt[k] = func( v )
	end
	return newt
end

function basefunc.table.array_find_i( t, ifirst, ilast, predicate )
	for i = ifirst, ilast, 1 do
		if( predicate( t[i] ) ) then
			return i, t[i]
		end
	end
	return nil
end

function basefunc.table.array_find( t, predicate )
	return basefunc.table.array_find_i( t, 1, #t, predicate )
end

function basefunc.table.array_find_all_i( t, ifirst, ilast, predicate )
	local ret = {}
	for i = ifirst, ilast, 1 do
		if( predicate( t[i] ) ) then
			ret[#ret+1] = t[i]
		end
	end
	return ret
end

function basefunc.table.array_find_all( t, predicate )
	return basefunc.table.array_find_all_i( t, 1, #t, predicate )
end
function basefunc.table.insert_repeat( t, value,times )
	while times>0 do
		t[#t+1]=value
		times=times-1
	end
end

-- 根据回调删除数组元素
function basefunc.table.remove_array(t,predicate)
	local i=1
	while i<=#t do
		if predicate(t[i]) then
			table.remove( t,i)
		else
			i=i+1
		end
	end
end


local function _table_unpack(_t,_n,_begin,...)
    if _n >= _begin then
        return _table_unpack(_t,_n-1,_begin,_t[_n],...)
    else
        return ...
    end
end

-- 将 _t 的内容 返回为 _t[_begin+1],_t[_begin+2],.., _t[_t.n]
-- 说明： table.pack 的反操作； 
-- 注意： 不知何故， table.unpack 不是使用 _t.n 而是 #_t
function basefunc.unpack_n(_t,_begin)
    return _table_unpack(_t,_t.n,_begin or 1)
end
local unpack_n = basefunc.unpack_n

function basefunc.nextDay( dateTable )
	local ts = os.time( dateTable )

	local ts_next = ts + oneday_sec
	local day_next = os.date( "*t", ts_next )
	return day_next
end

function basefunc.sepTheDate( dateTable, seperator )
	seperator = seperator or "-"
	local buf = {
		string.format( "%04d", dateTable.year ),
		string.format( "%02d", dateTable.month ),
		string.format( "%02d", dateTable.day ),
	}
	return table.concat( buf, seperator )
end

function basefunc.tohex(data)
	local ret = {}
	for i=1,string.len(data) do
		ret[#ret + 1] = string.format("%02X",data:byte(i))
	end

	return table.concat(ret)
end

-- 转换为时间戳
function basefunc.totime(_str)

    local _, _, y, m, d, _hour, _min, _sec = string.find(_str, "%s*(%d*)[/-]?(%d*)[/-]?(%d*)%s*(%d*):?(%d*):?(%d*)%s*");

    --转化为时间戳
    return os.time({
        year=tonumber(y) or 2021, 
        month = tonumber(m) or 1,
        day = tonumber(d) or 1, 
        hour = tonumber(_hour) or 0, 
        min = tonumber(_min) or 0, 
        sec = tonumber(_sec) or 0,
    });
end


--[[
	传入一个以下格式(常见于http get请求)的字符串，返回相应的键值对表，其中，键值均为字符串
	a=b&c=d&serverId=nmb
	格式的保证由调用者保证，任何非法格式行为不确定
]]
function basefunc.parse_url_params_str( params_str )
	local kvstrs = basefunc.string.split( params_str, "&" )
	local ret = {}
	for _, kvstr in ipairs( kvstrs ) do
		local pair = basefunc.string.split( kvstr, "=" )
		ret[pair[1]] = assert( pair[2] )
	end
	return ret
end


local unescape_uri_map = {
	["%2B"] = "+",
	["%20"] = " ",
	["%2F"] = "/",
	["%3F"] = "?",
	["%25"] = "%",
	["%23"] = "#",
	["%26"] = "&",
	["%3D"] = "=",
}



function basefunc.unescape_uri( uri  )

	-- 参考 https://github.com/gonapps/gonapps-lua-url-decoder
	return string.gsub(uri, "%%(%x%x)", function(hex)
        return string.char(tonumber(hex, 16))
    end)
end


local escape_uri_map = {
	["+"] = "%2B",
	[" "] = "%20",
	["/"] = "%2F",
	["?"] = "%3F",
	["%"] = "%25",
	["#"] = "%23",
	["&"] = "%26",
	["="] = "%3D",
}


function basefunc.escape_uri( uri )

	-- 参考 https://github.com/gonapps/gonapps-lua-url-encoder/blob/master/src/gonapps/url/encoder.lua
	return string.gsub(uri, "[^A-z0-9\\-_.~]", function(char) return string.format("%%%X", string.byte(char)) end)
end


-- print( basefunc.escape_uri( "as+ /?%#fwergrfg&=" ) )


-- print( basefunc.unescape_uri( basefunc.escape_uri( "as+ /?%#fwergrfg&=" ) ) )


--获取当前时间到目标时间的差值 返回值单位：秒  24点等于0
function basefunc.get_diff_target_time(t_hour)
	local time=os.date("*t")
    local wait_time
    if time.hour<t_hour then
        wait_time=((t_hour-time.hour)*60-time.min)*60-time.sec
    elseif time.hour==t_hour and time.min==0 and time.sec==0 then
        wait_time=0
    else
        wait_time=((t_hour-time.hour+24)*60-time.min)*60-time.sec
    end
    return wait_time
end


--两个格林威治时间点是否是同一天 可以设置零点 24点等于0
function basefunc.chk_same_date(_last_time,_cur_time,_point)
	_point = _point or 0

	if _last_time > _cur_time then
		_last_time,_cur_time = _cur_time,_last_time
	end

	--1970/1/2 0:0:0
	local t = os.time({year=1970, month=1, day=2, hour=0, min=0, sec=0})
	_point = t + _point*3600

	local t1 = _last_time - _point
	local t2 = _cur_time - _point

	local d1 = floor(t1/86400)
	local d2 = floor(t2/86400)

	if d2 == d1 then
		return true
	end

	return false
end

-- 1975-09-01 00:00:00 星期一
-- 注意：此时间 可以作为 天、周  的起始时刻
local time_diff_start = os.time({year=1975, month=9, day=1, hour=0, min=0, sec=0})

function basefunc.get_time_diff_start()
    return time_diff_start
end

-- 计算 两个时间的相差星期数： time2 - time1
-- 参数 week_begin ： 一周开始天（小时 0 ~ 6）, 0 表示周一
function basefunc.week_diff(time1,time2,day_begin)

	local _t0 = floor(time_diff_start + 86400 * (day_begin or 0))

	time1 = time1 or _t0

	return floor((time2-_t0)/604800) - floor((time1-_t0)/604800)
end

-- 计算 两个时间的相差天数： time2 - time1
-- 参数 day_begin ： 一天开始时间（小时 0 ~ 23）, 可以是小数
function basefunc.day_diff(time1,time2,day_begin)

	local _t0 = floor(time_diff_start + 3600 * (day_begin or 0))

	time1 = time1 or _t0

	return floor((time2-_t0)/86400) - floor((time1-_t0)/86400)
end

-- 计算 两个时间的相差小时数： time2 - time1
-- 参数 hour_begin ： 小时的开始时间（分 0 ~ 59）
function basefunc.hour_diff(time1,time2,hour_begin)

	local _t0 = floor(time_diff_start + 60 * (hour_begin or 0))

	time1 = time1 or _t0

	return floor((time2-_t0)/3600) - floor((time1-_t0)/3600)
end

-- 计算 两个时间的相差分钟数： time2 - time1
-- 参数 minute_begin ： 分钟的开始时间（秒 0 ~ 59）
function basefunc.minute_diff(time1,time2,minute_begin)

	local _t0 = floor(time_diff_start + (minute_begin or 0))

	time1 = time1 or _t0

	return floor((time2-_t0)/60) - floor((time1-_t0)/60)
end

-- 以按给定的偏移作为 天的 跨越， 得到 +n 天后的 时间; 
-- 注意，+0 天 就是 当天
-- 参数 day_begin ： 一天开始时间（小时 0 ~ 23）
-- 返回 2 个值： 一天的 起始时间, 结束时间
function basefunc.add_day(_now,_day_count,day_begin)

	local _t0 = floor(time_diff_start + 3600 * (day_begin or 0))
	local _cur_day = floor((_now-_t0)/86400)
	
	local _begin = floor(_t0 + (_cur_day + _day_count)*86400)
	return _begin,_begin + 86400
end

--[[判断当前是不是双周
	(base on 1970/1/5 0:0:0 is single week)
	格林威治时间的第一个周一零点
]]
function basefunc.is_double_week(_time)
	_time = _time or os.time()

	--1970/1/5 0:0:0
	local t = os.time({year=1970, month=1, day=5, hour=0, min=0, sec=0}) 

	local dt = _time - t

	local w = math.ceil(dt/(7*24*3600))%2

	if w == 0 then
		return true
	end

	return false
end


-- 获取本周已经过去的时间
function basefunc.get_week_elapse_time()

	local time=os.date("*t")

	local cd = time.wday-1
	if cd < 1 then
		cd = 7
	end

	local ct = ((cd-1)*24*3600 + time.hour*3600 + time.min*60 + time.sec)

	return ct
end

----add by wss
---获取星期几
function basefunc.get_week_day(_time)
	local time = _time or os.time()

	local week_day = os.date("*t" , time).wday

	local week_day = week_day - 1
	if week_day < 1 then
		week_day = 7
	end

	return week_day
end
-- 是否一个有效标识符，例如：设备编号、imei 等
function basefunc.valid_ident(_str,_min_len)
	return type(_str) == "string" and string.len(string.gsub(_str,"[%s%c0%-]+","")) > (_min_len or 5)
end

-- 格式化时间差
-- 参数: _sec 秒； _fmt 格式
-- 返回： n 小时 n 分 n 秒
function basefunc.format_time_diff(_sec,_fmt)
	local _d = {
		H=0,
		M=0,
		S=0,
		G = "", -- 符号，"-" 或空
	}

	if _sec < 0 then
		_sec = -_sec
		_d.G = "-"   -- 负数
	end

	if _sec >= 3600 then
		_d.H = math.floor(_sec/3600)
		_sec = _sec % 3600
	end

	if _sec >= 60 then
		_d.M = math.floor(_sec/60)
		_sec = _sec % 60
	end

	_d.S = math.floor(_sec+0.5)

	if _fmt then
		local ret,_ = string.gsub(_fmt or "%G%H小时%M分钟%S秒","%%([GHMS])",_d)
		return ret
	end

	-- 未指定格式，则按最简洁的格式
	local _ret_str = _d.G
	if _d.H > 0 then
		_ret_str = _ret_str .. _d.H .. "小时"
	end
	if _d.M > 0 then
		_ret_str = _ret_str .. _d.M .. "分钟"
	end
	if _d.S > 0 then
		if _d.M == 0 then
			_ret_str = _ret_str .. "零"
		end

		_ret_str = _ret_str .. _d.S .. "秒"
	end

	return _ret_str
end


local skynet
basefunc.tuoguan_v_tuoguan = "init"

-- 得到玩家的 序号： 只支持正式玩家
function basefunc.player_id_index(_player_id)
	if not basefunc.chk_player_is_real(_player_id) then
		return nil
	end

	return tonumber(string.sub(_player_id,3))
end

--判断玩家是否是真真实玩家
function basefunc.chk_player_is_real(_player_id)

	if basefunc.tuoguan_v_tuoguan == "init" then
		basefunc.tuoguan_v_tuoguan = nil
		skynet = skynet or require "skynet_plus"
		basefunc.tuoguan_v_tuoguan = skynet.getcfg("tuoguan_v_tuoguan")
	end

	if basefunc.tuoguan_v_tuoguan then
		return true
	elseif string.sub(_player_id,1,5) == "robot" then
		return false
	end
	return true
end

--判断玩家是否是真真实玩家(不管 tuoguan_v_tuoguan 配置)
function basefunc.is_real_player(_player_id)
	return string.sub(_player_id,1,5) ~= "robot"
end

--判断玩家是否 测试玩家（比如 压力测试）
function basefunc.is_test_player(_player_id)
	return string.sub(_player_id,1,4) == "test"
end

--得到操作系统的简称： ios ,android,unknown
-- 默认值 _default 不传 认为是 unknown
function basefunc.short_os_name(_os_info,_default)
	if type(_os_info) ~= "string" then
		return _default or "unknown"
	end

	_os_info = string.lower(_os_info)

	if string.find(_os_info,"android",1,true) then
		return "android"
	elseif string.find(_os_info,"ios",1,true) or string.find(_os_info,"iphone",1,true) then
		return "ios"
	else
		return _default or "unknown"
	end
end

--汉字的长度
function basefunc.utf8len(input)
    local len  = string.len(input)
    local left = len
    local cnt  = 0
    local arr  = {0, 0xc0, 0xe0, 0xf0, 0xf8, 0xfc}
    while left ~= 0 do
        local tmp = string.byte(input, -left)
        local i   = #arr
        while arr[i] do
            if tmp >= arr[i] then
                left = left - i
                break
            end
            i = i - 1
        end
        cnt = cnt + 1
    end
    return cnt
end

--汉字的截取
function basefunc.utf8sub(input,len)
    local left = string.len(input)
    local cnt  = 0
    local c = 0
    local arr  = {0, 0xc0, 0xe0, 0xf0, 0xf8, 0xfc}
    while left ~= 0 do
        local tmp = string.byte(input, -left)
        local i   = #arr
        while arr[i] do
            if tmp >= arr[i] then
                left = left - i
                c = c+i
                break
            end
            i = i - 1
        end
        cnt = cnt + 1
        if cnt >= len then
            return string.sub(input,1,c)
        end
    end
    return input
end


--获取一个名字的缩略字符串
function basefunc.short_player_name(name,len)
	len = len or 7
	if basefunc.utf8len(name) > len then
		return basefunc.utf8sub(name,len).."..."
	end
	return name
end

--- 获取两个时间戳是否为同一时间
--[[ time1 时间1，time2 时间2 ，offset_hour 偏移的小时  ]]
function basefunc.is_same_day( time1 , time2 , offset_hour )
    --- 2000年1月1日0点0分0秒
	local oldTime = os.time({year=2000, month=1, day=1, hour=0, min=0, sec=0})
	local oldTime = oldTime + 3600 * (offset_hour or 0)

	local dif_time1 = time1 - oldTime
	local dif_time2 = time2 - oldTime

	local dif_day1 = math.floor(dif_time1 / 86400)
	local dif_day2 = math.floor(dif_time2 / 86400)

	return dif_day1 == dif_day2
end

--- 获取是否为同一月
function basefunc.is_same_month( time1 , time2 )
	local time_date1 = os.date("*t",time1)
	local time_date2 = os.date("*t",time2)

	return time_date1.year == time_date2.year and time_date1.month == time_date2.month

end

---- 判断两个时间是否在一个时间轮次里面，(每多少天为一个轮次) , 以time1的时间为开始时间
function basefunc.is_same_round_time( begin_time , time1 , time2 , _delay_day )
    _delay_day = _delay_day or 1
    --- 开始的时间
	local begin_time = begin_time or 0
	--- 当前时间距离开始时间的时间
	local dif_time = time1 - begin_time
	--- 距离开始时间已经过了多少天
	local dif_day = math.floor( dif_time / 86400 )
	--- 到下一个刷新点还需要的时间
	--local next_refresh_time = (_delay_day - (dif_day % _delay_day))*86400 - dif_time % 86400

	------------- 上次抽奖抽奖的时间距离开始时间已经过去的天数
	local dif_time2 = time2 - begin_time
	local dif_day2 = math.floor( dif_time2 / 86400 )

	local is_same_round = true

	if math.floor(dif_day / _delay_day) ~= math.floor(dif_day2 / _delay_day) then
		is_same_round = false
	end

	return is_same_round
end




-- 获得今日的id
function basefunc.get_today_id(now_time , _start_time)
	local start_time = _start_time or os.time({year=2018, month=1, day=1, hour=0, min=0, sec=0})

	return math.floor( (now_time - start_time) / 86400)
end

---- 获取一天还剩多少时间
function basefunc.get_today_remain_time(_time)
	local date = os.date("*t", _time+86400)
	local next_time = os.time({year=date.year, month=date.month, day=date.day, hour=0, min=0, sec=0})
	return next_time - _time
end

---- 获取一天已经过多少时间
function basefunc.get_today_past_time(_time)
	local remain_time = basefunc.get_today_remain_time(_time)
	return 86400 - remain_time
end

---- 获取到下一天的时间点还需要多久
function basefunc.get_next_day_time_need(now_time , _time_point )
    --- 2000年1月1日0点0分0秒
	local oldTime = os.time({year=2000, month=1, day=1, hour=0, min=0, sec=0})
	local oldTime = oldTime + (_time_point or 0)

	return 86400 - (now_time - oldTime)%86400
end

--- add by wss
--- 获得周的id
function basefunc.get_now_week_id(now_time , _start_time)
    --- 2020-1-6 00:00:00 星期一
	local start_time = _start_time or os.time({year=2020, month=1, day=6, hour=0, min=0, sec=0})

	return math.floor( (now_time - start_time) / (7*86400) )
end

---- 获取当前时间到下一周周几的某个时间点还需要多久 参数： 周几， 具体时间（秒）
function basefunc.get_next_week_time_need( _next_week_day , _refresh_seconds )
	local week_elapse_time = basefunc.get_week_elapse_time()

	--- 每周的刷新时间
	local week_refresh_time = (_next_week_day - 1) * 86400 + _refresh_seconds

	local wait_time = 7 * 86400
	if week_elapse_time < week_refresh_time then
		wait_time = week_refresh_time - week_elapse_time
	else
		wait_time = 7 * 86400 - (week_elapse_time - week_refresh_time)
	end

	return wait_time
end

---- 获取当前时间到下一月的某个时间点还需要多久 参数：具体时间（秒）
function basefunc.get_next_month_time_need( _refresh_seconds )
	_refresh_seconds = _refresh_seconds or 0
	local now_time = os.time()
	local now_date = os.date("*t",now_time)
	local pass_time = basefunc.get_now_month_past_time(now_time)
	local wait_time = 0
	if pass_time >= _refresh_seconds then
		wait_time = basefunc.get_month_day_count(now_date.year,now_date.month) * 86400 - pass_time + _refresh_seconds
	else
		wait_time = _refresh_seconds - pass_time
	end

	return wait_time
end

----- 获取本周已经过去的时间
function basefunc.get_now_week_past_time(_now_time)
	local now_date = os.date("*t",_now_time)

	local real_week_day = now_date.wday - 1
	if real_week_day == 0 then
		real_week_day = 7
	end

	return (real_week_day-1)*86400 + basefunc.get_today_past_time(_now_time)
end

----- 获取本周剩余的时间
function basefunc.get_now_week_remain_time(_now_time)
	return 7*86400-basefunc.get_now_week_past_time(_now_time)
end

--- 获取本月已经过去的时间
function basefunc.get_now_month_past_time(_now_time)
	local now_date = os.date("*t",_now_time)

	local day = now_date.day

	return (day-1)*86400 + basefunc.get_today_past_time(_now_time)

end

function basefunc.get_today_time_by_hour(_hour)
	local cDateCurrectTime = os.date("*t")
	local cDateTodayTime = os.time({year=cDateCurrectTime.year, month=cDateCurrectTime.month, day=cDateCurrectTime.day, hour=_hour,min=0,sec=0})
	return cDateTodayTime
end

function basefunc.get_month_day_count(year,month)

	local t

	if ((year %4 == 0) and (year %100 ~= 0)) or (year %400 == 0) then
		t = {31,29,31,30,31,30,31,31,30,31,30,31}
	else
		t = {31,28,31,30,31,30,31,31,30,31,30,31}
	end

	return t[month]

end


---- 编码开关
function basefunc.encode_kaiguan(game_type , kaiguan)
	local split_name = basefunc.string.split(game_type, "_")

	local mj_kaiguan_map = {
		qing_yi_se = 1,
		da_dui_zi = 2,
		qi_dui = 3,
		long_qi_dui = 4,
		jiang_dui = 5,
		men_qing = 6,
		zhong_zhang = 7,
		jin_gou_diao = 8,
		yao_jiu = 9,
		hai_di_ly = 10,
		hai_di_pao = 11,
		tian_hu = 12,
		di_hu = 13,
		gang_shang_hua = 14,
		gang_shang_pao = 15,
		zimo = 16,
		qiangganghu = 17,
		zimo_jiafan = 18,
		zimo_jiadian = 19,
		da_piao = 20,
		huan_san_zhang = 21,
		zhuan_yu = 22,
	}

	local ddz_kaiguan_map = {

	}


	local kaiguan_code = 0
	if split_name[2] == "mj" then
		for key,value in pairs(kaiguan) do
			if mj_kaiguan_map[key] and value then
				kaiguan_code = kaiguan_code + 2 ^ (mj_kaiguan_map[key] - 1)

			end
		end
	elseif split_name[2] == "ddz" then

	end

	return kaiguan_code
end

--- 倍数编码
function basefunc.encode_multi(game_type , multi)
	local split_name = basefunc.string.split(game_type, "_")

	local mj_multi_map = {
		qing_yi_se = 1,
		da_dui_zi = 2,
		qi_dui = 3,
		long_qi_dui = 4,
		dai_geng = 5,
		jiang_dui = 6,
		men_qing = 7,
		zhong_zhang = 8,
		jin_gou_diao = 9,
		yao_jiu = 10,
		hai_di_ly = 11,
		hai_di_pao = 12,
		tian_hu = 13,
		di_hu = 14,
		gang_shang_hua = 15,
		gang_shang_pao = 16,
		zimo = 17,
		qiangganghu = 18,
	}

	local multi_code = {}
	if split_name[2] == "mj" then
		for multi_name,multi_index in pairs(mj_multi_map) do
			if multi[multi_name] then
				multi_code[ multi_index ] = string.char(multi[multi_name])
			else
				multi_code[ multi_index ] = string.char(0)
			end
		end

	elseif split_name[2] == "ddz" then

	end



	return table.concat(multi_code)

end

-- 拷贝 有效的 财富类型：  asset_type 不为空
-- 参数 _assets :  数组 {asset_type=,value=}
function basefunc.copy_asset_type(_assets)

    if type(_assets) ~= "table" then
        return nil
    end

    local _ret = {}
    for _,v in ipairs(_assets) do
        if v.asset_type then
            _ret[#_ret+1] = {
                asset_type = v.asset_type,
                value = v.value,
            }
        end
    end

    return _ret
end

function basefunc.trans_asset_to_jingbi( asset_type , value )
	if asset_type and PLAYER_ASSET_TRANS_JINGBI[asset_type] then
		return PLAYER_ASSET_TRANS_JINGBI[asset_type] * value

	end
	return 0
end

function basefunc.trans_jingbi_to_asset( jing_bi_value , asset_type )
	if asset_type and PLAYER_ASSET_TRANS_JINGBI[asset_type] then
		return math.floor(jing_bi_value / PLAYER_ASSET_TRANS_JINGBI[asset_type] )

	end
	return 0
end

-- 获取折扣的资产
function basefunc.get_discount_asset(_asset_type)

	if type(_asset_type)=="string" then
		if string.len(_asset_type)>9 and string.sub(_asset_type,1,9) == "discount_" then
			return string.sub(_asset_type,10,-1)
		end
	end

	return nil
end


-- 判断是否 是物品道具或者资产等
function basefunc.is_asset(_asset_type)

	if PLAYER_ASSET_TYPES_SET[_asset_type] then
		return true
	end

	if type(_asset_type)=="string" then
		if string.len(_asset_type)>5 and string.sub(_asset_type,1,5) == "prop_" then
			return true
		end
		if string.len(_asset_type)>11 and string.sub(_asset_type,1,11) == "expression_" then
			return true
		end
		if string.len(_asset_type)>7 and string.sub(_asset_type,1,7) == "phrase_" then
			return true
		end
		if string.len(_asset_type)>11 and string.sub(_asset_type,1,11) == "head_frame_" then
			return true
		end
	end

	return false
end


-- 判断是否 是装扮道具
function basefunc.is_dress_asset(_asset_type)

	if type(_asset_type)=="string" then
		if string.len(_asset_type)>11 and string.sub(_asset_type,1,11) == "expression_" then
			return true
		end
		if string.len(_asset_type)>7 and string.sub(_asset_type,1,7) == "phrase_" then
			return true
		end
		-- if string.len(_asset_type)>11 and string.sub(_asset_type,1,11) == "head_frame_" then
		-- 	return true
		-- end
	end

	return false
end

-- 判断是否是某种类型的物品
function basefunc.judge_asset_type(_asset_type,_judge_type)

	if type(_asset_type)=="string" and type(_asset_type)=="string" then
		if string.len(_asset_type)>string.len(_judge_type) and string.sub(_asset_type,1,string.len(_judge_type)) == _judge_type then
			return true
		end
	end

	return false
end

-- 判断是否 是物品有特有属性(独立不可折叠)
function basefunc.is_object_asset(_asset_type)

	if type(_asset_type)=="string" then
		if string.len(_asset_type)>4 and string.sub(_asset_type,1,4) == "obj_" then
			return true
		end
	end

	return false
end


-- 解析装扮道具
function basefunc.parse_dress_asset(_asset_type)

	if type(_asset_type)=="string" then
		local _,_,_type,_id = string.find(_asset_type,"(.*)_(%d+)")
		return _type,tonumber(_id)
	end

end

--- 比较两个值是否相同
function basefunc.compare_vaule_same( value1 , value2 )
	local type1 = type(value1)
	local type2 = type(value2)

	if type1 ~= type2 then
		return false
	end

	if type1 == "table" then
		for key,value in pairs(value1) do
			if value2[key] == nil then
				return false
			end
			local is_same = basefunc.compare_vaule_same( value , value2[key] )
			if not is_same then
				return false
			end
		end

		local t_num1 = basefunc.key_count(value1)
		local t_num2 = basefunc.key_count(value2)
		if t_num1 ~= t_num2 then
			return false
		end

	else
		return value1 == value2
	end

	return true
end

--- 比较值
function basefunc.compare_value( value1 , value2 , judge_type )
	if type(value2) ~= "table" then
		if judge_type == NOR_CONDITION_TYPE.EQUAL then
			return value1 == value2
		elseif judge_type == NOR_CONDITION_TYPE.GREATER then
			return value1 >= value2
		elseif judge_type == NOR_CONDITION_TYPE.LESS then
			return value1 <= value2
		elseif judge_type == NOR_CONDITION_TYPE.NOT_EQUAL then
			return value1 ~= value2
		end

	else
 		local e_judge_type = {
 			[NOR_CONDITION_TYPE.EQUAL] = "or",
 			[NOR_CONDITION_TYPE.GREATER] = "or",
 			[NOR_CONDITION_TYPE.LESS] = "or",
 			[NOR_CONDITION_TYPE.NOT_EQUAL] = "and",
 		}

		local cond_num = 0
		for key,value in ipairs(value2) do
			if basefunc.compare_value( value1 , value , judge_type ) then
				cond_num = cond_num + 1
			end
		end

		local is_cond = false
		if not e_judge_type[judge_type] or e_judge_type[judge_type] == "and" then
			if cond_num == #value2 then
				is_cond = true
			end
		elseif e_judge_type[judge_type] == "or" then
			if cond_num > 0 then
				is_cond = true
			end
		end

		if is_cond then
			return true
		else
			return false
		end
	end


	return false
end


--[[
    比较集合（map）
--]]
function basefunc.compare_map( map1 , map2 , judge_type )

    -- 成立条件： 二者有交集
    if judge_type == NOR_CONDITION_TYPE.EQUAL then
        for k,_ in pairs(map1) do
            if map2[k] then
                return true
            end
        end

        return false
    end

    -- 成立条件： 二者没有交集,和 NOR_CONDITION_TYPE.EQUAL 相反
    if judge_type == NOR_CONDITION_TYPE.NOT_EQUAL then
        return not basefunc.compare_map( map1 ,map2, NOR_CONDITION_TYPE.EQUAL )
    end

    -- 成立条件： map1 是 map2 的超集（map2 是 map1 的子集）
    if judge_type == NOR_CONDITION_TYPE.GREATER then
        for k,_ in pairs(map2) do
            if not map1[k] then
                return false
            end
        end

        return true
    end

    -- 成立条件： 和 NOR_CONDITION_TYPE.GREATER 对称
    if judge_type == NOR_CONDITION_TYPE.LESS then
        return basefunc.compare_map( map2 ,map1, NOR_CONDITION_TYPE.GREATER )
    end

	-- 成立条件： 完全相等
	if judge_type == NOR_CONDITION_TYPE.SUPER_EQUAL then
        for k,_ in pairs(map1) do
            if not map2[k] then
                return false
            end
        end
        for k,_ in pairs(map2) do
            if not map1[k] then
                return false
            end
        end

		return true
	end
end


--[[
    比较集合（vec）
--]]
function basefunc.compare_vec( vec1 , vec2 , judge_type )
    return basefunc.compare_map( basefunc.list_to_map(vec1) ,basefunc.list_to_map(vec2), judge_type )
end

function basefunc.get_time_by_date(r)
	if not r then
		return 0
	end

	local ttb = {}
	_,_,ttb.year,ttb.month,ttb.day,ttb.hour,ttb.min,ttb.sec = 
	    string.find(r,"^(%d+)-(%d+)-(%d+) (%d+):(%d+):(%d+)$")

    return os.time(ttb)
end

-- 用于任务奖励状态 编解码的 元表
basefunc.task_award_status_meta = basefunc.task_award_status_meta or {}
function basefunc.task_award_status_meta.__index(_t,_k)

    -- data 为 _t 表中的数据容器（放在容器中，避免 每个成员都需要用 rawget 访问）
    local _d = rawget(_t,"data")

    if not _d or not _d.status then
        return false
    end

    if type(_k) ~= "number" then
        return rawget(_t,_k)
    end
    if _k < 1 then
        return false
    end

    if type(_d.status) == "string" then
        return char_status_lib.get_char_status(_d.status,_k)
    else
        return char_status_lib.get_table_char_status(_d.status,_k)
    end
end
function basefunc.task_award_status_meta.__newindex(_t,_k,_v)

    -- data 为 _t 表中的数据容器（放在容器中，避免 每个成员都需要用 rawget 访问）
    local _d = rawget(_t,"data")

    if not _d or not _d.status then
        return
    end

    if type(_k) ~= "number" then
        rawset(_t,_k,_v)
        return
    end
    if _k < 1 then
        return
    end

    local _old
    if type(_d.status) == "string" then
        _old = char_status_lib.get_char_status(_d.status,_k)
    else
        _old = char_status_lib.get_table_char_status(_d.status,_k)
    end

    _v = _v and true or false
    if _old == _v then
        return
    end

    -- 每设置一次值，计数器 增加 1 
    _d.set_count = (_d.set_count or 0) + 1 

    -- 解析为表结构
    if type(_d.status) == "string" then  
        _d.status = char_status_lib.parse_char_status(_d.status)
    end
    _d.status = char_status_lib.set_table_char_status(_d.status,_k,_v)
    
    if _d.set_count >= 100 then
        _d.status = char_status_lib.zip_table_char_status(_d.status)
        _d.set_count = 0
    end
end

--- 解码任务的奖励领取状态
function basefunc.decode_task_award_status(status_num)

  	if type(status_num) == "number" then
        local vec = {}

	 	local chu = status_num
		local index = 0
		while true do
	    	index = index + 1
	    	local yu = chu % 2
	    	chu = math.floor(chu / 2)

	    	vec[#vec + 1] = yu == 1

	    	if chu <= 0 then
	      		break
	    	end
	  	end

        return vec
	else
        status_num = status_num or ""
        return setmetatable({data={status=status_num}},basefunc.task_award_status_meta)
	end
end
function basefunc.encode_task_award_status(status_vec , _tar_type , _is_compress)
	local tar_type = _tar_type or "number"

  	local num = 0

  	if tar_type ~= "number" and tar_type ~= "string" then
  		error("encode_task_award_status tar_type not string and not number")
  	end

  	if tar_type == "number" then
	  	for key,status in pairs(status_vec) do
	  		if status then
			    num = num + 2 ^ (key-1)
			end
	  	end
	elseif tar_type == "string" then
        local _meta = getmetatable(status_vec)
        if _meta then  -- 有 meta 表，则是 新方式编解码的 状态（char_status_lib）
            local _d = rawget(status_vec,"data")
            if _d and _d.status then
                if type(_d.status) == "string" then
                    num = _d.status
                else
                    num = char_status_lib.table_status_tostring(_d.status,true)
                end
            else
                num = ""
            end
        else
            ---- 如果要压缩，走新的
            if _is_compress then
                local tar_str = basefunc.encode_task_award_status_compress(status_vec , _tar_type)
                --- 编码成字符串之后，在前面加一个 +
                tar_str = "+" .. tar_str
                return tar_str
            end


            local max_num = 0
            ---- 找到最大的key
            for key,value in pairs(status_vec) do
                if key > max_num then
                    max_num = key
                end
            end
            ---- 中间没得值的key，用 0 填充
            for i = 1,max_num do
                status_vec[i] = status_vec[i] and 1 or 0
            end

            num = table.concat( status_vec , "" )
        end
	end

  	return num
end

--- 解码任务的奖励领取状态
function basefunc.decode_task_award_status_old(status_num)
    local vec = {}

    if type(status_num) == "number" then

       local chu = status_num
      local index = 0
      while true do
          index = index + 1
          local yu = chu % 2
          chu = math.floor(chu / 2)

          vec[#vec + 1] = yu == 1

          if chu <= 0 then
                break
          end
        end

  elseif type(status_num) == "string" then
      ----- 判断第一个字符是否是压缩的标志，如果是，用压缩的算法
      local is_find = string.find( status_num , "+" )
      if is_find then
          local tar_status_num = string.sub(status_num , 2, -1)

          return basefunc.decode_task_award_status_compress(tar_status_num)
      end

      vec = basefunc.string.string_to_vec(status_num)

      ---
      for key,value in pairs(vec) do
          vec[key] = value == "1"
      end

  end

    return vec
end


--[[
	参数：
	status_vec : 状态的vec ;
	_tar_type : 打成的类型（number,string）;
	_is_compress : 是否压缩
--]]
function basefunc.encode_task_award_status_old(status_vec , _tar_type , _is_compress)
	local tar_type = _tar_type or "number"

  	local num = 0

  	if tar_type ~= "number" and tar_type ~= "string" then
  		error("encode_task_award_status tar_type not string and not number")
  	end

  	if tar_type == "number" then
	  	for key,status in pairs(status_vec) do
	  		if status then
			    num = num + 2 ^ (key-1)
			end
	  	end
	elseif tar_type == "string" then
		---- 如果要压缩，走新的
		if _is_compress then
			local tar_str = basefunc.encode_task_award_status_compress(status_vec , _tar_type)
			--- 编码成字符串之后，在前面加一个 +
			tar_str = "+" .. tar_str
			return tar_str
		end


		local max_num = 0
		---- 找到最大的key
		for key,value in pairs(status_vec) do
			if key > max_num then
				max_num = key
			end
		end
		---- 中间没得值的key，用 0 填充
		for i = 1,max_num do
			status_vec[i] = status_vec[i] and 1 or 0
		end

		num = table.concat( status_vec , "" )
	end

  	return num
end

---------------------------------- add by wss
--- 解码任务的奖励领取状态(压缩版)
function basefunc.decode_task_award_status_compress(status_num)
  	local vec = {}

  	if type(status_num) == "number" then

	 	local chu = status_num
		local index = 0
		while true do
	    	index = index + 1
	    	local yu = chu % 2
	    	chu = math.floor(chu / 2)

	    	vec[#vec + 1] = yu == 1

	    	if chu <= 0 then
	      		break
	    	end
	  	end

	elseif type(status_num) == "string" then

		local new_tt = string.gsub( status_num , "%[%d+%]%d" , function( s )
			--print( "xxx------s:" , s )

			local num = string.sub( s , 2 , -3 )
			--print( "xxx------num:" ,num )

			local value = string.sub( s , -1 , -1 )
			--print( "xxx------value:" ,value )

			local rep = ""

			for i = 1, tonumber(num) do
				rep = rep .. value
			end

			return rep
		end)

		vec = basefunc.string.string_to_vec(new_tt)

		---
		for key,value in pairs(vec) do
			vec[key] = value == "1"
		end

	end

  	return vec
end

-----编码任务的领奖状态(压缩版)
function basefunc.encode_task_award_status_compress(status_vec , _tar_type)
	local tar_type = _tar_type or "number"

  	local num = 0

  	if tar_type ~= "number" and tar_type ~= "string" then
  		error("encode_task_award_status tar_type not string and not number")
  	end

  	if tar_type == "number" then
	  	for key,status in pairs(status_vec) do
	  		if status then
			    num = num + 2 ^ (key-1)
			end
	  	end
	elseif tar_type == "string" then
		local max_num = 0
		---- 找到最大的key
		for key,value in pairs(status_vec) do
			if key > max_num then
				max_num = key
			end
		end

		---- 有几个连续的相同的项，就开始压缩
		local same_limit = 5

		---- 中间没得值的key，用 0 填充
		for i = 1,max_num do
			status_vec[i] = status_vec[i] and 1 or 0
		end

		num = ""

		local end_str_vec = {}

		local last_same_index = 1
		local last_same_value = nil
		for i = 1 , max_num do
			if not last_same_value then
				last_same_value = status_vec[i]
				last_same_index = i
			end

			if status_vec[i] ~= last_same_value then
				local same_num = i - last_same_index

				if same_num >= same_limit then

					end_str_vec[#end_str_vec + 1] = "[" .. same_num .. "]" .. last_same_value

					--num = num .. "[" .. same_num .. "]" .. last_same_value
				else
					--num = num .. table.concat( status_vec , "" , last_same_index , i-1 )

					end_str_vec[#end_str_vec + 1] = table.concat( status_vec , "" , last_same_index , i-1 )
				end

				last_same_index = i
				last_same_value = status_vec[i]
			end

			---- 到最后，最后一个位置需要处理
			if i == max_num then
				local same_num = i - last_same_index + 1

				if same_num >= same_limit then
					--num = num .. "[" .. same_num .. "]" .. last_same_value
					end_str_vec[#end_str_vec + 1] = "[" .. same_num .. "]" .. last_same_value
				else
					--num = num .. table.concat( status_vec , "" , last_same_index , i )
					end_str_vec[#end_str_vec + 1] = table.concat( status_vec , "" , last_same_index , i )
				end
			end

		end


		num = table.concat( end_str_vec , "" )
	end

  	return num
end

-----------------------------------bit opt---------------------

--[[
	暂时只能处理 8 bit
]]

function basefunc.bit_or(a,b)
    local p,c=1,0
    while a+b>0 do
        local ra,rb=a%2,b%2
        if ra+rb>0 then c=c+p end
        a,b,p=(a-ra)/2,(b-rb)/2,p*2
    end
    return c
end

function basefunc.bit_xor(a,b)
    local p,c=1,0
    while a+b>0 do
        local ra,rb=a%2,b%2
        if ra+rb==1 then c=c+p end
        a,b,p=(a-ra)/2,(b-rb)/2,p*2
    end
    return c
end

function basefunc.bit_not(n)
    local p,c=1,0
    while n>0 do
        local r=n%2
        if r<1 then c=c+p end
        n,p=(n-r)/2,p*2
    end
    return c
end

function basefunc.bit_and(a,b)
    local p,c=1,0
    while a>0 and b>0 do
        local ra,rb=a%2,b%2
        if ra+rb>1 then c=c+p end
        a,b,p=(a-ra)/2,(b-rb)/2,p*2
    end
    return c
end


--[[
	取 正整数 的二进制位置上的值
]]
function basefunc.bit_get_place_value(_number,_n)
	local m = 2^(_n-1)
	if basefunc.bit_and(_number,m) > 0 then
		return 1
	end
	return 0
end

--[[
	设置 正整数 的二进制位置上的值
]]
function basefunc.bit_set_place_value(_number,_n,_v)

    local m = 2^(_n-1)

    if _v == 0 then

        m = bit_xor(255,m)
        return basefunc.bit_and(_number,m)

    else

        return basefunc.bit_or(_number,m)

    end

end

-- 显示简短金币数
function basefunc.num_to_cash_str(num, wan_digit, yi_digit)
	wan_digit = (not wan_digit or wan_digit > 2) and 2 or wan_digit
	yi_digit = (not yi_digit or yi_digit > 2) and 2 or yi_digit

    if num == nil then return "0" end
    num = tonumber(num)
    if num < 0 then
        num = -1 * num
    end
    if num < 10000 then
        return "" .. num
    elseif num >= 10000 and num < 100000000 then
        local n = math.floor(num / 10000)
        local n1 = math.floor((num%10000) / 1000)
        local n2 = math.floor((num%1000) / 100)
        if n2 > 0 and wan_digit == 2 then
            num = n .. "." .. n1 .. n2
        else
            if n1 > 0 and wan_digit == 1 then
                num = n .. "." .. n1
            else
                num = n
            end
        end
        return string.format("%s万", num)
    else
        local n = math.floor(num / 100000000)
        local n1 = math.floor((num%100000000) / 10000000)
        local n2 = math.floor((num%10000000) / 1000000)
        if n2 > 0 and yi_digit == 2 then
            num = n .. "." .. n1 .. n2
        else
            if n1 > 0 and yi_digit == 1 then
                num = n .. "." .. n1
            else
                num = n
            end
        end
        return string.format("%s亿", num)
    end
end

function basefunc.exe_lua(_text,_name)

	if not _text or "" == _text then
		error("exe_lua error:_text is empty!",2)
	end

	_name = _name or "code:" .. string.gsub(string.sub(_text,1,50),"[\r\n]"," ")

	local chunk,err = load(_text,_name)
	if not chunk then
		error(string.format("exe_lua %s error:%s ",_name,tostring(err)),2)
	end

	return chunk() or true

end

-- 生成 md5 签名， 参数依次相加
function basefunc.md5(...)

	local _d = table.pack(...)

	for i=1,_d.n do
		if _d[i] then
			_d[i] = tostring(_d[i])
		else
			_d[i] = ""
		end
	end

	local _s = table.concat(_d)
	if "" == _s then
		return ""
	end

	return md5.sumhexa(_s)
end

-- 检查 md5 签名（忽略大小写）
function basefunc.check_key_code(_key_code,...)
	return string.upper(_key_code) == basefunc.md5(...)
end



-----  add by wss
--[[
	算组合 的 个数
	a 里面选 b 个 来组合 (较大的数好像有问题...)
--]]
function basefunc.combination( a , b )
	if b > a then
		return 0
	end
	if a == b then
		return 1
	end

	local fenzi = 1
	for i = a-b+1 , a do
		fenzi = fenzi * i
	end

	local fenmu = 1
	for i=1,b do
		fenmu = fenmu * i
	end

	return math.floor( fenzi / fenmu )

end



---- 处理名字
function basefunc.deal_hide_player_name(_player_name)
	if not _player_name then
		return ""
	end
	local player_name = _player_name
	local player_name_vec = basefunc.string.string_to_vec(player_name)
	if player_name_vec and type(player_name_vec) == "table" and next(player_name_vec) then
		if #player_name_vec > 3 then
			player_name = player_name_vec[1] .. "**" .. player_name_vec[#player_name_vec]
		elseif #player_name_vec == 3 then
			player_name = player_name_vec[1] .. "*" .. player_name_vec[#player_name_vec]
		elseif #player_name_vec == 2 then
			player_name = player_name_vec[1] .. "*"
		elseif #player_name_vec == 1 then
			player_name = tostring( player_name_vec[1] )
		end
	end
	return player_name
end

------- 获取一个表按权重随机选的一个数据
function basefunc.get_random_data_by_weight( _data_vec , _weight_key )
	if type(_data_vec) ~= "table" then
		return nil
	end
	local total_power = 0
	for key,data in pairs(_data_vec) do
		total_power = total_power + data[ _weight_key ]
	end
	if total_power <= 0 then
		return nil
	end
	local rand = math.random(total_power)
	local now_rand = 0
	for key,data in pairs(_data_vec) do
		if rand <= now_rand + data[ _weight_key ] then
			return data,key
		end
		now_rand = now_rand + data[ _weight_key ]
	end
	return nil
end

-- 根据客户端发来的 os 字符串，判断 ios 还是 android ， 不能识别的返回源串
function basefunc.get_os_type(_os_text)

	if type(_os_text) ~= "string" then
		return _os_text
	end

	if string.find(_os_text,"iPhone",1,true) or
		string.find(_os_text,"iOS",1,true) then
		return "ios"
	elseif string.find(_os_text,"Android",1,true) then
		return "android"
	else
		return _os_text
	end
end

-- 编码 json 数组
function basefunc.jsonEncodeArray(_array)
	local strs = {}
	for _,v in ipairs(_array) do
		strs[#strs + 1] = cjson.encode(v)
	end

	return "[" .. table.concat(strs,",") .. "]"
end

-- 编码 json map
function basefunc.jsonEncodeMap(_map)
	local strs = {}
	for k,v in pairs(_map) do
		strs[#strs + 1] = string.format([["%s":%s]],tostring(k),cjson.encode(v))
	end

	return "{" .. table.concat(strs,",") .. "}"
end

-- 返回 数据 或 nil,err
function basefunc.decode_json(_json)
    if "" == _json then
        return nil
    end
    if type(_json) ~= "string" then
        return nil
    end
    
	local ok, data = xpcall(cjson.decode,basefunc.error_handle,_json)
	if ok then
		return data
	else
		return nil,data
	end
end

-- 不用编码的字符
local _cannt_encode_char = {}
for c=string.byte("a"),string.byte("z") do
	_cannt_encode_char[string.char(c)] = true
end
for c=string.byte("A"),string.byte("Z") do
	_cannt_encode_char[string.char(c)] = true
end
for c=string.byte("0"),string.byte("9") do
	_cannt_encode_char[string.char(c)] = true
end
_cannt_encode_char["-"] = true
_cannt_encode_char["_"] = true
_cannt_encode_char["."] = true

function basefunc.url_encode(str)

	if type(str) ~= "string" then
		return str
	end

	if "" == str then
		return str
	end

	local chars = {}
	for i=1,string.len(str) do
		local c = string.sub(str,i,i)
		if c == " " then
			chars[i] = "+"
		elseif _cannt_encode_char[c] then
			chars[i] = c
		else
			chars[i] = string.format("%%%02X",string.byte(c))
		end
	end

	return table.concat(chars)
end


local function url_decode_func(c)
	return string.char(tonumber(c, 16))
end

function basefunc.url_decode(str)
	if type(str) ~= "string" then
		return str
	end
	local str = str:gsub('+', ' ')
	return str:gsub("%%(..)", url_decode_func)
end

function basefunc.url_decode_data(_data)
	if type(_data) == "table" then
		for k,v in pairs(_data) do
			_data[k] = basefunc.url_decode_data(v)
		end

		return _data
	else
		return basefunc.url_decode(_data)
	end
end

function basefunc.parse_post_data(_data)

	local ok,_ddata = xpcall(cjson.decode,basefunc.error_handle,_data)
	if not ok then
	  return nil,_ddata
	end

	return basefunc.url_decode_data(_ddata)
end





function basefunc.clear_table(_table)
	if _table and type(_table) == "table" then
		for key,data in pairs(_table) do
			_table[key] = nil
		end
	end
end

-- 返回支持 热更新的函数。即：让函数支持热更新
-- 参数 ... ： _obj 中的多级子键，用于定位的函数
function basefunc.hotfunc(_obj,...)
    local _params = table.pack(...)
	return function(...) 
        return from_keys(_obj,unpack_n(_params))(...)
	end
end

-- 比较布尔值是否相同
function basefunc.cmpbool(_v1,_v2)
	return (_v1 and _v2) or (not _v1 and not _v2)
end

function basefunc.list_to_map(_list)
	local map = {}

	if _list and type(_list) == "table" then
		for key,data in pairs(_list) do
			map[data] = true
		end
	end

	return map
end

function basefunc.map_to_list(_map , _is_key)
	local list = {}

	if _map and type(_map) == "table" then
		for key,data in pairs(_map) do
			if _is_key then
				list[#list + 1] = key
			else
				list[#list + 1] = data
			end
		end
	end

	return list
end

function basefunc.timefmt(_time)
	return os.date("%Y-%m-%d %H:%M:%S",_time)
end

basefunc.priority_queue = basefunc.class()

-- Description:优先队列，自动维护优先级最高的元素在队首, 时间复杂度 O(nlgn), 空间复杂度O(n)
-- Author: yishene
function basefunc.priority_queue:ctor(func)
    self.cmp_func = func or self.cmp_func
    self.heap = {}
    self.length = 0
    -- return self
end

-- 返回优先队列的大小
function basefunc.priority_queue:size()
    return self.length
end

-- 优先队列是否为空，空着返回true
function basefunc.priority_queue:empty()
    return self.length == 0
end

-- 返回优先队列队顶元素
function basefunc.priority_queue:top()
    return self.heap[1]
end

-- 优先队列默认支持number比较函数
function basefunc.priority_queue.cmp_func(a, b)
    if type(a) == type(b) and a >= b then
        return true
    end
    return false
end

-- 交换函数, 参数值为堆的下标
function basefunc.priority_queue:swap(a,b)
    local tmp = self.heap[b]
    self.heap[b] = self.heap[a]
    self.heap[a] = tmp
end

-- 插入队尾
function basefunc.priority_queue:push(x)
    self.length = self.length + 1
    self.heap[self.length] = x

    local pos = self.length
    while(pos > 1) do
    	---- 刚插入一个 ，则一半一半的找是否满足排序规则，如果满足则交换 ， 这个可以保证第一个永远是 满足排序规则的
        local father = math.floor(pos / 2)
        if self.cmp_func(self.heap[pos], self.heap[father]) then
            self:swap(pos, father)
        else
            break
        end
        pos = father
    end
end

-- 弹出队首
function basefunc.priority_queue:pop()
    self:swap(1, self.length)
    self.length = self.length - 1

    local pos = 1
    while(pos * 2 <= self.length) do
        local lson = pos * 2
        local rson = pos * 2 + 1
        local priority_son
        if rson <= self.length and self.cmp_func(self.heap[rson], self.heap[lson]) then
            priority_son = rson
        else
            priority_son = lson
        end
        if self.cmp_func(self.heap[priority_son], self.heap[pos]) then
            self:swap(pos, priority_son)
            pos = priority_son
        else
            break
        end
    end
end

local function expr_print(...)
	print(...)
end

-- 默认环境，包含基础函数
local load_expr_default_env = {
	rawset=rawset,
	setmetatable=setmetatable,
	getmetatable=getmetatable,
	STR=STR,
	print=expr_print,
	error=error,
	math=math,
	string=string,
	tostring=tostring,
	tonumber=tonumber,
}
local load_expr_default_env_meta = {
	__newindex=function() 
		error('can not change variant!') 
	end	
}
setmetatable(load_expr_default_env,load_expr_default_env_meta)

-- 载入 表达式
-- 返回： 一个函数(代码块)  或 nil, 错误信息
-- 返回函数 调用方式：  func(_env) , _env 为执行代码的环境 ， 可以在代码块中直接使用
function basefunc.load_expr(_expr,_name)

	if type(_expr) ~= "string" then
		return nil
	end

	if "string" ~= type(_name) then
		_name = string.sub(_expr,1,15)
		if string.len(_expr) > 15 then
			_name = _name .. "..."
		end
	end


	return load([[
		setmetatable(_ENV,{
			__index=...,
			__newindex=function()
				error('can not change variant!')
			end})

		return ]] .. _expr,_name,
		"t",
		load_expr_default_env)
end

----- add by wss 获得开奖倍数
function basefunc.get_discount_rate( _rate_sort_list , start_rate , discount , max_once_rate ) 
	local select_rate = start_rate
	--- 目标倍数
	local target_rate = start_rate * discount

	if max_once_rate then
		target_rate = math.min( max_once_rate , target_rate ) -- max_once_rate > target_rate and target_rate or max_once_rate
	end

	---- 只从 大往小找
	for i = #_rate_sort_list , 1 , -1 do
		if _rate_sort_list[i] <= target_rate then
			select_rate = _rate_sort_list[i]
			break
		end
	end
	
	--- 最后防一下， 如果选择的比目标大，则用开始的倍数
	if select_rate > target_rate then
		select_rate = start_rate
	end

	--print(string.format("xx------get_discount_rate: start_rate:%s , discount:%s , max_once_rate:%s , select_rate:%s" , start_rate , discount , max_once_rate , select_rate ) )

	return select_rate
end


local function trans_text_base(_text,_func,_level,_max_level)
	local _s,_

    local _is_fun = type(_func) == "function"

    local _context  -- 当前递归层次的上下文
    if _is_fun then
        _context = {}
    end

    _s,_ = string.gsub(_text,"{(%g-)}",function(_name)

        local _ret = _is_fun and _func(_name,_context) or _func[_name]

        if not _ret then
            return nil
        elseif _level < _max_level then
            return trans_text_base(_ret,_func,_level+1,_max_level)
        else
            return _ret
        end
    end)

	return _s
end

--[[
    替换字符串，支持多层嵌套（repl_str_var的增强）
    参数 ：
        _text ： 带变量的字符串，变量格式 {name}
        _func : 回调函数 function(_name)
                参数：
                    _name    变量名
                    _context 上下文（同一递归层次共享数据）， 可以不使用
                返回值：
                    返回 nil/false 表示 不替换，用原始字串
        _max_level : 最大递归层次
--]]
function basefunc.trans_text(_text,_func,_max_level)
    _max_level = _max_level or 5
    return trans_text_base(_text,_func,1,_max_level)
end


-- 迁移最后一个
function basefunc.array_move(_src,_dest)
	if not _src[1] then
		return nil
	end

	_dest[#_dest + 1] = _src[#_src]
	_src[#_src] = nil

	return _dest[#_dest]
end

---- add by wss 
---- 获取 表为 { key1 = weight1 , key2 = weight2 ... } 的 随机的 key
function basefunc.get_random_key_value(_data_vec)
	if type(_data_vec) ~= "table" then
		return nil
	end
	local total_power = 0
	for key,value in pairs(_data_vec) do
		total_power = total_power + value
	end
	if total_power <= 0 then
		return nil
	end
	local rand = math.random(total_power)
	local now_rand = 0
	for key,value in pairs(_data_vec) do
		if rand <= now_rand + value then
			return key,value
		end
		now_rand = now_rand + value
	end
	return nil
end


-- 判断字符串中是否包含不可见的ascii字符
function basefunc.chk_string_have_invisible_char(_str)

    if type(_str) == "string" and string.len(_str)>0 then
        for i=1, string.len(_str) do
            local ch = string.byte(_str,i)
            if ch < 33 or ch > 126 then
                return true
            end
        end
    end

	return false
end

local tag_list = {}
function basefunc.check_time_interval( _time, _tag, _mod, _id )
	if not basefunc.chk_player_is_real(_id) then
		return nil
	end 
	local cur_tag_list = tag_list
	if _id then
		tag_list[_id] = tag_list[_id] or {last=tag_list.last}
		cur_tag_list = tag_list[_id]
	end
	local cur = _time
	if not cur_tag_list.last then
		cur_tag_list.last=cur
	end
	if _mod~=0 then
		dump.time_interval({_id, _tag, _mod, cur, cur-cur_tag_list[_tag] or cur_tag_list.last}, "")
	end
	cur_tag_list[_tag] = cur
	cur_tag_list.last = cur
end


-- 生成一个随机字符串
function basefunc.random_str(_len)
	if _len <= 0 then
		return ""
	end
	local _rand_chars = "6A9BD4E7FG8HJLMQNKR3TUdYabefhgijkmnqrt2uy"
	local _rand_len = string.len(_rand_chars)
	local _chars = {}
	for i=1,_len do
		local r = math.random(_rand_len)
		_chars[#_chars + 1] = string.sub(_rand_chars,r,r)
	end

	return table.concat(_chars)
end

-- 生成一个不区分大小写的随机字符串
function basefunc.random_CIstr(_len)
	if _len <= 0 then
		return ""
	end
	-- 去掉容易混淆的字符
	local _rand_chars = "0123456789ABCDEFGHJKMNPQRSTUVWXYZ"
	local _rand_len = string.len(_rand_chars)
	local _chars = {}
	for i=1,_len do
		local r = random(_rand_len)
		_chars[#_chars + 1] = string.sub(_rand_chars,r,r)
	end

	return table.concat(_chars)
end

---- 生成一个简易的唯一的token
local gen_token_idx = 0
function basefunc.gen_token( )
    gen_token_idx = gen_token_idx + 1
    if gen_token_idx > 65536 then
    	gen_token_idx = 1
    end

    local ts = os.date("%Y%m%d%H%M%S")
    return string.format("%s%s%s", ts, basefunc.random_str(5), gen_token_idx)
end

--[[
	_merge 表示是否合并相同单元格
	_not_one_line 存放不用在一行内显示的数据 {1,2,4}表示第1列、第2列、第4列可以换行显示

	_data需要格式化好，{[1]={},[2]={}}
	_name长度需要和_data每行长度一致
	对于_name包含'时间'两个字，且不是'时间戳'的，会将_data对应的时间戳转换为时间字符串
]]
function basefunc.build_web_table(_data, _name, _merge, _not_one_line)
	if not _data or type(_data)~="table" then
		return nil, [[<font color="#FF0000">[build数据异常]</font><br><br>]]..STR(_data)
	end

	for _,data in ipairs(_data) do
		if #data~=#_name then
			return nil, [[<font color="#FF0000">[数据与表头长度不一致]</font>]]
		end
	end

	local not_one_line = {}
	_not_one_line = _not_one_line or {}
	for _,v in ipairs(_not_one_line) do
		not_one_line[v] = true
	end

	local html_str = [[<div style="text-align: center;"><table border="3" style="margin: auto">]]

	-- 表头
	html_str = html_str..[[<tr>]]
	for i,name in ipairs(_name) do
		html_str = html_str ..[[<th ]]..(not_one_line[i] and 'width="300"' or 'nowrap="nowrap"')
							..[[ style="text-align: center;]]
							..(not_one_line[i] and ' word-break: break-all;' or '')
							..[[">]]
							..name..[[</th>]]
	end
	html_str = html_str..[[</tr>]]

	if #_data>0 then
		-- 构建合并单元格矩阵
		local merge_matrix = {}
		for i = 1,#_data do
			merge_matrix[i] = {}
			for j = 1,#_data[i] do
				merge_matrix[i][j] = 1
			end
		end
		if _merge then
			for j = 1,#_data[1] do
				for i = #_data,2,-1 do
					if _data[i][j]==_data[i-1][j] then
						merge_matrix[i-1][j] = merge_matrix[i-1][j] + merge_matrix[i][j]
						merge_matrix[i][j] = 0
					end
				end
			end
		end

		-- 内容
		for i = 1,#_data do
			html_str = html_str..[[<tr>]]

			for j = 1,#_data[i] do
				if type(_data[i][j])=="number" then
					-- 时间替换
					if string.find(_name[j], "时间") and not string.find(_name[j], "时间戳")  then
						_data[i][j] = basefunc.setDateTime(os.date("*t",_data[i][j]))
					else
						_data[i][j] = tostring(_data[i][j])
					end
				end
				if merge_matrix[i][j]>0 then
					html_str = html_str
								..[[<td ]]..(not_one_line[j] and '' or [[nowrap="nowrap"]])
								..[[ style="text-align: center;]]
								..(not_one_line[j] and ' word-break: break-all;' or '')
								..[[" rowspan="]]..merge_matrix[i][j]..[[">]]
								.._data[i][j]
								..[[</td>]]
				end
			end
			html_str = html_str..[[</tr>]]
		end
	end
	html_str = html_str..[[</table></div>]]

	return html_str, nil
end

function basefunc.get_today_0_timestamp(now)
    now = now or os.time() -- 获取当前时间戳
    local now_date = os.date("*t", now) -- 转换为日期时间
    now_date.hour = 0 -- 将时设置为0
    now_date.min = 0 -- 将分设置为0
    now_date.sec = 0 -- 将秒设置为0
    local midnight = os.time(now_date) -- 转换回时间戳
    return midnight
end


function basefunc.sort_tbl_by_key(t)
    local tt = {}
    for k,v in pairs(t) do
      if v ~= '' then
        table.insert(tt, {k = k, v = v})
      end
    end

    table.sort(tt, function (a, b)
      return a.k < b.k
    end)
    return tt
end

function basefunc.sign_table2str(tab)
    local res_tab = {}
    
    for _, v in ipairs(tab) do
        if v.v and v.v ~= "" then
            table.insert(res_tab, string.format('%s=%s', v.k, v.v))
        end
    end

    return table.concat(res_tab, "&")
end

function basefunc.split(str, delimiter)  
    -- 结果表  
    local result = {}  
    local current = ""
    for i = 1, #str do  
        if str:sub(i, i) == delimiter then  
            if #current > 0 then  
                table.insert(result, current)  
            end  
            current = ""
        else  
            current = current .. str:sub(i, i)  
        end  
    end   
    if #current > 0 then  
        table.insert(result, current)  
    end  
    return result  
end  

return basefunc