--[[ stardand load processes：
	1) register center connection
		local TaskLoader = require('infra.taskloader')
		local opt = { .. } -- some options of RegisterCenter server
		local loader = TaskLoader:new(opt)
		local taskId = loader:load_object(aTaskObject)
	2) get helper and call map()/reduce()
		local def = require('infra.taskhelper')
		def:map('?', taskId)
--]]

return {
	x = def:map("?", "testcase.tasks.t_task2")
}