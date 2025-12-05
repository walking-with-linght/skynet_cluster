local os_date           = os.date
local math_random       = math.random
local math_floor        = math.floor
local string_format     = string.format
local string_gsub       = string.gsub
local mylog				= require "base.mylog"
local skynet            = require "skynet"

function os.getTime()

	local t = os.date("*t")
	return string.format("%d-%d-%d %d:%d:%d",t.year,t.month,t.day,
		t.hour,t.min,t.sec)
end	

function os.getClock(timestring)

	local zol = {"year","month","day","hour","min","sec"}
	local d = 1
	local dest = {}
	string.gsub(timestring, "(%d+)", function (s)
		dest[zol[d]] = s
		d = d + 1
	end)

	return os.time(dest)
end	

function os.getDate()

	return os.date("*t")
end	

function os.getDateTime(time)

	return os.date("*t",time)
end	


function os.getDay()

	local t = os.date("*t")
	return t.day
end	

function os.getMonth()

	local t = os.date("*t")
	return t.month
end	

function os.isLeapYear()

	local t = os.date("*t")
	local year = t.year
    return (year%4 == 0 and year%100 ~= 0) or year%400 == 0;
end


function os.getClockOfTime()

    local t = os.date("*t")
    return t.hour * 10000 + t.min * 100
end    

function os.getWeek()
    local t = os.date("*t")
    if t.wday == 1 then 
        return 7--星期天 = 1
    else
        return t.wday - 1
    end       
end    

function os.getClockWeekOfTime()

    local t = os.date("*t")
    return os.getWeek() * 10000000 + t.hour * 10000 + t.min * 100
end    

function os.getCurTime()
    
    --return math_floor(skynet.time())
    return os.time()
end

function os.getThisMonth(time)

    time = time or os.time()
    return tonumber(os.date('%m', time))
end 

function os.getWeeHoursTime()
    local time = os.time()
    return os.time({
        year    = os_date("%Y", time),
        month   = os_date("%m", time),
        day     = os_date("%d", time),
        hour    = 0,
        min     = 0,
        sec     = 0,
    })
end


function os.getTimeYMD(t)

    return os.time({
        year    = os_date("%Y", t),
        month   = os_date("%m", t),
        day     = os_date("%d", t),
        hour    = 0,
        min     = 0,
        sec     = 0,
    })
end


function os.isExpiredTime(time1, time2, hour, min, sec)

    local hour = hour or 0
    local min  = min or 0
    local sec = sec or 0
    return os.getSameDayEndTime(time1, hour, min, sec) ~= os.getSameDayEndTime(time2, hour, min, sec)
end

function os.getSameDayBeginTime(time, checkHour)
    return os.getSameDayEndTime(time, checkHour) - (24 * 3600)
end

function os.getSameDayEndTime(time, checkHour, checkMin, checkSec)
    if not checkHour then checkHour = 0 end
    if not checkMin then checkMin = 0 end
    if not checkSec then checkSec = 0 end

    local time2 = os.date("*t", time)
    local data1 = checkHour * 3600 + checkMin * 60 + checkSec
    local data2 = time2.hour * 3600 + time2.min * 60 + time2.sec

    time2.hour = checkHour
    time2.min = checkMin
    time2.sec = checkSec
    if data2 >= data1 then
        return os.time(time2) + (24 * 3600)
    else
        return os.time(time2)
    end
end

function os.getSameWeekBeginTime(time, checkWeek)
    return os.getSameWeekEndTime(time, checkWeek) - (7 * 24 * 3600)
end


function os.isExpiredWeekTime(time1, time2, checkWeek, hour, min, sec)

    local hour = hour or 0
    local min  = min or 0
    local sec = sec or 0
    return os.getSameWeekEndTime(time1, checkWeek, hour, min, sec) ~= os.getSameWeekEndTime(time2, checkWeek, hour, min, sec)
end

-- getSameWeekEndTime函数是以周六为一周最后一天
function os.getSameWeekEndTime(time, checkWeek, checkHour, checkMin, checkSec)
    if not checkHour then checkHour = 0 end
    if not checkMin then checkMin = 0 end
    if not checkSec then checkSec = 0 end

    local time2 = os.date("*t", time)
    local data1 = checkWeek * 1000000 + checkHour * 10000 + checkMin * 100 + checkSec
    local data2 = time2.wday * 1000000 + time2.hour * 10000 + time2.min * 100 + time2.sec

    time2.hour = checkHour
    time2.min = checkMin
    time2.sec = checkSec
    if data2 >= data1 then
        return os.time(time2) + (24 * 3600 * (7 - time2.wday + checkWeek))
    else
        return os.time(time2) + (24 * 3600 * (- time2.wday + checkWeek))
    end
end

function os.decodeSegmentTime(str)
    local results = {}
    for _, data in ipairs(str:split(";") or {}) do
        local info = data:split(":")
        if #info ~= 2 then
            mylog.warn("impossible str:%s", str or -1)
        end

        table.insert(results, {tonumber(info[1]), tonumber(info[2])})
    end

    return results
end

function os.decodeSegmentsPerDay(str)
    local results = {}
    for index, data in ipairs(str:split(";") or {}) do
        local data2 = data:split("-")
        if #data2 ~= 2 then
            mylog.warn("impossible str:%s", str or -1)
        end

        local result = {}
        for _, datum in ipairs(data2) do
            local info = datum:split(":")
            if #info ~= 2 then
                mylog.warn("impossible str:%s", str or -1)
            end

            table.insert(result, {tonumber(info[1]), tonumber(info[2])})
        end
        table.insert(results, result)
    end

    return results
