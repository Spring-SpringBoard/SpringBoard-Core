# springmon
SpringRTS file monitor and autoreloader

## Features
- Detection and automated reload of *single-file* widget and gadget changes

## Dependencies
- Spring 104.x+
- [spring-wrapper-connector](https://github.com/gajop/spring-wrapper-connector)
- [spring-launcher](https://github.com/gajop/spring-launcher/)

## Install
1. Obtain the repository either by adding it as a git submodule or by copying the entire structure in to your Spring game folder. Put it anywhere (although `/libs` is suggested and used by default).
2. Copy the file `api_springmon_loader.lua` to the `luaui/widgets` and `luarules/gadgets` folders and modify the `SPRINGMON_DIR` path as necessary.
