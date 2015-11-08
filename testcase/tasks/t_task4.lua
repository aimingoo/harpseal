return {
	name = 'order',
	ding = {
		name = 'field: order.ding',
		-- in multi-levels or sub-objects
		n = def:run(function(self)
			print("task4 done, and self is " .. (self and self.name or 'unsupported'))
			return 'done.'
		end)
	}
}