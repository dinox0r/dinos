all:
	@echo assembling dino.asm
	pushd ./src; dasm dino.asm -o../bin/dino.rom -l../bin/dino.lst -s../bin/dino.sym -v -f3; popd
	cp bin/dino.rom bin/dino.bin

run: all
	stella bin/dino.rom

debug: all
	stella -debug bin/dino.rom
