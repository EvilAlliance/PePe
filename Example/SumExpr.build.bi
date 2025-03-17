:i argc 0
:b stdin 0

:i returncode 0
:b stdout 378
_start([34m%2: [0mmem, [35m%3: [0mptr)
  [95m%12[0m, [96m%13[0m = call.(mem, i8) [34m%2[0m, main
  [35m%17[0m, [36m%18[0m = syscall.(mem, void) [95m%12[0m, 60, [96m%13[0m
  [36m%4[0m = callgraph.void [93m%10[0m
  return [35m%17[0m, [35m%3[0m
main([34m%2: [0mmem, [35m%3: [0mptr)
  [36m%4[0m = callgraph.void 
  return [34m%2[0m, [35m%3[0m, 2

:b stderr 0

