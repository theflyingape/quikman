@echo on
pushd %~dp0
set PATH=bin

ca65 --cpu 6502 --listing quikman.s
ld65 -C doc\vic20.cfg -o quikman.prg quikman.o

popd
pause
