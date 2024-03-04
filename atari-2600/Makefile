all:
	@echo assembling dino.asm
	dasm dino.asm -odino.rom -ldino.lst -sdino.sym -v -f3

run: all
	stella dino.rom

debug: all
	stella -debug dino.rom
