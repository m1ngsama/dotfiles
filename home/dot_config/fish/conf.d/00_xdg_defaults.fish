# XDG variables that are empty or relative are invalid and must be treated as
# unset. Normalize them before vendored conf.d integrations read their values.
if not set -q XDG_CONFIG_HOME; or test -z "$XDG_CONFIG_HOME"; or not string match -q '/*' -- "$XDG_CONFIG_HOME"
    set -gx XDG_CONFIG_HOME "$HOME/.config"
end

if not set -q XDG_DATA_HOME; or test -z "$XDG_DATA_HOME"; or not string match -q '/*' -- "$XDG_DATA_HOME"
    set -gx XDG_DATA_HOME "$HOME/.local/share"
end

if not set -q XDG_STATE_HOME; or test -z "$XDG_STATE_HOME"; or not string match -q '/*' -- "$XDG_STATE_HOME"
    set -gx XDG_STATE_HOME "$HOME/.local/state"
end

if not set -q XDG_CACHE_HOME; or test -z "$XDG_CACHE_HOME"; or not string match -q '/*' -- "$XDG_CACHE_HOME"
    set -gx XDG_CACHE_HOME "$HOME/.cache"
end
