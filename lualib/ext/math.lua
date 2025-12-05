local skynet 			= require "skynet"
local math_randomseed   = math.randomseed
local math_random       = math.random
local string_gsub       = string.gsub
local string_format     = string.format
local load              = load
local math_floor        = math.floor
local table      = table
local randomseed

function extract_number_from_string(str)  

    local hex_or_dec_str = string.match(str, "table: 0x(%w+)")  
    if hex_or_dec_str then  

        if string.sub(hex_or_dec_str, 1, 2) == "0x" then  
 
            return tonumber(hex_or_dec_str, 16)  
        else  
    
            local dec_str = ""  
            for digit in string.gmatch(hex_or_dec_str, "%d") do  

                if dec_str == "" or digit ~= "0" or string.sub(dec_str, -1) ~= "0" then  
                    dec_str = dec_str .. digit  
                end  
            end  

            return tonumber(dec_str)  
        end  
    else  
        -- 如果没有匹配到任何数字，返回nil或错误处理  
        mylog.warn("error str:%s", str)
        return 1
    end  
end  

function math.myrand(min, max)

--    math.randomseed(os.time())
--    if max then
--        return math.random(min, max)
--    else
--        return math.random(min)
--    end
    local t = {}
    if min == max then return min end
    if not randomseed then
        randomSeed = extract_number_from_string(string.format('%s', t))
        --mylog.info("myrand==========service:%08x t:%s randomSeed:%s", skynet.self(), string.format('%s', t), randomSeed)
        math_randomseed(math_floor(randomSeed) + math_floor(skynet.time() * 100))
    end
    if max then
        return math_random(min, max)
    else
        return math_random(min)
    end
end	


function math.rate(num)
    return math.myrand(10000) <= num
end    

function math.randarr(num, arr2)

    if num >= #arr2 then
        return arr2
    end 
    local arr = {}
    for k, v in pairs(arr2) do table.insert(arr, v) end
    local targets = {}
    while #targets < num do
        local item = table.remove(arr, math_random(#arr))
        table.insert(targets, item)
    end 
    return targets
end 

function math.randOne(arr2)
    return math.randarr(1, arr2)[1]
end

function math.tonumber(num)

    return assert(tonumber(num), string.format("stack traceback: error num %s.", num))
end    


--expr 公式
--map {a = xxx, b = xxx}
--返回整数
function math.expr(expr, map)
    local expr = string_gsub(expr, "(%w+)", map)
    return math_floor(math.rawexpr(expr, map))
end   

--公式 返回原值(可能为小数)
function math.rawexpr(expr, map)
    local expr = string_gsub(expr, "(%w+)", map)
    return load(string_format("return %s", expr))()
end   

