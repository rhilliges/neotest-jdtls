local log = require('neotest-jdtls.utils.log')
local project = require('neotest-jdtls.utils.project')

local M = {}

M.is_test_file = function(file_path)
	local path = vim.uri_from_fname(file_path)
	local is_test_file = false

	local current_project = project.get_current_project()
	if current_project.classes[path] then
		is_test_file = true
	end
	log.debug('is_test_file result: ', file_path, path, is_test_file)
	return is_test_file
end

return M
