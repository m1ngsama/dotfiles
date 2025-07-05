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

# pnpm
set -gx PNPM_HOME "/Users/m1ng/Library/pnpm"
if not string match -q -- $PNPM_HOME $PATH
  set -gx PATH "$PNPM_HOME" $PATH
end
# pnpm end
