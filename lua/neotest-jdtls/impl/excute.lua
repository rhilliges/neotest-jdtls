local data_adapters = require('java-core.adapters')
local ReportViewer = require('java-test.ui.floating-report-viewer')
local ResultParserFactory = require('java-test.results.result-parser-factory')
local JUnitReport = require('java-test.reports.junit')
local log = require('neotest-jdtls.log')
local execute_command = require('neotest-jdtls.utils').execute_command
local nio = require('nio')

local M = {}

local TestLevel = {
	Workspace = 1,
	WorkspaceFolder = 2,
	Project = 3,
	Package = 4,
	Class = 5,
	Method = 6,
}

local function setup(server, dap_launcher_config, report)
	server:bind('127.0.0.1', 0)
	server:listen(128, function(err)
		assert(not err, err)
		local sock = assert(vim.loop.new_tcp(), 'uv.new_tcp must return handle')
		server:accept(sock)
		local success = sock:read_start(report:get_stream_reader(sock))
		assert(success == 0, 'failed to listen to reader')
	end)
	dap_launcher_config.args = dap_launcher_config.args:gsub(
		'-port ([0-9]+)',
		'-port ' .. server:getsockname().port
	)
	return dap_launcher_config
end

--- @param java_test_item JavaTestItem
--- @return JunitLaunchRequestArguments
local function handle_test(data, java_test_item)
	---@type JavaTestItem
	local closest_item = nil
	local start_line = data.range[1] + 1
	for _, children in ipairs(java_test_item.children) do
		if children.range.start.line == start_line then
			closest_item = children
			break
		end
		closest_item = children
	end
	return {
		projectName = closest_item.projectName,
		testLevel = TestLevel.Method,
		testKind = closest_item.testKind,
		testNames = { closest_item.jdtHandler },
	}
end

--- @param java_test_item JavaTestItem
--- @return JunitLaunchRequestArguments
local function handle_file(java_test_item)
	local m = nil
	local testNames = {}
	for _, children in ipairs(java_test_item.children) do
		table.insert(testNames, children.jdtHandler)
		if m == nil then
			m = children
		end
	end
	return {
		projectName = m.projectName,
		testLevel = TestLevel.Class,
		testKind = m.testKind,
		testNames = { vim.split(m.fullName, '#')[1] },
	}
end

local function shutdown_server(server)
	if server then
		server:shutdown()
		server:close()
		log.debug('server closed')
	end
end

local function run_test(dap_launcher_config, server)
	local event = nio.control.event()
	vim.schedule(function()
		require('dap').run(dap_launcher_config, {
			after = function(_)
				shutdown_server(server)
				event.set()
			end,
		})
	end)
	event.wait()
end

--- @return ResolvedMainClass
local function resolve_main_class()
	local class_list = execute_command({
		command = 'vscode.java.resolveMainClass',
		arguments = nil,
	}).result
	assert(#class_list > 0, 'No main class found')
	return class_list[1]
end

---@return JavaTestItem
---@param test_file_uri string
local function get_java_test_item(test_file_uri)
	---@type JavaTestItem
	local java_test_items = execute_command({
		command = 'vscode.java.test.findTestTypesAndMethods',
		arguments = { test_file_uri },
	}).result
	assert(#java_test_items == 1, 'Too many test items found')
	return java_test_items[1]
end

---@param test_file_uri string
---@return JunitLaunchRequestArguments
local function resolve_junit_launch_arguments(data, test_file_uri)
	if
		data.type ~= 'test'
		and data.type ~= 'file'
		and data.type ~= 'namespace'
	then
		error('Unsupported test type: ' .. data.type)
	end

	local java_test_item = get_java_test_item(test_file_uri)
	---@type JunitLaunchRequestArguments
	local arguments
	if data.type == 'test' then
		arguments = handle_test(data, java_test_item)
	else
		-- file and namespace
		arguments = handle_file(java_test_item)
	end
	local launch_arguments = execute_command({
		command = 'vscode.java.test.junit.argument',
		arguments = vim.fn.json_encode(arguments),
	}).result.body

	return launch_arguments
end

---@param args neotest.RunArgs
---@return neotest.RunSpec
function M.build_spec(args)
	local strategy = args.strategy
	local tree = args and args.tree
	local data = tree:data()
	log.debug('data', vim.inspect(data))

	local resolved_main_class = resolve_main_class()
	local test_file_uri = vim.uri_from_fname(data.path)
	log.debug('file_uri', test_file_uri)

	local executable = execute_command({
		command = 'vscode.java.resolveJavaExecutable',
		arguments = {
			resolved_main_class.mainClass,
			resolved_main_class.projectName,
		},
	}).result

	local junit_launch_arguments =
		resolve_junit_launch_arguments(data, test_file_uri)

	local is_debug = strategy == 'dap'
	local dap_launcher_config =
		data_adapters.get_dap_launcher_config(junit_launch_arguments, executable, {
			debug = is_debug,
			label = 'Launch All Java Tests',
		})

	local report = JUnitReport(ResultParserFactory(), ReportViewer())
	local server = assert(vim.loop.new_tcp(), 'uv.new_tcp() must return handle')
	dap_launcher_config = setup(server, dap_launcher_config, report)

	local config = {}
	if not is_debug then
		run_test(dap_launcher_config, server)
		log.debug('sessions', vim.inspect(require('dap').session()))
	else
		dap_launcher_config.after = function()
			vim.schedule(function()
				shutdown_server(server)
			end)
		end
		config = dap_launcher_config
	end

	local context = {
		file = data.path,
		pos_id = data.id,
		type = data.type,
		report = report,
	}
	local response = {
		context = context,
		strategy = config,
	}
	return response
end

return M

--- @class JunitLaunchRequestArguments
--- @field projectName string
--- @field testLevel number
--- @field testKind string
--- @field testNames string[]

---@class ResolvedMainClass
---@field mainClass string
---@field projectName string

---@class JavaTestItem
---@field children JavaTestItem[]
---@field uri string
---@field range Range
---@field jdtHandler string
---@field fullName string
---@field label string
---@field id string
---@field projectName string
---@field testKind number
---@field testLevel number
---@field sortText string|nil
---@field uniqueId string|nil
---@field natureIds string[]|nil

---@class Range
---@field start Position
---@field end Position

---@class Position
---@field line number
---@field character number
