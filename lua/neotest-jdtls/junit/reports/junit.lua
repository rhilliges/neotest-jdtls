local class = require('neotest-jdtls.utils.class')
local log = require('neotest-jdtls.utils.log')
local ResultParserFactory =
	require('neotest-jdtls.junit.results.result-parser-factory')

---@class java_test.JUnitTestReport
---@field private conn uv_tcp_t
---@field private result_parser java_test.TestParser
---@field private result_parser_fac java_test.TestParserFactory
local JUnitReport = class()

function JUnitReport:_init()
	self.conn = nil
	self.result_parser_fac = ResultParserFactory()
end

---Returns the test results
---@return java_test.TestResults[]
function JUnitReport:get_results()
	return self.result_parser:get_test_details()
end

---Returns a stream reader function
---@param conn uv_tcp_t
---@return fun(err: string, buffer: string) # callback function
function JUnitReport:get_stream_reader(conn)
	self.conn = conn
	self.result_parser = self.result_parser_fac:get_parser()
	return vim.schedule_wrap(function(err, buffer)
		if err then
			self.conn:close()
			return
		end

		if buffer then
			self:on_update(buffer)
		else
			self.conn:close()
		end
	end)
end

---Runs on connection update
---@private
---@param text string
function JUnitReport:on_update(text)
	log.trace('on_update', text)
	self.result_parser:parse(text)
end

return JUnitReport
