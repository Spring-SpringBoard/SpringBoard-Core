build:
	cd native && cargo build

build-release:
	cd native && cargo build --release

watch command='':
	cd native && bacon {{ command }}

dev:
	~/apps/SpringBoard.AppImage -c ~/projects/spring-projects/SBC.sdd/dist_cfg/config.json