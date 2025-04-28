all:
	@echo assembling dino.asm
	pushd ./src; dasm dino.asm -o../bin/dino.rom -l../bin/dino.lst -s../bin/dino.sym -v -f3; popd

run: all
	stella bin/dino.rom

debug: all
	stella -debug bin/dino.rom
