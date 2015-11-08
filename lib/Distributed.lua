---------------------------------------------------------------------------------------------------------
-- Distributed processing module in lua v1.0.0
-- Author: aimingoo@wandoujia.com
-- Copyright (c) 2015.10
--
-- The distributed processing module from NGX_4C architecture
--	1) N4C is programming framework.
--	2) N4C = a Controllable & Computable Communication Cluster architectur.
--
-- Usage:
--	register	: register_task()
--	executer	: execute_task(), run() 
--		*) limited executer		: run task at local only, distributed "taskId" is unsupported.
--			status - offline	: can read local and/or remote configuration, support local tasks.
--			status - online		: run as http client and send heartbeat to owner/supervision node or service(Etcd etc.)
--		*) unlimited executer	: accept remote task requrie, download(or load cached) and execute it.
--	dispatcher	: map()
--		*) task mapper			: it's limited task dispatcher, task proxy/redirect only, or daemon launcher.
--		*) task dispatcher 		: dispatch and run local and remote task, unlimited executer.
---------------------------------------------------------------------------------------------------------
local Promise = require('lib.Promise')

local mod_prefix = ({...})[1]
if mod_prefix then
	if mod_prefix == 'lib.Distributed' then -- hard load
		mod_prefix = ''
	else -- load by luarocks
		mod_prefix = mod_prefix .. '.'
	end
end
local def = require(mod_prefix .. 'infra.taskhelper')

local JSON = require('lib.JSON')
local JSON_decode = function(...) return JSON:decode(...) end
local JSON_encode = function(...) return JSON:encode_pretty(...) end

local reserved_tokens = {
	["?"]	= Promise.reject("unhandled placeholder '?'"),
	["::*"]	= Promise.reject("unhandled placeholder '::*'"),
	["::?"]	= Promise.reject("argument distributionScope scopePart invalid"),
	[":::"]	= Promise.reject("argument distributionScope invalid")
}

local invalid_task_center = {
	download_task = function(taskId) return Promise.reject('current node is not unlimited executer') end,
	register_task = function(taskDef) return Promise.reject('current node is not publisher') end
}

local invalid_resource_center = {
	require = function(resId) return Promise.reject('current node is not dispatcher') end
}

local invalid_promised_request = function(arrResult)
	return Promise.reject('promised request is unsupported at current node')
end

-- mix/copy fields from ref to self
local function mix(self, ref, expanded)
	if ref == nil then return self end

	if type(ref) == 'function' then return expanded and ref or nil end
	if type(ref) ~= 'table' then return ref end

	self = (type(self) == 'table') and self or {}
	for key, value in pairs(ref) do
		self[key] = mix(self[key], value, expanded)
	end
	return self
end

