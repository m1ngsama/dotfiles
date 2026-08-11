function fish_prompt --description 'M1NGSAMA prompt'
    set -l last_status $status
    # Solarized Osaka palette from locked commit f796014c14b1910e08d42cc2077fef34f08e0295.
    set -l osaka_red db302d
    set -l osaka_magenta d23681
    set -l osaka_blue 268bd3
    set -l osaka_cyan 29a298
    set -l osaka_green 849900
    set -l osaka_yellow b28500

    set -l marker_color $osaka_green
    if test $last_status -ne 0
        set marker_color $osaka_red
        # The marker and status number remain meaningful without colour.
        set_color --bold $osaka_red
        printf '!%d ' $last_status
    end

    set_color --bold $marker_color
    if fish_is_root_user
        printf '# '
    else
        printf '➜ '
    end

    set_color --bold $osaka_cyan
    printf '%s' (prompt_pwd)

    if command -q git
        # One porcelain-v2 query provides both branch and worktree state. This
        # avoids spawning three Git processes on every prompt refresh.
        set -l git_status (command git --no-optional-locks status \
            --porcelain=v2 --branch \
            --ignore-submodules=dirty --untracked-files=no \
            2>/dev/null)
        if test $status -ne 0
            set git_status
        end

        set -l branch_line (string match -- '# branch.head *' $git_status)
        set -l branch (string replace -- '# branch.head ' '' $branch_line)
        if test "$branch" = '(detached)'
            set -l oid_line (string match -- '# branch.oid *' $git_status)
            set -l oid (string replace -- '# branch.oid ' '' $oid_line)
            set branch (string sub --length 7 -- "$oid")
        end

        if test -n "$branch"
            set_color --bold $osaka_blue
            printf ' git:('
            set_color --bold $osaka_magenta
            printf '%s' "$branch"
            set_color --bold $osaka_blue
            printf ')'
        end

        set -l changes (string match --invert --regex '^# ' $git_status)
        if test -n "$changes"
            set_color --bold $osaka_yellow
            printf ' *'
        end
    end

    set_color normal
    printf ' '
end
