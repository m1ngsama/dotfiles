status is-interactive; or return

if command -q eza
    alias l 'command eza --group-directories-first --icons=auto'
    alias ll 'command eza --long --header --group-directories-first --icons=auto'
    alias la 'command eza --all --long --header --group-directories-first --icons=auto'
    alias lg 'command eza --long --header --git --group-directories-first --icons=auto'
    alias lt 'command eza --tree --level=2 --group-directories-first --icons=auto'
    alias all 'command eza --all --long --header --git --group-directories-first --icons=auto --time-style=long-iso'
else
    alias l 'command ls'
    alias ll 'command ls -lh'
    alias la 'command ls -lAh'
    alias lg 'command ls -lh'
    alias lt 'command ls -lAh'
    alias all 'command ls -lAh'
end
