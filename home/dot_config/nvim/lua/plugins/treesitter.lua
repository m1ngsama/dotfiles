local function extend_unique(target, additions)
	local seen = {}
	for _, item in ipairs(target) do
		seen[item] = true
	end
	for _, item in ipairs(additions) do
		if not seen[item] then
			table.insert(target, item)
			seen[item] = true
		end
	end
end

return {
	{
		"nvim-treesitter/nvim-treesitter",
		-- LazyVim's build hook and its config hook can both request
		-- tree-sitter-cli during a cold install. Keep one serialized path: the
		-- config hook installs the CLI first, then the requested parsers.
		build = false,
		init = function()
			vim.filetype.add({
				extension = {
					mdx = "mdx",
				},
			})
			vim.treesitter.language.register("markdown", "mdx")
		end,
		opts = function(_, opts)
			if vim.g.dotfiles_benchmark == 1 then
				opts.ensure_installed = {}
				return
			end
			opts.ensure_installed = opts.ensure_installed or {}
			extend_unique(opts.ensure_installed, {
				"astro",
				"cmake",
				"cpp",
				"css",
				"fish",
				"gitignore",
				"go",
				"graphql",
				"http",
				"java",
				"php",
				"rust",
				"scss",
				"sql",
				"svelte",
			})
		end,
	},
}
