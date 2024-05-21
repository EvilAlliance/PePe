#define NOB_IMPLEMENTATION
#include "./src/nob.h"

int main(int argc, char *argv[]) {
  NOB_GO_REBUILD_URSELF(argc, argv);

  const char *program = nob_shift_args(&argc, &argv);

  nob_log(NOB_INFO, "--- STAGE 1 ---");

  if (!nob_mkdir_if_not_exists("build")) {
    _mkdir("./build");
  }

  Nob_Cmd cmd = {0};
  nob_cmd_append(&cmd, "gcc", "-o", "./build/main", "main.c");

  if (!nob_cmd_run_sync(cmd))
    return 1;

  cmd.count = 0;

  nob_cmd_append(&cmd, "./build/main");

  if (!nob_cmd_run_sync(cmd))
    return 1;

  return 0;
}
