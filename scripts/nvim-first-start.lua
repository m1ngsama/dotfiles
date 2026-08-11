local function assert_unique(label, items)
	local seen = {}
	for _, item in ipairs(items) do
		assert(not seen[item], ("%s contains duplicate %q"):format(label, item))
		seen[item] = true
	end
end

local function canonical_purl(id)
	local purl = require("mason-core.purl")
	return purl.parse(id):map(purl.compile):get_or_throw(("invalid Mason package URL: %s"):format(id))
end

local function wait_for_mason_packages(label, packages, timeout)
	assert_unique(label, packages)
	local registry = require("mason-registry")
	local location = require("mason-core.installer.InstallLocation").global()
	local mason_root = location:get_dir()
	local tracked = {}
	for _, name in ipairs(packages) do
		local package = registry.get_package(name)
		tracked[name] = {
			package = package,
			lockfile = location:lockfile(name),
			desired_source_id = canonical_purl(package.spec.source.id),
			desired_source_type = package.spec.schema,
			desired_registry = package.registry:serialize(),
			attempted = false,
		}
	end

	local failure
	local complete = vim.wait(timeout, function()
		local all_complete = true
		for name, item in pairs(tracked) do
			local package = item.package
			if package:is_installing() then
				all_complete = false
			elseif vim.uv.fs_stat(item.lockfile) then
				-- is_installing() is process-local; the lock also detects another
				-- Neovim updating the same Mason root. Never bypass that lock.
				item.external_lock = true
				all_complete = false
			else
				item.external_lock = false
				local receipt_ok, receipt_optional = pcall(package.get_receipt, package)
				local has_receipt = receipt_ok and receipt_optional:is_present()
				local source_matches = false
				local registry_matches = false
				local installed_source_id = receipt_ok and "no receipt" or "unreadable receipt"
				if not receipt_ok or (not has_receipt and package:is_installed()) then
					failure = (
						"Mason package %s has incomplete receipt state; close all Neovim instances, "
						.. "move %s aside as a backup, then rerun scripts/setup-nvim"
					):format(name, mason_root)
					return true
				end
				if has_receipt then
					local receipt = receipt_optional:get()
					local source = receipt:get_source()
					installed_source_id = source.id or "missing source id"
					local canonical_ok, installed_canonical = pcall(canonical_purl, source.id)
					source_matches = source.type == item.desired_source_type
						and canonical_ok
						and installed_canonical == item.desired_source_id
					registry_matches = vim.deep_equal(receipt:get_registry(), item.desired_registry)
				end
				if has_receipt and source_matches and registry_matches then
					-- Mason writes the receipt only after linking the final package.
				elseif not item.attempted then
					-- A missing receipt is an interrupted install. Any source or
					-- registry mismatch is an unreviewed result. Reinstall both cases
					-- from the pinned recipe without bypassing Mason's process lock.
					item.attempted = true
					package:install()
					all_complete = false
				else
					failure = (
						"Mason package %s did not converge: expected source %s from pinned registry, "
						.. "found %s; close Neovim, move %s aside, and retry"
					):format(name, item.desired_source_id, installed_source_id, mason_root)
					return true
				end
			end
		end
		return all_complete
	end, 500)
	assert(not failure, failure)
	if not complete then
		local locked = {}
		for name, item in pairs(tracked) do
			if item.external_lock then
				table.insert(locked, name)
			end
		end
		table.sort(locked)
		assert(
			#locked == 0,
			("timed out waiting for external Mason locks: %s; close other Neovim instances before retrying"):format(
				table.concat(locked, ", ")
			)
		)
		error("timed out waiting for " .. label)
	end
end

local function refresh_mason_registry(timeout)
	local registry = require("mason-registry")
	local refreshed
	registry.refresh(function(success)
		refreshed = success
	end)
	assert(
		vim.wait(timeout, function()
			return refreshed ~= nil
		end, 100),
		"timed out refreshing the pinned Mason registry"
	)
	assert(refreshed, "failed to refresh the pinned Mason registry")
end

local function configured_lsp_packages(timeout)
	local config_path = vim.fn.stdpath("config") .. "/init.lua"
	vim.cmd.edit(vim.fn.fnameescape(config_path))

	local settings = require("mason-lspconfig.settings")
	local loaded = vim.wait(timeout, function()
		local plugin = require("lazy.core.config").plugins["nvim-lspconfig"]
		return plugin._.loaded ~= nil and #settings.current.ensure_installed > 0
	end, 50)
	assert(loaded, "timed out loading the configured LSP server list")
	assert_unique("mason-lspconfig ensure_installed", settings.current.ensure_installed)

	local mapping = require("mason-lspconfig.mappings").get_mason_map().lspconfig_to_package
	local packages = {}
	local seen = {}
	for _, identifier in ipairs(settings.current.ensure_installed) do
		local server = identifier:match("^[^@]+")
		local package = mapping[server]
		assert(package, ("no Mason package mapping for LSP server %q"):format(server))
		if not seen[package] then
			table.insert(packages, package)
			seen[package] = true
		end
	end
	return packages
end

local function wait_for_treesitter_parsers(timeout)
	local parsers = LazyVim.opts("nvim-treesitter").ensure_installed
	assert_unique("nvim-treesitter ensure_installed", parsers)

	local treesitter = require("nvim-treesitter")
	local complete = vim.wait(timeout, function()
		local installed = {}
		for _, name in ipairs(treesitter.get_installed("parsers")) do
			installed[name] = true
		end
		for _, name in ipairs(parsers) do
			if not installed[name] then
				return false
			end
		end
		return true
	end, 500)
	assert(complete, "timed out waiting for the curated Tree-sitter parsers")
end

local function assert_lazy_tasks()
	for name, plugin in pairs(require("lazy.core.config").plugins) do
		for _, task in ipairs(plugin._.tasks or {}) do
			assert(not task:has_errors(), ("lazy task failed: %s/%s"):format(name, task.name))
		end
	end
end

local function main()
	assert(require("lazy.core.config").plugins["nvim-treesitter"].build == false)
	require("lazy.core.loader").load("mason.nvim", { cmd = "dotfiles setup" }, { force = true })
	refresh_mason_registry(30000)
	wait_for_mason_packages("the curated Mason tools", LazyVim.opts("mason.nvim").ensure_installed, 300000)
	wait_for_mason_packages("the configured LSP servers", configured_lsp_packages(10000), 300000)
	wait_for_treesitter_parsers(300000)

	local uname = vim.uv.os_uname()
	local linux_arm64 = uname.sysname == "Linux" and (uname.machine == "aarch64" or uname.machine == "arm64")
	assert(not linux_arm64 or vim.fn.executable("clangd") == 1, "Linux arm64 requires a system clangd")

	assert_lazy_tasks()
end

local ok, err = xpcall(main, debug.traceback)
if not ok then
	vim.api.nvim_err_writeln(err)
	vim.cmd("cquit 1")
end
vim.cmd("qa")
