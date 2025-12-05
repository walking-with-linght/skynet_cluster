local string_gsub   = string.gsub
local table_insert  = table.insert

function string.trim(s, char)
    if io.empty(char) then
        return (string_gsub(s, "^%s*(.-)%s*$", "%1"))
    end
    return (string_gsub(s, "^".. char .."*(.-)".. char .."*$", "%1"))
end


function string.ltrim(s, char)
    if io.empty(char) then
        return (string_gsub(s, "^%s*(.-)$", "%1"))
    end
    return (string_gsub(s, "^".. char .."*(.-)$", "%1"))
end


function string.rtrim(s, char)
    if io.empty(char) then
        return (string_gsub(s, "^(.-)%s*$", "%1"))
    end
    return (string_gsub(s, "^(.-)".. char .."*$", "%1"))
end

function string.split(dest, sep, toint)


    local rt= {}
    --
    string_gsub(dest, '[^'..sep..']+', function(w)
        table_insert(rt, toint and tonumber(string.trim(w)) or string.trim(w))
    end)

    return rt
end

function string.invalid(str, maxLen)

    return type(str) ~= "string" or #str <= 0  
            or str:match("['|-|\\|\"|,|;|:|%s]") 
            or (type(maxLen) == "number" and maxLen > 0 and #str > maxLen)
end    

function string.serialize(obj, lvl, isFeed)
    local lua = ""
    local feed1 = isFeed and "{" or "{\n"
    local feed2 = isFeed and "," or ",\n"
    local t = type(obj)
    if t == "number" then
        lua = lua .. obj
    elseif t == "boolean" then
        lua = lua .. tostring(obj)
    elseif t == "string" then
        lua = lua .. string.format("%q", obj)
    elseif t == "table" then
        lvl = lvl or 0
        local lvls = ('  '):rep(lvl)
        local lvls2 = ('  '):rep(lvl + 1)
        lua = lua .. feed1
        for k, v in pairs(obj) do
            lua = lua .. lvls2
            lua = lua .. "[" .. string.serialize(k, lvl + 1) .. "]=" .. string.serialize(v, lvl + 1) .. feed2
        end
        local metatable = getmetatable(obj)
        if metatable and type(metatable.__index) == "table" then
        for k, v in pairs(metatable.__index) do
            lua = lua .. "[" .. string.serialize(k, lvl + 1) .. "]=" .. string.serialize(v, lvl + 1) .. feed2
        end
    end
        lua = lua .. lvls
        lua = lua .. "}"
    elseif t == "nil" then
        return "nil"
    elseif t == "function" then
        return  "function"    
    else
        error("can not serialize a " .. t .. " type.")
    end
    return lua
end

-- function string.dump(obj)

--     if mylog and not mylog.isDebug then
--         return ''
--     end

--     local getIndent, quoteStr, wrapKey, wrapVal, dumpObj
--     getIndent = function(level)
--         return string.rep("\t", level)
--     end
--     quoteStr = function(str)
--         return '"' .. string.gsub(str, '"', '\\"') .. '"'
--     end
--     wrapKey = function(val)
--         if type(val) == "number" then
--             return "[" .. val .. "]"
--         elseif type(val) == "string" then
--             return "[" .. quoteStr(val) .. "]"
--         else
--             return "[" .. tostring(val) .. "]"
--         end
--     end
--     wrapVal = function(val, level)
--         if type(val) == "table" then
--             return dumpObj(val, level)
--         elseif type(val) == "number" then
--             return val
--         elseif type(val) == "string" then
--             return quoteStr(val)
--         else
--             return tostring(val)
--         end
--     end
--     dumpObj = function(obj, level)
--         if type(obj) ~= "table" then
--             return wrapVal(obj)
--         end
--         level = level + 1
--         local tokens = {}
--         tokens[#tokens + 1] = "{"
--         for k, v in pairs(obj) do
--             tokens[#tokens + 1] = getIndent(level) .. wrapKey(k) .. " = " .. wrapVal(v, level) .. ","
--         end
--         tokens[#tokens + 1] = getIndent(level - 1) .. "}"
--         return table.concat(tokens, "\n")
--     end
--     return dumpObj(obj, 0)
-- end

function string.escape(s)
    return s:gsub("[^a-zA-Z0-9-_.~]", function(c) 
        return string.format("%%%02x",string.byte(c)) 
    end)
end

function string.unescape(s)
    return s:gsub("%%%x%x", function(ss) 
        return string.char(tonumber("0x" .. ss:sub(2))) 
    end)
end

function string.parse_query_string(s, t)
    if not s then
        return
    end

    for k,v in s:gmatch("([^&;]+)=([^&;]+)") do
        if #k > 0 then
            t[string.unescape(k)] = string.unescape(v)
        end
    end
end

function string.encode_query_string(t)
    if not t then
        return ""
    end

    local tt = {}
    for k,v in pairs(t) do
        if type(v) ~= "string" then
            v = tostring(v)
        end
        tt[#tt + 1] = string.format("%s=%s", string.escape(k), string.escape(v))
    end
    return table.concat(tt, "&")
end

-- 生成62进制字符数字映射
function string.gen62char()
    local map = {}
    for i=0,61 do
        local char
        if 10 <= i and i < 36 then
            char = string.char(65+i-10)
        elseif 36 <= i and i < 62 then
            char = string.char(97+i-36)
        else
            char = tostring(i)
        end
        map[i] = char
        map[char] = i
    end
    return map
end

-- 0-9A-Za-z
string.CHAR_MAP = string.gen62char()

function string.randomkey(len)
    len = len or 32
    local ret = {}
    local maxlen = 62
    for i=1,len do
        table.insert(ret,string.CHAR_MAP[math.random(0,maxlen-1)])
    end
    return table.concat(ret,"")
end
