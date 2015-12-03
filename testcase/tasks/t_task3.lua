local task = def:map('?', 'testcase.tasks.t_task4')
local taskId = task.map
print('try preload task4, id:\n\t', taskId)
-- print('try preload task4, id:\n\t', JSON_encode(task))

return {
	z = def:run(function(self)
		print("hi")
	end),

	zz1 = def:run(taskId),
	zz2 = taskId,
	-- zz3 = task,

	-- array of task
	m = {
		def:map('?', 'testcase.tasks.t_task4'),
		def:reduce('?', 'testcase.tasks.t_task4', function(self)end),
		def:run(function(self)end),
	},

	distributed = function(_, taskDef)
		print('distributed in t_task3')
	end,

	promised = function(_, taskOrder)
		print('promised in t_task3')
	end
}