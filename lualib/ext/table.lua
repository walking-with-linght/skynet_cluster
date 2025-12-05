local string_format = string.format
local pairs = pairs
   
--复制对象可以带元表
function table.clone(t)

    local hash = {}
    local function _clone(obj)

        if type(obj) ~= "table" then
            return obj
        elseif hash[obj] then
            return hash[obj]    
        end 
        local newObj = {}
        hash[obj] = newObj
        for k, v in pairs(obj) do
            newObj[_clone(k)] = _clone(v)
        end 

        return setmetatable(newObj, getmetatable(obj))
    end 

    local t  = _clone(obj)
    return t
end    

--复制对象不带元表
function table.copy(t)

    local function clone(t, lookup)

        if type(t) ~= "table" then
            return t
        elseif lookup[t] then
            return lookup[t]
        end
        local n = {}
        lookup[t] = n
        for key, value in pairs(t) do
            n[clone(key, lookup)] = clone(value, lookup)
        end
        return n      
    end    
    local lookup = {}
    return clone(t, lookup)
end

function table.random(arr2, num)

    assert(type(arr2) == "table")
    assert(type(num) == "number" and num >= 1)
    local arr = table.copy(arr2)
    if num >= #arr then
        return arr
    end 
    --math.randomseed(os.time())
    local targets = {}
    while #targets < num do
        local index = math.myrand(#arr)
        local item = table.remove(arr, index)
        table.insert(targets, item)
    end 
    return targets
end 

function table.keys(hashtable)
    local keys = {}
    for k, v in pairs(hashtable) do
        keys[#keys + 1] = k
    end
    return keys
end

function table.values(hashtable)
    local values = {}
    for k, v in pairs(hashtable) do
        values[#values + 1] = v
    end
    return values
end

function table.merge(dest, src)
    for k, v in pairs(src) do
        dest[k] = v
    end
end

function table.mergearray(dest, src)
    for k, v in ipairs(src) do
        table.insert(dest, v)
    end
end

--移除数组t指定下标的remove的元素
function table.removeindex(t, remove)

    table.sort(remove, function (a, b) return a > b end)
    local len = #t
    for _, index in ipairs(remove) do
        if index <= len then
            table.remove(t, index)
        end
    end 
end

--将数组src插入数组dest前面
function table.inserthead(dest, src)
    for i = #src, 1, -1 do
        table.insert(dest, 1, src[i])
    end
end

function table.map(t, fn)
    local n = {}
    for k, v in pairs(t) do
        n[k] = fn(v, k)
    end
    return n
end

function table.walk(t, fn)
    for k,v in pairs(t) do
        fn(v, k)
    end
end

function table.filter(t, fn)
    local n = {}
    for k, v in pairs(t) do
        if fn(v, k) then
            n[k] = v
        end
    end
    return n
end

function table.length(t)
    local count = 0
    for _, __ in pairs(t) do
        count = count + 1
    end
    return count
end

function table.readonly(t, name)
    name = name or "table"
    setmetatable(t, {
        __newindex = function()
            error(string_format("<%s:%s> is readonly table", name, tostring(t)))
        end,
        __index = function(_, key)
            error(string_format("<%s:%s> not found key: %s", name, tostring(t), key))
        end
    })
    return t
end

function table.keys(t)
    local ret = {}
    for k,v in pairs(t) do
        table.insert(ret,k)
    end
    return ret
end

function table.arrayKeys(t)
    local ret = {}
    for k, _ in ipairs(t) do
        table.insert(ret, k)
    end
    return ret
end

function table.values(t)
    local ret = {}
    for k,v in pairs(t) do
        table.insert(ret,v)
    end
    return ret
end

function table.numberArrayEqual(array1, array2)

    if #array1 ~= #array2 then
        return false
    end

    table.sort(array1)
    table.sort(array2)
    for i = 1, #array1 do

        if array1[i] ~= array2[i] then
            return false
        end
    end

    return true
end

function table.shuffle(array)

    local count = #array
    local t={}
    local maxIndex = count
    for i = 1, maxIndex do
        table.insert(t,i)
    end

    while maxIndex > 1 do
        local n = math.random(1,maxIndex-1)
        if t[n] ~= nil then
            t[maxIndex],t[n] = t[n],t[maxIndex]
            maxIndex = maxIndex - 1
        end
    end

    local r = {}
    for _, i in pairs(t) do
        table.insert(r, array[i])
    end
    return r
end

--快速插入 注意func返回值 1 -1 0, 排序函数必须确定唯一排序股则
function table.insertObj(arr, obj, func)
    assert(type(func) == "function")
    local _begin = 1
    local _end = #arr
    while _begin <= _end do
        local mid = math.ceil((_begin + _end) / 2)
        local item = arr[mid]
        local ret = func(obj, item)
        if ret == 0 then 
            assert(false) 
        end
        if ret  > 0 then
            _begin = mid + 1
        else
            _end = mid - 1
        end
    end
    table.insert(arr, _begin, obj)
    return _begin
end 

function table.findObjIndex(arr, obj, func)
   assert(type(func) == "function")
    local _begin = 1
    local _end = #arr
    while _begin <= _end do
        local mid = math.ceil((_begin + _end) / 2)
        local item = arr[mid]
        local ret = func(obj, item)
        if ret == 0 then 
            return mid
        end
        if ret  > 0 then
            _begin = mid + 1
        else
            _end = mid - 1
        end
    end
    return nil
end    

--快速删除 注意func返回值 1 -1 0, 排序函数必须确定唯一排序股则
function table.removeObj(arr, obj, func)
    local index = table.findObjIndex(arr, obj, func)
    if index then
        table.remove(arr, index)
    end    
    return index
end
