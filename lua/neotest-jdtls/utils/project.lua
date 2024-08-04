local log = require('neotest-jdtls.utils.log')
local jdtls = require('neotest-jdtls.utils.jdtls')
local class = require('neotest-jdtls.utils.class')
local nio = require('nio')

local M = {
	project_cache = nil,
	project_load_event = nio.control.event(),
}

--- @class ProjectCache
--- @field longestTestFolder string
--- @field packages table<string, JavaTestItem[]> -- <uri,JavatestItem[]>
--- @field classes table<string, JavaTestItem[]> -- <uri,JavatestItem[]>
--- @field methods table<string, JavaTestItem[]> -- <uri,JavatestItem[]>
--- @field root_dir string
local ProjectCache = class()

function ProjectCache:_init()
	self.longestTestFolder = ''
	self.packages = {}
	self.classes = {}
	self.methods = {}
end

local function load_current_project()
	local event = nio.control.event()
	vim.schedule(function()
		log.debug('Load project cache')
		local cache = ProjectCache()

		local project = jdtls.find_java_projects()
		assert(#project == 1)
		local jdtHandler = project[1].jdtHandler

		local data = jdtls.find_test_packages_and_types(jdtHandler)
		for _, package in ipairs(data) do
			if package.testLevel == 4 or package.testLevel == 3 then
				cache.packages[package.uri] = {
					package = package,
				}
				if #package.uri > #cache.longestTestFolder then
					cache.longestTestFolder = package.uri
				end

				for _, child in ipairs(package.children) do
					cache.classes[child.uri] = {
						classes = child,
					}
				end
			end
		end
		M.project_cache = cache
		event.set()
	end)
	return event
end

--- @return ProjectCache
function M.get_current_project()
	if not M.project_cache then
		load_current_project().wait()
		return M.project_cache
	else
		return M.project_cache
	end
end

function M.autocmd_clear_cache()
	if not M.project_cache then
		return
	end
	local buf = vim.api.nvim_get_current_buf()
	local bufname = vim.api.nvim_buf_get_name(buf)
	local path = vim.uri_from_fname(bufname)
	log.debug('cache infot', bufname, buf, path)
	if not M.project_cache.classes[path] then
		M.project_cache = nil
		log.debug('cache cleared')
	else
		log.debug('skip cache clear')
	end
end

function M.clear_project_cache()
	M.project_cache = nil
end

return M
