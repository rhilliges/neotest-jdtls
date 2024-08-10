local log = require('neotest-jdtls.utils.log')
local nio = require('nio')

local JDTLS = {}

---@enum TestKind
JDTLS.TestKind = {
	JUnit5 = 0,
	JUnit = 1,
	TestNG = 2,
	None = 100,
}

---@enum TestLevel
JDTLS.TestLevel = {
	Workspace = 1,
	WorkspaceFolder = 2,
	Project = 3,
	Package = 4,
	Class = 5,
	Method = 6,
}

function JDTLS.get_client()
	local clients = nio.lsp.get_clients({ name = 'jdtls' })

	if #clients > 1 then
		error('Could not find any running jdtls clients')
	end

	return clients[1]
end

function JDTLS.root_dir()
	return JDTLS.get_client().config.root_dir
end

---Executes workspace command on jdtls
---@param cmd_info {command: string, arguments: any }
---@param timeout number?
---@param buffer number?
---@return { err: { code: number, message: string }, result: any }
local function execute_command(cmd_info, timeout, buffer)
	timeout = timeout and timeout or 5000
	buffer = buffer and buffer or 0
	log.trace(
		'Executing command:',
		'[' .. cmd_info.command .. ']',
		'with args:',
		vim.inspect(cmd_info.arguments)
	)
	local result = JDTLS.get_client()
		.request_sync('workspace/executeCommand', cmd_info, timeout, buffer)
	log.trace(
		'Command',
		'[' .. cmd_info.command .. ']',
		'executed with result:',
		vim.inspect(result)
	)
	return result
end

--- @param test_file_uri string
--- @return JavaTestItem[]
function JDTLS.find_test_types_and_methods(test_file_uri)
	local java_test_items = execute_command({
		command = 'vscode.java.test.findTestTypesAndMethods',
		arguments = { test_file_uri },
	})
	return java_test_items.result
end

function JDTLS.find_test_packages_and_types_cached_f(jdtHandler)
	if not JDTLS.find_test_packages_and_types_cache then
		JDTLS.find_test_packages_and_types_cache =
			JDTLS.find_test_packages_and_types(jdtHandler)
	end
	return JDTLS.find_test_packages_and_types_cache
end

--- @return JavaTestItem[]
function JDTLS.find_java_projects(root)
	local _, result = JDTLS.get_client().request.workspace_executeCommand({
		command = 'vscode.java.test.findJavaProjects',
		arguments = { vim.uri_from_fname(root) },
	})
	return result
end

function JDTLS.is_test_file(file_path)
	log.debug('is_test_file', file_path)
	local err, result = JDTLS.get_client().request.workspace_executeCommand({
		command = 'java.project.isTestFile',
		arguments = { vim.uri_from_fname(file_path) },
	})
	return err, result
end

--- @param jdtHandler string
--- @return JavaTestItem[]
function JDTLS.find_test_packages_and_types(jdtHandler)
	local _, result = JDTLS.get_client().request.workspace_executeCommand({
		command = 'vscode.java.test.findTestPackagesAndTypes',
		arguments = { jdtHandler },
	})
	return result
end

--- @param arguments JunitLaunchRequestArguments
function JDTLS.get_junit_launch_arguments(arguments)
	local launch_arguments = execute_command({
		command = 'vscode.java.test.junit.argument',
		arguments = vim.fn.json_encode(arguments),
	}).result.body
	return launch_arguments
end

--- @param main_class string
--- @param project_name string
function JDTLS.resolve_java_executable(main_class, project_name)
	local executable = execute_command({
		command = 'vscode.java.resolveJavaExecutable',
		arguments = {
			main_class,
			project_name,
		},
	}).result
	return executable
end

return JDTLS

---@class JavaTestItem
---@field children JavaTestItem[]
---@field uri string
---@field range Range
---@field jdtHandler string
---@field fullName string
---@field label string
---@field id string
---@field projectName string
---@field testKind TestKind
---@field testLevel TestLevel
---@field sortText string
---@field uniqueId string
---@field natureIds string[]
---
---@class Range
---@field start Position
---@field end Position

---@class Position
---@field line number
---@field character number
