local lazy_root = vim.fn.stdpath("data") .. "/lazy"
local lazy_commit = "6c3bda4aca61a13a9c63f1c1d1b16b9d3be90d7a"
local lazyvim_commit = "dc1ffa5bcb66f46284f91a8593dda5c7c54a1824"
local benchmark = vim.g.dotfiles_benchmark == 1

local function bootstrap_plugin(name, url, commit, branch)
	local plugin_path = lazy_root .. "/" .. name
	local plugin_stat = vim.uv.fs_lstat(plugin_path)
	if plugin_stat then
		if plugin_stat.type ~= "directory" then
			error(("%s bootstrap refused a non-directory or symlink checkout: %s"):format(name, plugin_path))
		end
		return plugin_path
	end

	local plugin_stage = plugin_path .. ".bootstrap." .. vim.fn.getpid()
	local function bootstrap_error(message, output)
		vim.fn.delete(plugin_stage, "rf")
		error(("%s bootstrap failed: %s\n%s"):format(name, message, vim.trim(output or "")))
	end
	local function run(command)
		local output = vim.fn.system(command)
		if vim.v.shell_error ~= 0 then
			bootstrap_error(table.concat(command, " "), output)
		end
	end

	vim.fn.mkdir(lazy_root, "p")
	vim.fn.delete(plugin_stage, "rf")
	vim.fn.mkdir(plugin_stage, "p")
	run({ "git", "-C", plugin_stage, "init", "--quiet" })
	run({ "git", "-C", plugin_stage, "remote", "add", "origin", url })
	-- Keep the checkout deterministic while retaining the default-branch refs
	-- lazy.nvim needs when it writes the lock file after a first install.
	run({
		"git",
		"-C",
		plugin_stage,
		"fetch",
		"--quiet",
		"--depth=1",
		"--filter=blob:none",
		"origin",
		commit .. ":refs/remotes/origin/" .. branch,
	})
	run({
		"git",
		"-C",
		plugin_stage,
		"symbolic-ref",
		"refs/remotes/origin/HEAD",
		"refs/remotes/origin/" .. branch,
	})
	run({ "git", "-C", plugin_stage, "checkout", "--quiet", "--detach", commit })

	local renamed, rename_error = vim.uv.fs_rename(plugin_stage, plugin_path)
	if not renamed then
		-- A concurrent Neovim may have completed the same atomic bootstrap.
		if vim.uv.fs_stat(plugin_path) then
			vim.fn.delete(plugin_stage, "rf")
		else
			bootstrap_error("could not install the staged checkout", rename_error)
		end
	end
	return plugin_path
end

local lazypath = bootstrap_plugin("lazy.nvim", "https://github.com/folke/lazy.nvim.git", lazy_commit, "main")
-- LazyVim provides imported specs. Installing it before setup makes the full
-- graph visible in the first lock-aware install pass, so early partial passes
-- cannot discard still-unseen lock entries and replace them with branch tips.
bootstrap_plugin("LazyVim", "https://github.com/LazyVim/LazyVim.git", lazyvim_commit, "main")
vim.opt.rtp:prepend(lazypath)

require("lazy").setup({
	-- The repository lock is the complete plugin graph. Do not let a project's
	-- local .lazy.lua silently add an unreviewed dependency on startup.
	local_spec = false,
	-- Local performance measurements use an already-provisioned copy and must
	-- never turn a timing sample into dependency installation.
	install = { missing = not benchmark },
	spec = {
		-- add LazyVim and import its plugins
		{
			"LazyVim/LazyVim",
			import = "lazyvim.plugins",
			opts = {
				colorscheme = "solarized-osaka",
				news = {
					lazyvim = true,
					neovim = true,
				},
			},
		},
		{ import = "plugins" },
	},
	defaults = {
		-- By default, only LazyVim plugins will be lazy-loaded. Your custom plugins will load during startup.
		-- If you know what you're doing, you can set this to `true` to have all your custom plugins lazy-loaded by default.
		lazy = false,
		-- It's recommended to leave version=false for now, since a lot the plugin that support versioning,
		-- have outdated releases, which may break your Neovim install.
		version = false, -- always use the latest git commit
		-- version = "*", -- try installing the latest stable version for plugins that support semver
	},
	dev = {
		path = "~/.ghq/github.com",
	},
	-- The graph is Git-locked. Disable package/rock discovery so a repository
	-- rockspec cannot introduce a second, unpinned dependency channel.
	pkg = { enabled = false },
	-- Keep normal startup offline and deterministic. Review updates explicitly
	-- with :Lazy check, then restore or update the committed lock as intended.
	checker = { enabled = false },
	performance = {
		cache = {
			enabled = true,
			-- disable_events = {},
		},
		rtp = {
			-- disable some rtp plugins
			disabled_plugins = {
				"gzip",
				-- "matchit",
				"matchparen", -- using vim-matchup or other alternatives
				"netrwPlugin",
				"rplugin",
				"tarPlugin",
				"tohtml",
				"tutor",
				"zipPlugin",
			},
		},
	},
	ui = {
		custom_keys = {
			["<localleader>d"] = function(plugin)
				dd(plugin)
			end,
		},
	},
	debug = false,
})
