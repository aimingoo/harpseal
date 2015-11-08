#harpseal
harpseal is implement of PEDT - Parallel Exchangeable Distribution Task specifications for lua.

PEDT v1.1 specifications supported.

#install
> git clone https://github.com/aimingoo/harpseal

or
> luarocks install harpseal

#import and usage
```lua
var Harpseal = require('harpseal');
var options = {};
var pedt = Harpseal:new(options);

pedt:run(..)
	:andThen(function(result){
		..
	})
```

# options
the full options schema:
```lua
options = {
	distributed_request = function(arrResult) .. end, -- a http client implement
	system_route = { .. }, -- any key/value pairs
	task_register_center = {
		download_task = function(taskId) .. end, -- PEDT interface
		register_task = function(taskDef) .. end,  -- PEDT interface
	},
	resource_status_center = {
		require = function(resId) .. end,-- PEDT interface
	}
}
```

# interfaces
> for detail, @see ${harpseal}/infra/specifications/*
> for Promise in lua, @see [https://github.com/aimingoo/Promise](https://github.com/aimingoo/Promise)

all interfaces are promise supported except pedt.upgrade() and helpers.

## pedt:run
```lua
function pedt:run(task, args)
```
run a task (taskId, function or taskObject) with args.

## pedt.map
```lua
function pedt:map(distributionScope, taskId, args)
```
map taskId to distributionScope with args, and get result array.

distributionScope will parse by pedt.require().

## pedt.execute_task
```lua
function pedt:execute_task(taskId, args)
```
run a taskId with args. pedt.run(taskId) will call this.

## pedt.register_task
```lua
function pedt:register_task(task)
```
run a task and return taskId.

the "task" is a taskDef text or local taskObject.

## pedt.require
```lua
function pedt:require(token)
```
require a resource by token. the token is distributionScope or system token, or other.

this is n4c expanded interface, resource query interface emmbedded.

## pedt.upgrade
```javascript
this.upgrade = function(newOptions)
```
upgrade current Harpseal/PEDT instance with newOptions. @see [options](#options)

this is harpseal expanded interface.

## helpers

some tool/helpers include in the package.

### Harpseal.infra.taskhelper
```lua
local Harpseal = require('harpseal');
local def = Harpseal.infra.taskhelper;
-- or
-- local def = require('harpseal.infra.taskhelper');

local taskDef = {
	x = def:run(...),
	y = def:map(...),
	...
}
```
a taskDef define helper. @see:
> $(harpseal)/testcase/t_loadTask.lua

### Harpseal.infra.httphelper
```lua
local Harpseal = require('harpseal');
local httphelper = Harpseal.infra.httphelper;
-- or
-- local httphelper = require('harpseal.infra.httphelper');

local options = {
	...,
	distributed_request = httphelper.distributed_request
}

-- (...)
-- (in your business or main, call these)
httphelper.start()
```
a recommented/standard distributed request, and activate copas parallel loop with call .start() method in your code.

### Harpseal.tools.taskloader
```lua
local Harpseal = require('harpseal');
local TaskLoader = Harpseal.tools.taskloader;
-- or
-- local TaskLoader = require('harpseal.tools.taskloader');

-- need a register center
--	*) you can copy dbg_register_center.lua to your project folder from $(harpseal)/infra/.
local pedt = Harpseal:new({
	task_register_center = require(..),
})
local loader = TaskLoader:new({ publisher = pedt })

-- load task by lua module name
--	*) with depth of the discover
local taskId = loader:loadByModule('testcase.tasks.t_task1')
..
```
a task loader tool, will load tasks by module name of taskDef file, with depth discovery for all members. @see:
> $(harpseal)/testcase/t_loadTask.lua

# testcase
try these:
```bash
> # launch redpoll as service, require NodeJS
> # (for test only)
> git clone https://github.com/aimingoo/redpoll
> node redpoll/testcase/t_executor.js

> # start new shell and continue
> luarocks install luasocket
> luarocks install copas
> git clone 'https://github.com/aimingoo/harpseal'
> cd harpseal
> lua testcase/t_loadTask.lua
```

# history
```text
	2015.11.08	v1.0.0 released.
```