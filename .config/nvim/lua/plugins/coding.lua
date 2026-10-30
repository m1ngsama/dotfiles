return {
	{
		"smjonas/inc-rename.nvim",
		cmd = "IncRename",
		config = true,
	},

	{
		"nvim-mini/mini.bracketed",
		event = "BufReadPost",
		config = function()
			local bracketed = require("mini.bracketed")
			bracketed.setup({
				file = { suffix = "" },
				window = { suffix = "" },
				quickfix = { suffix = "" },
				yank = { suffix = "" },
				treesitter = { suffix = "n" },
			})
		end,
	},

	{
		"monaqa/dial.nvim",
    -- stylua: ignore
    keys = {
      { "<C-a>", function() return require("dial.map").inc_normal() end, expr = true, desc = "Increment" },
      { "<C-x>", function() return require("dial.map").dec_normal() end, expr = true, desc = "Decrement" },
    },
		config = function()
			local augend = require("dial.augend")
			require("dial.config").augends:register_group({
				default = {
					augend.integer.alias.decimal,
					augend.integer.alias.hex,
					augend.date.alias["%Y/%m/%d"],
					augend.constant.alias.bool,
					augend.semver.alias.semver,
					augend.constant.new({ elements = { "let", "const" } }),
				},
			})
		end,
	},

	{
		"zbirenbaum/copilot.lua",
		opts = function()
			local node = vim.env.COPILOT_NODE_COMMAND
			if not node and vim.fn.has("mac") == 1 then
				local data = vim.env.XDG_DATA_HOME or vim.fn.expand("~/.local/share")
				local nodes = vim.fn.glob(data .. "/nvm/v*/bin/node", false, true)
				local function version(path)
					return vim.fs.basename(vim.fs.dirname(vim.fs.dirname(path)))
				end
				table.sort(nodes, function(a, b)
					return vim.version.cmp(version(a), version(b)) > 0
				end)
				for _, path in ipairs(nodes) do
					if vim.version.ge(version(path), "22.0.0") and vim.fn.executable(path) == 1 then
						node = path
						break
					end
				end
			end
			return {
				copilot_node_command = node or "node",
				suggestion = {
					auto_trigger = true,
					keymap = {
						accept = "<C-l>",
						accept_word = "<M-l>",
						accept_line = "<M-S-l>",
						next = "<M-]>",
						prev = "<M-[>",
						dismiss = "<C-]>",
					},
				},
				filetypes = {
					markdown = true,
					help = true,
				},
			}
		end,
	},
}
