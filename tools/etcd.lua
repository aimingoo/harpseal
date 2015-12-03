--
-- a simple etcd task_center connector
--
local MD5 = require('lib.MD5').sumhexa
local Promise = require('lib.Promise')
local JSON = require('lib.JSON')
local JSON_decode = function(...) return JSON:decode(...) end
local JSON_encode = function(...) return JSON:encode_pretty(...) end

-- task center at etcd, code from $(ngx_4c)/scripts/n4cDistrbutionTaskNode.lua
local etcdServer = { url = 'http://127.0.0.1:4001/v2/keys/N4C/task_center/tasks' }

local function read_shell(cmd)
	local f = assert(io.popen(cmd), 'cant execute with pipe')
	local response = f:read('*a')
	f:close()
	if not response then
		return false, Promise.reject('cant read from pipe')
	end
	return JSON_decode(response)
end

local function n4c_download_task(taskId)
	local id = string.gsub(taskId, '^task:', "")
	local get = "curl -s '"..etcdServer.url..'/'..id.."'"
	local r, rejected = read_shell(get)

	local taskDef = r and r.node and r.node.value
	if not taskDef then
		return rejected or Promise.reject('cant load taskDef from key: '..id)
	else
		return Promise.resolve(taskDef)
	end
end

local function n4c_register_task(taskDef)
	local id = MD5(tostring(taskDef))
	local put = "curl -s -XPUT --data-urlencode value@- '"..etcdServer.url..'/'..id.."' >/dev/null"
	local f = assert(io.popen(put, 'w'), 'cant execute with pipe')
	f:setvbuf("no")
	local ok, reason = f:write(taskDef)
	f:close()
	if not ok then
		return Promise.reject(reason)
	else
		return Promise.resolve('task:'..id)
	end
end

local function n4c_list_tasks()
	local get = "curl -s '"..etcdServer.url.."'"
	local r, rejected = read_shell(get)

	local nodes = r and r.node and r.node.dir and r.node.nodes
	if not nodes then
		if rejected then
			rejected:catch(print)
		else
			print('cant load tasks from: '..etcdServer.url)
		end
	else
		table.foreachi(nodes, function(i, node)
			print(i, node.key)
		end)
	end
end

local function n4c_show_task(taskId)
	local id = string.gsub(taskId, '^task:', "")
	local get = "curl -s '"..etcdServer.url..'/'..id.."'"
	local r, rejected = read_shell(get)

	local taskDef = r and r.node and r.node.value
	if not taskDef then
		if rejected then
			rejected:catch(print)
		else
			print('cant load taskDef from key: '..id)
		end
	else
		print(JSON_encode(JSON_decode(taskDef)))
	end
end

return {
	download_task = n4c_download_task,
	register_task = n4c_register_task,
	list = n4c_list_tasks,
	show = n4c_show_task,
}