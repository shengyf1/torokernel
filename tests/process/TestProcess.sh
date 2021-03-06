rm ../../rtl/*.ppu
rm ../../rtl/*.o
../../builder/BuildMultibootKernel.sh TestProcess "-dShutdownWhenFinished"
qemu-system-x86_64 -m 256 -smp 2 -nographic -monitor /dev/null -kernel TestProcess.bin -serial file:testprocess.report -device isa-debug-exit,iobase=0xf4,iosize=0x04
if grep -q FAILED "./testprocess.report"; then
  cat ./testprocess.report
  exit 1
fi
