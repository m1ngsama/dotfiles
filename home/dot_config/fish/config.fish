# Keep environment setup deterministic and process-local. fish_add_path is
# idempotent and ignores directories that do not exist; --global prevents it
# from writing machine-specific universal variables.
fish_add_path --global \
    "$HOME/.local/bin" \
    /opt/homebrew/bin \
    /opt/homebrew/sbin \
    /usr/local/bin \
    /usr/local/sbin \
    /usr/local/mysql/bin

# Go installs commands into GOBIN when it is set, otherwise into the first
# GOPATH workspace's bin directory. Fish imports GOPATH as a path variable, so
# selecting its first element also handles a colon-separated inherited value.
set -l go_bin "$HOME/go/bin"
if set -q GOBIN; and test -n "$GOBIN"; and string match -q '/*' -- "$GOBIN"
    set go_bin "$GOBIN"
else if set -q GOPATH; and test -n "$GOPATH[1]"
    set go_bin "$GOPATH[1]/bin"
end
fish_add_path --global "$go_bin"

# pnpm uses different default homes on macOS and Linux. An existing
# PNPM_HOME always wins, so machine or work-specific overrides stay local.
if not set -q PNPM_HOME; and command -q uname
    switch (command uname -s 2>/dev/null)
        case Darwin
            set -gx PNPM_HOME "$HOME/Library/pnpm"
        case Linux
            set -l data_home "$HOME/.local/share"
            if set -q XDG_DATA_HOME
                set data_home "$XDG_DATA_HOME"
            end
            set -gx PNPM_HOME "$data_home/pnpm"
    end
end

if set -q PNPM_HOME; and test -n "$PNPM_HOME"
    fish_add_path --global "$PNPM_HOME"
end

# Everything below is presentation or interactive workflow integration. Keep
# it out of non-interactive shells and degrade quietly when a tool is absent.
if status is-interactive
    if command -q thefuck
        thefuck --alias | source
    end

    if command -q man
        # Locale environment variables work with both BSD man and man-db;
        # man-db's -L flag is not available on macOS.
        alias cman 'env LC_ALL=zh_CN.UTF-8 man'
    end

    function fish_greeting
        set -l maxim 'Talk is cheap. Show me the code.'
        if command -q lolcat
            # Keep the rice without delaying every new interactive shell with
            # lolcat's animation loop.
            printf '%s\n' "$maxim" | command lolcat
        else
            printf '%s\n' "$maxim"
        end
    end
end

# Optional local examples (keep credentials and host-specific values out of
# the repository):
# set -gx ALL_PROXY socks5h://127.0.0.1:1080
# set -gx http_proxy http://127.0.0.1:8118
# set -gx https_proxy http://127.0.0.1:8118
