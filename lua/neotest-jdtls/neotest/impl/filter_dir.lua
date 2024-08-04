local log = require('neotest-jdtls.utils.log')
local project = require('neotest-jdtls.utils.project')

local M = {}

M.filter_dir = function(name, rel_path, root)
	local path = vim.uri_from_fname(root .. '/' .. rel_path)
	log.debug('filter_dir check:', name, rel_path, path)
	local path_ok = false

	local current_project = project.get_current_project()
	if current_project.packages[path] then
		path_ok = true
	else
		if #current_project.longestTestFolder > #path then
			path_ok = vim.startswith(current_project.longestTestFolder, path)
		end
	end
	log.debug('filter_dir result:', name, rel_path, path_ok)
	return path_ok
end

return M
