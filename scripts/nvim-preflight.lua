local function read_file(path)
	local handle, open_error = io.open(path, "rb")
	assert(handle, ("could not open %s: %s"):format(path, open_error or "unknown error"))
	local contents = handle:read("*a")
	handle:close()
	return contents
end

local function run(command)
	local result = vim.system(command, {
		text = true,
		env = {
			GIT_ATTR_NOSYSTEM = "1",
			GIT_CONFIG_GLOBAL = "/dev/null",
			GIT_CONFIG_NOSYSTEM = "1",
			GIT_NO_LAZY_FETCH = "1",
			GIT_NO_REPLACE_OBJECTS = "1",
			GIT_OPTIONAL_LOCKS = "0",
			GIT_TERMINAL_PROMPT = "0",
		},
	}):wait(30000)
	local output = vim.trim((result.stdout or "") .. (result.stderr or ""))
	return result.code == 0, output
end

local function ensure_real_directory(path)
	local stat = vim.uv.fs_lstat(path)
	if stat then
		assert(stat.type == "directory", "refusing non-directory or symlink path: " .. path)
		return
	end
	local created, create_error = vim.uv.fs_mkdir(path, tonumber("700", 8))
	assert(created, ("could not create %s: %s"):format(path, create_error or "unknown error"))
end

local function first_line(value)
	return (value:match("[^\r\n]+") or value):sub(1, 240)
end

local function each_nul_record(value)
	return value:gmatch("([^%z]+)")
end

local function metadata_file_reason(path, label)
	local stat = vim.uv.fs_lstat(path)
	if not stat then
		return nil
	end
	if stat.type ~= "file" then
		return label .. " is not a regular file"
	end
	local ok, contents = pcall(read_file, path)
	if not ok then
		return "could not read " .. label
	end
	for line in contents:gmatch("[^\r\n]+") do
		if not line:match("^%s*$") and not line:match("^%s*#") then
			return "active " .. label
		end
	end
	return nil
end

local function allowed_local_config(key)
	return vim.tbl_contains({
		"core.autocrlf",
		"core.bare",
		"core.filemode",
		"core.ignorecase",
		"core.logallrefupdates",
		"core.precomposeunicode",
		"core.repositoryformatversion",
		"remote.origin.fetch",
		"remote.origin.partialclonefilter",
		"remote.origin.promisor",
		"remote.origin.url",
		"submodule.active",
	}, key) or key:match("^branch%..+%.merge$") ~= nil or key:match("^branch%..+%.remote$") ~= nil
end

local function checkout_metadata_reason(git, git_dir)
	local config_command =
		vim.list_extend(vim.deepcopy(git), { "config", "--local", "--no-includes", "--name-only", "--null", "--list" })
	local config_ok, config_names = run(config_command)
	if not config_ok then
		return "unreadable local Git config: " .. first_line(config_names)
	end
	for name in each_nul_record(config_names) do
		local key = name:lower()
		if not allowed_local_config(key) then
			return "unsupported local Git config: " .. key
		end
	end

	for _, item in ipairs({
		{ git_dir .. "/info/attributes", "Git info attributes" },
		{ git_dir .. "/info/exclude", "Git info excludes" },
		{ git_dir .. "/objects/info/alternates", "Git object alternates" },
		{ git_dir .. "/objects/info/http-alternates", "Git HTTP object alternates" },
	}) do
		local reason = metadata_file_reason(item[1], item[2])
		if reason then
			return reason
		end
	end

	local hooks_path = git_dir .. "/hooks"
	local hooks_stat = vim.uv.fs_lstat(hooks_path)
	if hooks_stat then
		if hooks_stat.type ~= "directory" then
			return "Git hooks path is not a regular directory"
		end
		local scanner, scan_error = vim.uv.fs_scandir(hooks_path)
		if not scanner then
			return "could not inspect Git hooks: " .. (scan_error or "unknown error")
		end
		while true do
			local hook = vim.uv.fs_scandir_next(scanner)
			if not hook then
				break
			end
			if not hook:match("%.sample$") then
				return "non-sample Git hook metadata: " .. hook
			end
		end
	end

	local replace_command =
		vim.list_extend(vim.deepcopy(git), { "for-each-ref", "--format=%(refname)", "refs/replace" })
	local replace_ok, replace_refs = run(replace_command)
	if not replace_ok then
		return "unreadable Git replacement refs: " .. first_line(replace_refs)
	end
	if replace_refs ~= "" then
		return "Git replacement refs are present"
	end
	return nil
end

local function allowed_generated_path(path)
	return path == "doc/tags" or path:match("^doc/tags%-%w[%w._-]*$") ~= nil
end

