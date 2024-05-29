local M = {}

local excluded_directories = {
	'target',
	'build',
	'out',
	'bin',
	'resources',
	'main',
}

M.filter_dir = function(name, rel_path, _)
	if vim.tbl_contains(excluded_directories, name) then
		return false
	end

	if name == rel_path then
		return true
	end

	-- if vim.endswith(rel_path, name) then
	--
	-- 	return true
	-- end

	if string.find(rel_path, 'test') then
		return true
	end
	return false
end

return M
