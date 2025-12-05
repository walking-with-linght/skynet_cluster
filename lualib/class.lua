local class = {}; 
setmetatable(class, class)

function class:__index(name)
	local class_methods = {}; 
    class_methods.__index = class_methods
	local class_object = {}
	local class_meta = {
		__newindex = class_methods,
		__index = class_methods,
		__call = function(self, init)
			return setmetatable(init or {}, class_methods)
		end
	}
	class[name] = setmetatable(class_object, class_meta)
	return class_object
end

local class = { __index = class };
setmetatable(class, class)

function class:__call(name)
	return self[name]
end

local function container_next(self, k)
	local nk, v = next(self, k)
	if nk == false then
		return next(self, false)
	else
		return nk, v
	end
end

function class.container(name)
	local container_class = class[name]
	function container_class:__pairs()
		return container_next, self
	end
	return container_class
end

return class
--[[
local class = require("class")

-- 定义类
class.Car = {
    drive = function(self) 
        print("Driving at " .. self.speed .. " km/h") 
    end,
    
    stop = function(self)
        print("Car stopped")
        self.speed = 0
    end
}

-- 实例化对象
local myCar = class.Car({ speed = 60 })
myCar:drive()  -- 输出: Driving at 60 km/h
myCar:stop()   -- 输出: Car stopped
-------------------------------------------------------------------------------
class.Person = {
    -- 构造函数
    new = function(self, name, age)
        return self({ name = name, age = age })
    end,
    
    -- 实例方法
    introduce = function(self)
        print("Hello, I'm " .. self.name .. ", " .. self.age .. " years old")
    end,
    
    -- 类方法
    getSpecies = function()
        return "Homo sapiens"
    end
}

-- 使用
local person = class.Person:new("Alice", 25)
person:introduce()  -- 输出: Hello, I'm Alice, 25 years old
print(class.Person.getSpecies())  -- 输出: Homo sapiens
-------------------------------------------------------------------------------
-- 定义容器类
class.List = {
    add = function(self, item)
        table.insert(self, item)
    end,
    
    get = function(self, index)
        return self[index]
    end
}

-- 启用容器功能
class.container("List")

local myList = class.List()
myList:add("apple")
myList:add("banana")
myList:add("cherry")

-- 支持pairs遍历
for index, value in pairs(myList) do
    print(index, value)  -- 输出: 1 apple, 2 banana, 3 cherry
end

]]