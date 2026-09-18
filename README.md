# jetson-nano-build-script
This repository contains a build script which combines the other repositories into a fully usable image without the need for manual configuration.

## TODO:
- [ ] ask for wifi name and password to be baked into netcfg.yaml
- [ ] jetson_stats install (currently not working right) and powermode activation
- [ ] small OLED screen script for useful stats
  - [ ] Adafruit libraries
- [ ] jellyfin bare metal install
  - [ ] ffmpeg wrapper for jellyfin hw decoding
    - [ ] there is an old repo with patched ffmpeg so that it can be a drag-and-drop replacement, mb try to patch a newer version of ffmpeg
