fish_add_path --global \
    "$HOME/.local/bin" \
    "$HOME/go/bin" \
    "$HOME/.cargo/bin" \
    "$HOME/.bun/bin" \
    /opt/homebrew/bin \
    /opt/homebrew/sbin \
    /usr/local/bin \
    /usr/local/sbin \
    /usr/local/mysql/bin

if not set -q PNPM_HOME
    switch (uname)
        case Darwin
            set -gx PNPM_HOME "$HOME/Library/pnpm"
        case '*'
            set -gx PNPM_HOME "$HOME/.local/share/pnpm"
    end
end
fish_add_path --global "$PNPM_HOME"

status is-interactive; or return

command -q thefuck; and thefuck --alias | source
alias cman 'env LC_ALL=zh_CN.UTF-8 man'

function fish_greeting
    if command -q lolcat
        echo 'Talk is cheap. Show me the code.' | lolcat
    else
        echo 'Talk is cheap. Show me the code.'
    end
end
