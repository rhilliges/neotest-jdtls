local async = require('neotest.async')
local log = require('neotest-jdtls.log')
local lib = require('neotest.lib')

local M = {}

local TestStatus = {
	Failed = 'failed',
	Skipped = 'skipped',
	Passed = 'passed',
}

local function get_result_from_ch_node(ch)
	if ch.result.status == TestStatus.Failed then
		local results_path = async.fn.tempname()
		lib.files.write(results_path, table.concat(ch.result.trace, '\n'))
		log.debug('stream_path: ', results_path)
		return {
			status = TestStatus.Failed,
			errors = {
				{ message = ch.result.trace[1] },
			},
			output = results_path,
			short = ch.result.trace[1],
		}
	elseif ch.result.status == TestStatus.Skipped then
		return {
			status = TestStatus.Skipped,
		}
	else
		local results_path = async.fn.tempname()
		local log_data
		if ch.result.trace then
			log_data = table.concat(ch.result.trace, '\n')
		else
			log_data = 'Test passed (There is no output available)'
		end
		lib.files.write(results_path, log_data)
		return {
			status = TestStatus.Passed,
			output = results_path,
		}
	end
end

---@param spec neotest.RunSpec
---@param result neotest.StrategyResult
---@param tree neotest.Tree
function M.results(spec, _, tree)
	local result_map = {}
	local report = spec.context.report:get_results()
	for _, item in ipairs(report) do
		log.debug('item: ', item)
		for _, ch in ipairs(item.children) do
			local key = vim.split(ch.display_name, '%(')[1]
			result_map[key] = get_result_from_ch_node(ch)
		end
	end
	local results = {}
	for _, node in tree:iter_nodes() do
		local node_data = node:data()
		local node_result = result_map[node_data.name]
		if node_result then
			results[node_data.id] = node_result
		end
	end
	return results
end

return M
