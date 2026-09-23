#!/bin/sh
export XDG_SESSION_TYPE=x11
[ -r "$HOME/.xprofile" ] && . "$HOME/.xprofile"
[ -r "$HOME/.Xresources" ] && xrdb -merge "$HOME/.Xresources"
exec i3
