status is-interactive; or return
command -q ghq; and command -q fzf; or return

bind \cg __m1ng_ghq_repository_search
if bind -M insert >/dev/null 2>/dev/null
    bind -M insert \cg __m1ng_ghq_repository_search
end
