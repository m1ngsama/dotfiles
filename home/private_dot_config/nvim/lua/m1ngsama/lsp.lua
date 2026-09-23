local M = {}

function M.toggleInlayHints()
	local filter = { bufnr = 0 }
	vim.lsp.inlay_hint.enable(not vim.lsp.inlay_hint.is_enabled(filter), filter)
end

return M
