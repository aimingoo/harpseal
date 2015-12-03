--
-- a simple pedt task management tool
--
-- usage:
--	> lua pedt.lua <action> [paraments]
--	> lua pedt.lua help
--	> lua pedt.lua
-- paraments:
--	for action 'add'/'run':
--			xxx			: taskDef modName/fileName/context, or set stdin by '-'
--			-t modName	: task_register_center module name
--			-c typeTag	: context type of taskDef, tags: module, json, file, or script
--	for action 'run':
--			-a args		: json or http query parament string, it's arguments for run task
--	for action 'help':
--			-t modName	: @see 'run' action, if exist
--			-l          : force list commands
--	for center methods:
--			-t modName	: @see 'run' action, if exist
--			-a args     : @see 'run' action, if exist
--			xxx			: normal arguments
--
local sepa = string.byte('-', 1)
local action, i = arg[1] or 'help', 2
if string.byte(action, 1) == sepa then
	action, i = 'help', 1
end

local default_task_center = require('infra.dbg_register_center') -- default
local task_center = default_task_center, arguments -- for 'run' action or center method
local task, context_type -- for 'add' action
local force_list = false
local function err(reason) print(reason) end

local JSON = require('lib.JSON')
local JSON_decode = function(...) return JSON:decode(...) end
local JSON_encode = function(...) return JSON:encode_pretty(...) end

while i <= #arg do
	local s = arg[i]
	if s == '-t' then -- task center
		i = i+1
		task_center = require(arg[i])
	elseif s == '-a' then -- arguments for 'run' or center methods:
		i = i+1
		arguments = arg[i]
		local ok, result = pcall(JSON_decode, arguments)
		if not ok then
			result = {}
			for param in string.gmatch(arguments, '[^&]+') do
				local found, _, key, value = string.find(param, '^([^=]+)=?(.*)$')
				if found then result[key] = value end
			end
		end
		arguments = type(result) == 'table' and result or nil
	elseif action == 'add' or action == 'run' then
		if s == '-' then
			if not task then task = '-' end
		elseif string.byte(s, 1) == sepa then
			if s == '-c' then -- context type
				i = i+1
				context_type = arg[i]
			end
		elseif not task then -- first only
			task = s
		end
	elseif action == 'show' then
		if not arguments and string.byte(s, 1) ~= sepa then
			arguments = s
		end
	elseif action == 'help' then
		if s == '-l' then
			force_list = true
		end
	end
	i = i + 1
end

-- get pedt instance to connect task center or resource center
local Harpseal = require("lib.Distributed")
local pedt = Harpseal:new({task_register_center = task_center})

-- get task load helper
local TaskLoader = require("tools.taskloader")
local loader = TaskLoader:new({ publisher = pedt })

local function isTaskId(str)
	return (string.len(str)==5+32) and string.match(str, '^task:')
end

local function add_action(task, context_type)
	if not task or task == '-' then
		task = io.read("*a")
		if not context_type then
			context_type = 'json'
		end
	end

	local p, taskId
	if not context_type or context_type == 'module' then
		p = loader:loadByModule(task):andThen(function(id)
			taskId = id
			print(taskId .. ' loaded from module: '..task)
		end)
	elseif context_type == 'file' then
		p = loader:loadByFile(task):andThen(function(id)
			taskId = id
			print(taskId .. ' loaded from file: '..task)
		end)
	elseif context_type == 'script' then
		p = loader:loadScript(task):andThen(function(id)
			taskId = id
			print(taskId .. ' loaded from script.')
		end)
	elseif context_type == 'json' then -- json conext, not json file
		p = loader.publisher:register_task(task):andThen(function(id)
			taskId = id
			print(taskId .. ' loaded from json.')
		end)
	else
		print('unknow paraments '..table.concat({tostring(task), tostring(context_type)}, '/'))
	end

	if p then
		local function ok() return taskId end
		return p:andThen(ok, err)
	end
end

local function run_action(task, context_type)
	if not task or task == '-' then
		task = io.read("*a")
		if not context_type then
			context_type = 'json'
		end
	elseif isTaskId(task) then
		context_type = 'task'
	end

	local p, t
	if not context_type or context_type == 'module' then
		p = loader:loadByModule(task)
	elseif context_type == 'file' then
		p = loader:loadByFile(task)
	elseif context_type == 'script' then
		if string.find(task, '^function[%( ]') then
			local ok, result = pcall(loadstring('return ' .. task))
			if not ok then
				error('cant load script from string:\n==========\n'..task..'\n==========')
			else
				t = result
			end
		else
			p = loader:loadScript(task)
		end
	elseif context_type == 'json' then -- json conext, not json file
		p = loader.publisher:register_task(task)
	elseif context_type == 'task' then
		t = task
	else
		error('unknow paraments '..table.concat({tostring(task), tostring(context_type)}, '/'))
	end

	if p then
		local function run(task) return pedt:run(task, arguments) end
		return p:andThen(run):catch(err)
	elseif t then
		return pedt:run(t, arguments)
	end
end

function help_action()
	if force_list or task_center ~= default_task_center then
		print('Methods:')
		for cmd in pairs(task_center) do
			if not (cmd == 'register_task' or cmd == 'download_task') then
				print('\t - '..cmd)
			end
		end
	else
		print('Usage:')
		print('\tlua pedt.lua <action> [paraments]')
		print('\tlua pedt.lua help')
		print('\tlua pedt.lua')
	end
end

-- main
if action == 'help' then
	help_action()
elseif action == 'add' then
	add_action(task, context_type)
elseif action == 'run' then
	local p = run_action(task, context_type)
	if p then
		p:andThen(function(result) print(JSON_encode(result)) end)
	end
elseif task_center[action] then  -- center methods
	local ok, reason = pcall(task_center[action], arguments)
	if not ok then
		print('error from task center: '..reason)
	end
else
	print('unknow action: '..action)
end
