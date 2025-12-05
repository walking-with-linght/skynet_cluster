--
-- beautify
--
-- A command line utility for beautifying lua source code using the beautifier.
--

local util = require'utils.format.Util'
local Parser = require'utils.format.ParseLua'
local Format_Beautify = require'utils.format.FormatBeautiful'
local ParseLua = Parser.ParseLua
local PrintTable = util.PrintTable

local function splitFilename(name)
	--table.foreach(arg, print)
	if name:find(".") then
		local p, ext = name:match("()%.([^%.]*)$")
		if p and ext then
			if #ext == 0 then
				return name, nil
			else
				local filename = name:sub(1,p-1)
				return filename, ext
			end
		else
			return name, nil
		end
	else
		return name, nil
	end
end
local function beautify(source_content)
	local st, ast = ParseLua(source_content)
	if not st then
		--we failed to parse the file, show why
		print(ast)
		return false,ast
	end
	return Format_Beautify(ast)
end
return beautify
