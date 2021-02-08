local _G = require "_G"
local getmetatable = _G.getmetatable
local pairs = _G.pairs
local select = _G.select
local setmetatable = _G.setmetatable
local tonumber = _G.tonumber
local type = _G.type

---[[
local newmem = memory.create
--[=[]]
local create = memory.create
local resize = memory.resize
local function newmem(str)
	local m = create()
	resize(m, #str, str)
	return m
end
--]=]

local function tomemval(v)
	if type(v) == "string" then
		return newmem(v)
	end
	return v
end

local function tomemnotnum(v)
	if type(v) == "string" and tonumber(v) == nil then
		return newmem(v)
	end
	return v
end

local function tomemstrorfunc(chunk)
	local t = type(chunk)
	if t == "string" then
		return memory.create(chunk)
	elseif t == "function" then
		return function (...)
			return tomemval(chunk(...))
		end
	end
	return chunk
end

local tomemvararg = setmetatable({}, {__index = function () return tomemval end})
local tomemnotnumva = setmetatable({false}, {__index = function () return tomemnotnum end})

local wraps = {
	[_G] = {
		print = tomemvararg,
		load = {tomemstrorfunc},
	},
	[io] = {
		write = tomemvararg,
	},
	[getmetatable(io.stdout).__index] = {
		write = tomemvararg,
	},
	[string] = {
		sub = {tomemval},
		reverse = {tomemval},
		lower = {tomemval},
		upper = {tomemval},
		rep = {tomemval, false, tomemval},
		byte = {tomemval},
		find = {tomemval},
		match = {tomemval},
		gmatch = {tomemval},
		gsub = {tomemval, false, tomemstrorfunc},
		format = tomemnotnumva,
		pack = tomemnotnumva,
		unpack = {nil, tomemval},
	},
	[table] = {
		concat = {tomemval, tomemval},
	},
	[utf8] = {
		len = {tomemval},
		codepoint = {tomemval},
		offset = {tomemval},
		codes = {tomemval},
	},
}

local function wrapargs(i, args, ...)
	if select("#", ...) > 0 then
		local value = ...
		local convert = args[i]
		if convert then
			value = convert(value)
		end
		return value, wrapargs(i+1, args, select(2, ...))
	end
end

for module, funcs in pairs(wraps) do
	for name, args in pairs(funcs) do
		local backup = module[name]
		module[name] = function (...)
			return backup(wrapargs(1, args, ...))
		end
	end
end