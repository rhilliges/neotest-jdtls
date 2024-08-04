local adapter = require('neotest-jdtls.neotest.adapter')
local project = require('neotest-jdtls.utils.project')

local group = vim.api.nvim_create_augroup('neotest-jdtls', { clear = true })

vim.api.nvim_create_autocmd({ 'BufWritePost' }, {
	pattern = '*.java',
	callback = project.autocmd_clear_cache,
	group = group,
})

vim.api.nvim_create_user_command(
	'NeotestJdtlsClearProjectCache',
	project.clear_project_cache,
	{}
)

return adapter
