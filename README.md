# SpringBoard: Editor for Spring

Resources:
- [Wiki](https://github.com/Spring-SpringBoard/SpringBoard-Core/wiki/Starting-out)
- API (TODO)
- Examples (TODO)

## Installing
The production version can be obtained from rapid, via:
`pr-downloader sbc:test`

The development version can be obtained from this repository, by cloning it in your game folder:
```
git clone https://github.com/Spring-SpringBoard/SpringBoard-Core SB-C.sdd
cd SB-C.sdd
git submodule init
git submodule update
```

### Game-specific modules
This is the core module, you may still want to get additional game-specific modules if you're making a scenario.

Some examples:
- https://github.com/Spring-SpringBoard/SpringBoard-BA
- https://github.com/Spring-SpringBoard/SpringBoard-ZK
- https://github.com/Spring-SpringBoard/SpringBoard-EVO

## Assets

Any assets (texture files, skyboxes, etc.) should be put in the "springboard/assets" folder, located inside the Spring data directory.

Core assets can be obtained from the following [link](https://drive.google.com/file/d/0B9FQjbVMFgL2LTM2Z1VVaGRZRDQ/view?usp=sharing). Once downloaded, they should be extracted, with the resulting folder structure of "springboard/assets/core/".
