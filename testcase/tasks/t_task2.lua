return {
	y = def:reduce("?", "testcase.tasks.t_task3", function(_, result)
		return 'HI'
	end)
}