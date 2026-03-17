# ranger

This directory tracks the ranger setup I actually use instead of storing a
full copy of the packaged defaults.

## Files

- `rc.conf`: minimal overrides on top of ranger's built-in defaults
- `scope.sh`: richer previews for images, video, PDF, archives, and text

## Recommended packages on Arch Linux

```bash
sudo pacman -S --needed \
  ranger ueberzugpp chafa ffmpegthumbnailer mediainfo highlight atool \
  perl-image-exiftool w3m mpv trash-cli unrar poppler imagemagick bat jq file
```

## Notes

- `preview_images_method ueberzug` works well in X11 terminals such as Alacritty.
- `chafa` provides a readable fallback when graphical image previews are unavailable.
- `trash-cli` powers the `dt` and `dT` key bindings in `rc.conf`.
