all:
	@echo assembling dino.asm
	pushd ./src; dasm main.asm -o../bin/dino.rom -l../bin/dino.lst -s../bin/dino.sym -v -f3; popd

run: all
	stella bin/main.rom

debug: all
	stella -debug bin/dino.rom