end

function os.isInSegment(segments, now)
    local time = os.date("*t", now)
    local hourmin = time.hour * 10000 + time.min * 100 + time.sec

    for index, segment in ipairs(segments or {}) do
        local begin = segment[1][1] * 10000 + segment[1][2] * 100
        local endEx = segment[2][1] * 10000 + segment[2][2] * 100

        if hourmin >= begin and hourmin <= endEx then
            return index
        end
    end

    return 0
end

-- 24*60*60=86400
function os.getDays(lastTime)
    assert(type(lastTime) == "number")

    local time = os.date("*t", lastTime)
    time.hour = 0
    time.min = 0
    time.sec = 0
    lastTime = os.time(time)

    local interval = os.time() - lastTime
    local days = math.floor(interval / 86400)
    if interval > (days * 86400) then
        days = days + 1
    end

    return days
end
-- 时间字符串(XXXX-XX-XX XX:XX:XX)解析成时间(table)
function os.stringToDateTable(strTime)

    if type(strTime) ~= "string" then
        mylog.warn("transfer format must be string. error type:%s %s", type(strTime), strTime)
        return 0
    end

    local timeTable = {}
    local t = strTime:split(" ")
    if #t ~= 2 then
        mylog.warn("transfer data must be [XXXX-XX-XX XX:XX:XX][%s]", strTime)
    end

    for k, v in pairs(t) do
        if k == 1 then
             local t2 = v:split("-")
             if #t2 ~= 3 then
                mylog.warn("transfer data must be [XXXX-XX-XX XX:XX:XX][%s]", strTime)
             end
             timeTable.year = t2[1] or 2000
             timeTable.month = t2[2] or 1
             timeTable.day = t2[3] or 1
        elseif k == 2 then
            local t2 =  v:split(":")
            if #t2 ~= 3 then
                mylog.warn("transfer data must be [XXXX-XX-XX XX:XX:XX][%s]", strTime)
            end
            timeTable.hour = t2[1] or 0
            timeTable.min = t2[2] or 0
            timeTable.sec = t2[3] or 0
        end
    end

    return timeTable
end

-- 时间字符串(XXXX-XX-XX XX:XX:XX)解析成时间(os.time())
function os.stringToDateTime(strTime)

    if type(strTime) ~= "string" then
        mylog.warn("transfer format must be string. error type:%s %s", type(strTime), strTime)
        return 0
    end

    local timeTable = {}
    local t = strTime:split(" ")
    if #t ~= 2 then
        mylog.warn("transfer data must be [XXXX-XX-XX XX:XX:XX][%s]", strTime)
    end

    for k, v in pairs(t) do
        if k == 1 then
             local t2 = v:split("-")
             if #t2 ~= 3 then
                mylog.warn("transfer data must be [XXXX-XX-XX XX:XX:XX][%s]", strTime)
             end
             timeTable.year = t2[1] or 2000
             timeTable.month = t2[2] or 1
             timeTable.day = t2[3] or 1
        elseif k == 2 then
            local t2 =  v:split(":")
            if #t2 ~= 3 then
                mylog.warn("transfer data must be [XXXX-XX-XX XX:XX:XX][%s]", strTime)
            end
            timeTable.hour = t2[1] or 0
            timeTable.min = t2[2] or 0
            timeTable.sec = t2[3] or 0
        end
    end

    return os.time(timeTable)
end

-- 时间解析成字符串(XXXX-XX-XX XX:XX:XX)
function os.dateTimeToString(time)
    return string_format("%02d-%02d-%02d %02d:%02d:%02d", os_date("%Y", time), os_date("%m", time), os_date("%d", time), os_date("%H", time), os_date("%M", time), os_date("%S", time))
end

function os.isTimeInfoMaxEndTimeStrDay(curTimeInfo,endTimeStr,addDay)
    local endTimeTable = os.stringToDateTable(endTimeStr)
    if not addDay then addDay = 0 end
    if curTimeInfo.year> tonumber(endTimeTable.year) then
        return true,tostring(os.time(endTimeTable))
    end

    if curTimeInfo.month> tonumber(endTimeTable.month) then
        return true,tostring(os.time(endTimeTable))
    end

    if curTimeInfo.day+addDay>= tonumber(endTimeTable.day) then
        return true,tostring(os.time(endTimeTable))
    end
    return false

end

--指定时间,时分秒的时间戳
function os.getSameDayTime(lastTime,checkHour, checkMin, checkSec)
    if not checkHour then checkHour = 0 end
    if not checkMin then checkMin = 0 end
    if not checkSec then checkSec = 0 end

    local time = os.date("*t", lastTime)
    time.hour = checkHour
    time.min = checkMin
    time.sec = checkSec
    lastTime = os.time(time)
    return lastTime
end


--时间区间
-- 10:10 -13:50
-- 10:10 
function os.isInTimeInterval(t1,t2)
   
    local time = os.time()

    local hour = tonumber(os_date("%H", time))
    local min  = tonumber(os_date("%M", time))

    if t1 and t2 then
        if hour >=t1[1] and hour< t2[1] then 
            if hour == t1[1] then
                if min>=t1[2] then 
                    return true 
                else 
                    return false
                end
            elseif hour == t2[1] then 
                if min<t2[2] then 
                    return true 
                else 
                    return false
                end 
            else 
                return true      
            end
        else 
            return false
        end
    end

    if t1 then 
    
        if hour <t1[1]  then 
      
            return true 
        elseif hour ==t1[1] and min < t1[2] then 
   
            return true 
        end 

        return false
    end
end
