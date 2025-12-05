-- This file will execute before every lua service start
-- See config

-- print("PRELOAD", ...)

if ... ~= "userlog" then
	local logfile = require("logfile")
	local skynet = require("skynet")
	tlog = logfile.Test
	dlog = logfile.Debug
	rlog = logfile.Rel
	elog = logfile.Err
	print = tlog
	skynet.error = tlog

	require "pdefine"
	require "dump"
	require "preload.io"
	require "preload.string"
end

-- lua面向对象扩展
-- local _class={}

-- function class(super)
--     local class_type={}
--     class_type.ctor=false
--     class_type.super=super
--     class_type.new=function(...)
--             local obj={}
--             do
--                 local create
--                 create = function(c,...)
--                     if c.super then
--                         create(c.super,...)
--                     end
--                     if c.ctor then
--                         c.ctor(obj,...)
--                     end
--                 end

--                 create(class_type,...)
--             end
--             setmetatable(obj,{ __index=_class[class_type] })
--             return obj
--         end
--     local vtbl={}
--     _class[class_type]=vtbl

--     setmetatable(class_type,{__newindex=
--         function(t,k,v)
--             vtbl[k]=v
--         end
--     })

--     if super then
--         setmetatable(vtbl,{__index=
--             function(t,k)
--                 local ret=_class[super][k]
--                 vtbl[k]=ret
--                 return ret
--             end
--         })
--     end

--     return class_type
-- end

----
function class(clsname, super)
    local _name2cls = _G._name2cls
    if not _name2cls then
        _name2cls = {}
        _G._name2cls = _name2cls
    end
    local cls = _name2cls[clsname]
    if cls then
        print("class already defined, will override " .. clsname)
        return cls
    end
    
    local superType = type(super)
    if superType ~= "function" and superType ~= "table" then
        superType = nil
        super = nil
    end

    if superType == "function" or (super and super.__ctype == 1) then
        -- inherited from native C++ Object
        cls = {}
        if superType == "table" then
            -- copy fields from super
            for k,v in pairs(super) do cls[k] = v end
            cls.__create = super.__create
            cls.super    = super
        else
            cls.__create = super
            cls.ctor = function() end
        end
        cls.__cname = clsname
        cls.__ctype = 1
        function cls.new(...)
            local instance = cls.__create(...)
            -- copy fields from class to native object
            for k,v in pairs(cls) do instance[k] = v end
            instance.class = cls
            instance:ctor(...)
            return instance
        end
    else
        -- inherited from Lua Object
        if super then
            cls = {}
            setmetatable(cls, {__index = super})
            cls.super = super
        else
            cls = {ctor = function() end}
        end
        cls.__cname = clsname
        cls.__ctype = 2 -- lua
        cls.__index = cls
        function cls.new(...)
            local instance = setmetatable({}, cls)
            instance.class = cls
            instance:ctor(...)
            return instance
        end
    end
    _name2cls[clsname] = cls

    return cls
end