local function main()
	local lock_path = vim.fn.stdpath("config") .. "/lazy-lock.json"
	local decoded_ok, lock = pcall(vim.json.decode, read_file(lock_path))
	assert(decoded_ok and type(lock) == "table", "invalid Neovim lock file: " .. lock_path)

	local names = vim.tbl_keys(lock)
	table.sort(names)
	assert(#names > 0, "Neovim lock file is empty: " .. lock_path)

	local lazy_root = vim.fn.stdpath("data") .. "/lazy"
	local lazy_stat = vim.uv.fs_lstat(lazy_root)
	if not lazy_stat then
		print("Neovim plugin preflight: cold data root; nothing to quarantine.")
		return
	end
	assert(lazy_stat.type == "directory", "refusing non-directory or symlink plugin root: " .. lazy_root)

	local drifted = {}
	for _, name in ipairs(names) do
		assert(name:match("^[%w][%w._-]*$"), "unsafe plugin name in lazy-lock.json: " .. name)
		local entry = lock[name]
		assert(type(entry) == "table", "invalid lock entry for " .. name)
		assert(
			type(entry.commit) == "string" and entry.commit:match("^[0-9a-f]+$") and #entry.commit == 40,
			"invalid commit in lock entry for " .. name
		)

		local plugin_path = lazy_root .. "/" .. name
		local stat = vim.uv.fs_lstat(plugin_path)
		if stat then
			assert(stat.type == "directory", "refusing non-directory or symlink plugin checkout: " .. plugin_path)

			local git_dir = plugin_path .. "/.git"
			local git_stat = vim.uv.fs_lstat(git_dir)
			local git = {
				"git",
				"--no-replace-objects",
				"-c",
				"core.fsmonitor=false",
				"-c",
				"core.hooksPath=/dev/null",
				"-c",
				"core.trustctime=true",
				"-c",
				"core.checkStat=default",
				"-c",
				"core.ignoreStat=false",
				"--git-dir=" .. git_dir,
				"--work-tree=" .. plugin_path,
			}
			local reason = not git_stat and "missing .git directory"
				or git_stat.type ~= "directory" and "non-directory or linked .git metadata"
				or checkout_metadata_reason(git, git_dir)
			local head_ok = false
			local head = "unknown"
			if not reason then
				local head_command = vim.list_extend(vim.deepcopy(git), { "rev-parse", "--verify", "HEAD" })
				head_ok, head = run(head_command)
				if not head_ok then
					reason = "unreadable Git checkout: " .. first_line(head)
				elseif head ~= entry.commit then
					reason = ("commit %s, expected %s"):format(head, entry.commit)
				end
			end
			if not reason then
				local status_command = vim.list_extend(
					vim.deepcopy(git),
					{ "status", "--porcelain=v1", "--untracked-files=no", "--ignore-submodules=all" }
				)
				local status_ok, status = run(status_command)
				if not status_ok then
					reason = "unreadable Git status: " .. first_line(status)
				elseif status ~= "" then
					reason = "tracked or staged working-tree changes"
				end
			end
			if not reason then
				local index_command = vim.list_extend(vim.deepcopy(git), { "ls-files", "-v", "-z" })
				local index_ok, index_flags = run(index_command)
				if not index_ok then
					reason = "unreadable Git index: " .. first_line(index_flags)
				else
					for record in each_nul_record(index_flags) do
						local tag = record:sub(1, 1)
						if tag == "S" or tag:match("%l") then
							reason = ("index flag %s on %s"):format(tag, record:sub(3))
							break
						end
					end
				end
			end
			if not reason then
				local stage_command = vim.list_extend(vim.deepcopy(git), { "ls-files", "-s", "-z" })
				local stage_ok, stages = run(stage_command)
				if not stage_ok then
					reason = "unreadable Git stages: " .. first_line(stages)
				else
					for record in each_nul_record(stages) do
						local mode, _, stage, path = record:match("^(%d+) ([0-9a-f]+) (%d+)\t(.*)$")
						if not mode then
							reason = "malformed Git index entry"
						elseif stage ~= "0" then
							reason = "unmerged Git index entry: " .. path
						elseif mode == "160000" then
							reason = "Git submodule checkout requires recursive verification: " .. path
						end
						if reason then
							break
						end
					end
				end
			end
			if not reason then
				local extras_command = vim.list_extend(vim.deepcopy(git), { "ls-files", "--others", "-z" })
				local extras_ok, extras = run(extras_command)
				if not extras_ok then
					reason = "unreadable untracked paths: " .. first_line(extras)
				else
					for path in each_nul_record(extras) do
						if not allowed_generated_path(path) then
							reason = "untracked or ignored path: " .. path
							break
						end
					end
				end
			end

			if reason then
				table.insert(drifted, {
					name = name,
					path = plugin_path,
					head = head_ok and head or "unknown",
					reason = reason,
				})
			end
		end
	end

	if #drifted == 0 then
		print("Neovim plugin preflight: every existing checkout matches the reviewed lock.")
		return
	end

	local quarantine_base = vim.fn.stdpath("data") .. "/dotfiles-quarantine"
	ensure_real_directory(quarantine_base)
	local quarantine = quarantine_base .. "/" .. os.date("!%Y%m%dT%H%M%SZ") .. "-" .. vim.fn.getpid()
	ensure_real_directory(quarantine)

	local manifest_path = quarantine .. "/MANIFEST.tsv"
	local manifest, manifest_error = io.open(manifest_path, "wb")
	assert(manifest, ("could not create %s: %s"):format(manifest_path, manifest_error or "unknown error"))
	manifest:write("plugin\tprevious_head\treason\n")
	manifest:flush()

	for _, item in ipairs(drifted) do
		local destination = quarantine .. "/" .. item.name
		local renamed, rename_error = vim.uv.fs_rename(item.path, destination)
		assert(
			renamed,
			("could not quarantine %s at %s: %s"):format(item.name, destination, rename_error or "unknown error")
		)
		local reason = item.reason:gsub("[\t\r\n]", " ")
		manifest:write(("%s\t%s\t%s\n"):format(item.name, item.head, reason))
		manifest:flush()
		print(("Quarantined Neovim plugin %s: %s"):format(item.name, reason))
	end
	manifest:close()
	print("Preserved previous plugin checkouts at " .. quarantine)
end

local ok, err = xpcall(main, debug.traceback)
if not ok then
	vim.api.nvim_err_writeln("Neovim plugin preflight failed:\n" .. err)
	vim.cmd("cquit 1")
end