-- ex:
--	local obj = {}, f = function(self, a, b) self.A=a; self.B=b end
--	local ff = bind(f, obj)
--	ff(1,2) // non-self
local function bind(...)
	local function with_arguments(t, ...) return t[1](t[2], ...) end
	local function ignore_arguments(t) return t[1](select(2, unpack(t))) end
	return setmetatable({...}, {
		__call = (#{...} > 2) and ignore_arguments or with_arguments
	})
end

---------------------------------------------------------------------------------------------------------
--	meta promisedTask core utils
---------------------------------------------------------------------------------------------------------

local function isTaskId(str)
	return (string.len(str)==5+32) and string.match(str, '^task:')
end

local function isDistributedTask(obj)
	return ((type(obj.map) == 'string') and isTaskId(obj.map) and (obj.scope ~= nil))
		or ((type(obj.run) == 'string') and isTaskId(obj.run))
		or ((type(obj.run) == 'table'))
		or ((type(obj.run) == 'function'))
end

local function isDistributedTasks(arr)
	for _, value in ipairs(arr) do
		if isDistributedTask(value) then
			return true
		end
	end
	return false
end

local function promise_arguments(t) return t.arguments end
local function promise_distributed_task(worker, task)
	-- task as taskDef, rewrite task.arguments
	local args = task.arguments and isDistributedTask(task.arguments) and worker:run(task):andThen(promise_arguments) or task.arguments;
	if task.run ~= nil then
		return worker:run(task.run, args)
	elseif task.map ~= nil then
		return worker:map(task.scope, task.map, args)
	else
		return Promise.reject("none distribution method in taskDef");
	end
end

local function promise_distributed_tasks(worker, arr)
	local tasks = {}
	for _, value in ipairs(arr) do
		table.insert(tasks, isDistributedTask(value) and promise_distributed_task(worker, value) or value)
	end
	-- assert(next(tasks), 'try distribution empty tasks')
	return Promise.all(tasks)
end

-- rewrite members
local function promise_member_rewrite(promised)
	local taskOrder = table.remove(promised) -- pop taskOrder
	local keys = assert(taskOrder.promised.keys, 'cant find promised.keys in metatable')
	for i, key in ipairs(keys) do
		taskOrder[key] = promised[i]
	end
	return Promise.resolve(taskOrder)
end

-- promise all members
local function promise_static_member(worker, picker, order)
	local fakeOrder = function(obj) return setmetatable({}, {__index=obj}) end
	local promised = order.promised
	if promised then
		local promises, keys = {}, promised.keys
		if keys then
			for i, key in pairs(keys) do
				local value = promised[i]
				if isDistributedTask(value) then
					table.insert(promises, promise_distributed_task(worker, value))
				elseif #value > 0 then
					table.insert(promises, promise_distributed_tasks(worker, value))
				else
					-- assert(promise_static_member(value), 'invalid value promised')
					table.insert(promises, promise_static_member(worker, picker, fakeOrder(value)))
				end
			end
			table.insert(promises, order) -- push order
			return Promise.all(promises):andThen(promise_member_rewrite):andThen(picker)
		else
			-- assert(promised.promised, 'no promised method and promises')
			return Promise.resolve(order):andThen(picker)
		end
	end
end

local function getTaskResult(worker, taskOrder)
	return (taskOrder.promised and taskOrder.promised.promised) and taskOrder.promised.promised(worker, taskOrder) or taskOrder
end

local function extractTaskResult(taskOrder)
	if #taskOrder > 0 then
		for _, item in ipairs(taskOrder) do
			if type(item)=='table' then extractTaskResult(item) end
		end
	else
		local meta = getmetatable(taskOrder)
		if meta then
			local taskDef = assert(meta.__index, 'invalid taskOrder') -- @see makeTaskOrder() and makeTaskMetaTable()
			if taskDef.promised and taskDef.promised.keys then -- rewrited
				for _, result in pairs(taskOrder) do
					if type(result) == 'table' then extractTaskResult(result) end
				end
			end
			for key, result in pairs(taskDef) do
				if ((key ~= 'promised') and (key ~= 'distributed') and
					(type(result) ~= 'function') and (rawget(taskOrder, key) == nil)) then
					taskOrder[key] = result
				end
			end
		end
		return taskOrder
	end
end

local function extractMapedTaskResult(results)
	-- the <result> resolved with {body: body, headers: response.headers}
	--	*) @see request.get() in distributed_request()
	local maped = {}
	for i, result in ipairs(results) do
		local ok, result = pcall(JSON_decode, result.body)
		if not ok then
			return  Promise.reject({index=i, reason="JSON decode error of: " .. result})
		end
		maped[i] = result
	end
	return maped
end

-- scan static members and preprocess
local function preProcessMembers(obj)
	local keys, promised = {}, {}
	for key, value in pairs(obj) do
		if type(value) == 'table' then
			if isDistributedTask(value) or isDistributedTasks(value) then
				table.insert(keys, key)
				table.insert(promised, value)
				obj[key] = nil
			else
				local p = preProcessMembers(value)
				if p then
					table.insert(keys, key)
					table.insert(promised, p)
					obj[key] = nil
				end
			end
		end
	end

	if #keys > 0 then
		promised.keys = keys
	end

	if obj.promised then
		promised.promised = obj.promised
	end

	if next(promised) ~= nil then
		obj.promised = promised
		return obj
	end
end

---------------------------------------------------------------------------------------------------------
-- MetaPromisedTask
---------------------------------------------------------------------------------------------------------

-- meta promisedTask
local MetaPromisedTask = {
	__call = function(t, resolve, reject)
		local worker, order = unpack(t)
		local picker = bind(getTaskResult, worker)
		return Promise.resolve(promise_static_member(worker, picker, order) or order):andThen(resolve, reject)
	end
}

-- get a promisedTask
local function makeTaskMetaTable(taskDef)
	return { __index = taskDef }
end

-- make original taskOrder
local function makeTaskOrder(meta)
	return setmetatable({}, meta)
end

local function asPromisedTask(...)
	return setmetatable({ ... }, { __call=MetaPromisedTask.__call })
end

---------------------------------------------------------------------------------------------------------
-- internal methods
---------------------------------------------------------------------------------------------------------
local GLOBAL_CACHED_TASKS = {}

-- need prebind context to self
local function distributed_task(worker, taskDef)
	local taskObject = def.decode(taskDef)

	if taskObject.distributed then
		taskObject.distributed(worker, taskObject)
	end

	-- preprocess members
	preProcessMembers(taskObject)
	return taskObject
end

