:i argc 0
:b stdin 0

:i returncode 0
:b stdout 523
_start([34m%2: [0mmem, [35m%3: [0mptr)
  [95m%12[0m, [96m%13[0m = call.(mem, i8) [34m%2[0m, main
  [35m%17[0m, [36m%18[0m = syscall.(mem, void) [95m%12[0m, 60, [96m%13[0m
  [36m%4[0m = callgraph.void [93m%10[0m
  return [35m%17[0m, [35m%3[0m
main([34m%2: [0mmem, [35m%3: [0mptr)
  [95m%12[0m = add.i8 1, 1 !nuw
  [36m%4[0m = callgraph.void 
  goto [38m%6.ret[0m([34m%2[0m, [95m%12[0m)
[38m%6.ret[0m([39m%7: [0mmem, [91m%8: [0mi8)
  return [39m%7[0m, [35m%3[0m, [91m%8[0m

:b stderr 0

