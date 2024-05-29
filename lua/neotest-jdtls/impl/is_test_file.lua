local M = {}

M.is_test_file = function(file_path)
	local is_test_file = string.find(file_path, 'test') ~= nil
		and string.find(file_path, '.java') ~= nil
		and string.find(file_path, '.class') == nil
	return is_test_file
end

return M