local function inject_default_handles(opt)
	if not opt.task_register_center then
		opt.task_register_center = invalid_task_center
	else
		local center = opt.task_register_center;
		if not center.download_task then center.download_task = invalid_task_center.download_task end
		if not center.register_task then center.register_task = invalid_task_center.register_task end
	end

	if not opt.resource_status_center then
		opt.resource_status_center = invalid_resource_center
	else
		local center = opt.resource_status_center;
		if not center.require then center.require = invalid_resource_center.require end
	end

	return opt
end

local function internal_parse_scope(self, center, distributionScope)
	-- "?" or "*" is filted by self.require()
	if string.len(distributionScope) < 4 then return self:require(":::") end

	-- systemPart:pathPart:scopePart
	--	*) rx_tokens = /^([^:]+):(.*):([^:]+)$/
	local parts, scopePart = string.match(distributionScope, '^(.*):([^:]+)$')
	if not parts then return self:require(":::") end

	-- TODO: dynamic scopePart parser, the <parts> is systemPart:pathPart
	return ((scopePart == '?') and self:require("::?")
		or ((scopePart == '*') and Promise.resolve(center.require(parts))
		or Promise.reject("dynamic scopePart is not support")));
end

local function internal_download_task(self, center, taskId)
	local WORKER_CACHED_TASKS = GLOBAL_CACHED_TASKS[self] or {}
	local function cached_as_promise(taskDef)
		if not taskDef then
			return Promise.reject('unknow taskId in D.execute_task()')
		end

		local resolved_taskMeta = Promise.resolve(makeTaskMetaTable(taskDef))
		WORKER_CACHED_TASKS[taskId] = resolved_taskMeta
		return resolved_taskMeta
	end

	return WORKER_CACHED_TASKS[taskId]
		or Promise.resolve(center.download_task(taskId)):andThen(bind(distributed_task, self)):andThen(cached_as_promise);
end

-- need prebind context to self
local function internal_execute_task(self, taskMeta)
	-- local worker, args = unpack(self)
	local taskOrder = mix(makeTaskOrder(taskMeta), self[2]);
	return Promise.new(asPromisedTask(self[1], taskOrder))
end

-- -------------------------------------------------------------------------------------------------------
-- Distributed processing methods
-- 	*) return promise object by these methods
-- 	*) MUST: catch error by caller for these interfaces
-- -------------------------------------------------------------------------------------------------------
local D = setmetatable({}, {__index=def})
if mod_prefix then
	D.infra = {
		taskhelper = require(mod_prefix..'infra.taskhelper'),
		httphelper = require(mod_prefix..'infra.httphelper'),
	}
	D.tools = {
		taskloader = require(mod_prefix..'tools.taskloader'),
	}
end

function D:run(task, args)
	local t = type(task)
	if t == 'function' then
		-- direct call, or call from promise_distributed_task()
		return Promise.resolve(args):andThen(bind(task, self))
	elseif (t == 'string') and isTaskId(task) then
		-- execute registed taskDef with taskId
		return Promise.resolve(args):andThen(function(args)
			return self:execute_task(task, args)
		end)
	elseif t == 'table' then
		-- run local taskObject, will skip decode and ignore taskDef.distributed()
		local taskDef = preProcessMembers(task) or task
		local taskMeta = makeTaskMetaTable(taskDef)
		local taskOrder = mix(makeTaskOrder(taskMeta), args)
		return Promise.new(asPromisedTask(self, taskOrder))
			:andThen(extractTaskResult)
	else
		return Promise.reject('unknow task type "' .. t .. '" in Distributed.run()')
	end
end

function D:map(distributionScope, taskId, args)
	return Promise.all({self:require(distributionScope), taskId, args})
		:andThen(self.distributed_request)
		:andThen(extractMapedTaskResult)
end

return {
	new = function(_, opt)
		local instance = setmetatable({},  { __index = D });
		local options = { system_route = setmetatable({}, { __index = reserved_tokens }) };

		local function system_route(token)
			return options.system_route[token]
		end

		function instance:upgrade(newOptions)
			inject_default_handles(mix(options, newOptions, true))
			if newOptions.distributed_request then -- is update
				self.distributed_request = options.distributed_request
			end
		end

		function instance:require(token)
			return Promise.resolve(system_route(token) or
				internal_parse_scope(self, options.resource_status_center, token))
		end

		function instance:execute_task(taskId, args)
			return internal_download_task(self, options.task_register_center, tostring(taskId))
				:andThen(bind(internal_execute_task, {self, args})):andThen(extractTaskResult)
		end

		function instance:register_task(task)
			return Promise.resolve(options.task_register_center.register_task(
				(type(task) == 'string') and task or def.encode(task)))
		end

		-- set defaults and return instance
		GLOBAL_CACHED_TASKS[instance] = {}
		instance.distributed_request = invalid_promised_request
		instance:upgrade(opt)
		return instance;
	end
}