local log = require('neotest-jdtls.utils.log')
local jdtls = require('neotest-jdtls.utils.jdtls_nio')
-- local project = require('neotest-jdtls.utils.project')
local M = {}

M.is_test_file = function(file_path)
	-- check if file is a test file with project cache
	-- local path = vim.uri_from_fname(file_path)
	-- local is_test_file = false
	--
	-- local current_project = project.get_current_project(path)
	-- if current_project.classes[path] then
	-- 	is_test_file = true
	-- end
	-- log.debug('is_test_file result: ', file_path, path, is_test_file)

	-- check if file is a test file with jdtls request
	local err, is_test_file = jdtls.is_test_file(file_path)
	if err then
		log.error('is_test_file error: ', file_path, err)
		return false
	end
	log.debug('is_test_file result: ', file_path, is_test_file)
	return is_test_file
end

return M
