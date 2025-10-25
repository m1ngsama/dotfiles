if status is-interactive
    # Commands to run in interactive sessions can go here
end

# fisher
set -Ux fish_user_paths $fish_user_paths /usr/local/bin

# brew
set -g PATH /opt/homebrew/bin $PATH

# mysql 
set -g PATH /usr/local/mysql/bin $PATH

# golang
set -Ux GOPATH /Users/m1ng/Documents/PF/data/go
set -Ux PATH $PATH $GOPATH/bin

thefuck --alias | source

function fish_greeting
    echo 'Talk is cheap. Show me the code.' | lolcat -a -d 10
end

# pnpm in mac
set -gx PNPM_HOME /Users/m1ng/Library/pnpm
if not string match -q -- $PNPM_HOME $PATH
    set -gx PATH "$PNPM_HOME" $PATH
end
# pnpm end

## move from arch
##function fish_greeting
#end

# Man in zh_CN, you should install man-pages-zh_cn manual first
#alias cman="man -L zh_CN"
#alias all="eza -alh --icons --group-directories-first --time-style=long-iso --total-size"

# When use shadowsocks as proxy you need that
## set -x ALL_PROXY "socks5h://127.0.0.1:1080"
## set -x http_proxy "socks5h://127.0.0.1:1080"
## set -x https_proxy "socks5h://127.0.0.1:1080"
## set -x http_proxy "http://127.0.0.1:8118"

# Privoxy, filtering proxy for the HTTP protocol
## set -x https_proxy "https://127.0.0.1:8118"
## set -x ALL_PROXY "https://127.0.0.1:8118"

### if not set -q NODE_VERSION
###    nvm use lts
### end

## pnpm in arch
# set -gx PNPM_HOME "/home/m1ng/.local/share/pnpm"
# if not string match -q -- $PNPM_HOME $PATH
# set -gx PATH "$PNPM_HOME" $PATH
# end
## pnpm end
