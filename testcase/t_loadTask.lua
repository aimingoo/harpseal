---------------------------------------------------------------------------------------------------------
-- Harpseal v1.0
--
-- A example for task loder
-- Usage:
--	# step 1: run server in redpoll with nodejs
--		> git clone https://github.com/aimingoo/redpoll
--		> node redpoll/testcase/t_executor.js
--	# step 2: run the example
--		> luarocks install luasocket
--		> luarocks install copas
--		> git clone https://github.com/aimingoo/harpseal
--		> cd harpseal
--		> lua testcase/t_loadTask.lua
---------------------------------------------------------------------------------------------------------
local Promise = require('lib.Promise')
local httphelper = require('infra.httphelper')
local start_distribution_loop = httphelper.start

local JSON = require('lib.JSON')
local JSON_decode = function(...) return JSON:decode(...) end
local JSON_encode = function(...) return JSON:encode_pretty(...) end

local opt = {
	-- resource_status_center = {},
	task_register_center = require('infra.dbg_register_center'),
	distributed_request = httphelper.distributed_request,
}
local PEDT = require('lib.Distributed')
local pedt = PEDT:new(opt)

---------------------------------------------------------------------------------------------------------
-- for debugger only
---------------------------------------------------------------------------------------------------------
-- error output
local err = function(reason) print('ERR ==>', type(reason) == 'string' and reason or JSON_encode(reason)) end

-- rewrite pedt.map()
local original_map = pedt.map
pedt.map = function(self, distributionScope, taskId, args)
	if distributionScope == '?' then
		return Promise.resolve(args):andThen(function(args)
			return self:execute_task(taskId, rags)
		end)
	end
	return original_map(self, distributionScope, taskId, args)
end

-- fake some scopes for remote nodes, and inject them
local remote_taskId = 'task:c2eb2597e461aa3aa0e472f52e92fe0b'
local full = "redpoll:/com.wandoujia.le/redpoll/demo:*"
local injected_scopes = {
	[full] = Promise.resolve({'http://127.0.0.1:8032/redpoll/execute_'}),
}

---------------------------------------------------------------------------------------------------------
-- testcases
---------------------------------------------------------------------------------------------------------
-- case 1, load and register
--[[-- pedt as publisher, or create unique publisher
	local new_publisher = { register_task = function(_, ...) return pedt:register_task(...)  end }
	local Loader = TaskLoader:new({ publisher = new_publisher })
--]]
print('case 1')
local TaskLoader = require('tools.taskloader')
local Loader = TaskLoader:new({ publisher = pedt })
local taskId = Loader:loadByModule('testcase.tasks.t_task1')

-- case 2, execute it
print("INFO1:", taskId, type(taskId))
pedt:run(taskId):andThen(JSON_encode):andThen(print, err)
-- opt.task_register_center.report()

-- case 3, map/reduce
-- 	*) inject test scopes
pedt:upgrade({ system_route = injected_scopes })
-- 	*) map to remote and reduce at local
local reduceFunc = function(_, mapedResults)
	print('recude result:', JSON_encode(mapedResults))
	return true -- return recuded value
end
pedt:reduce(full, remote_taskId, {a=1, b=2, p1="new value"}, reduceFunc):andThen(print, err)

-- loop for copas
start_distribution_loop()
