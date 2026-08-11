function __m1ng_ghq_repository_search --description 'Select a ghq repository with fzf'
    if not command -q ghq; or not command -q fzf
        printf 'ghq repository search requires both ghq and fzf\n' >&2
        return 127
    end

    set -l query (commandline --current-buffer)
    set -l selected (command ghq list --full-path 2>/dev/null | command fzf --query "$query" --select-1 --exit-0)

    if test -n "$selected"
        cd -- "$selected"
        commandline --replace ''
    end

    commandline -f repaint
end
