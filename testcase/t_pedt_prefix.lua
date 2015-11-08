---------------------------------------------------------------------------------------------------------
-- A example for task prefix analyses
---------------------------------------------------------------------------------------------------------
local def = require('infra.taskhelper')
local JSON = require('lib.JSON')
local print_json = function(...) print(JSON:encode_pretty(...)) end

print_json(def.decode('{"x": "data:Hello World!"}'))
print_json(def.decode('{"x": "data:string:utf8:Hello World!"}'))
print_json(def.decode('{"x": "data:base64:SGVsbG8gV29ybGQh"}'))
print_json(def.decode('{"x": "data:string:base64:SGVsbG8gV29ybGQh"}'))
