#define G_USE
#include "./src/G.h"

#define FILE_NAME "main.c"

int main(int argc, char *argv[]) {
  Read_File f = {
      .path = FILE_NAME,
  };

  if (!g_start_reading_file(&f)) {
    g_log(G_ERROR, "Could not start reading");
    return 1;
  }

  g_log(G_INFO, "Reading File: %s", f.path);
  String_Builder data = {
      .capacity = 50,
      .items = malloc(50),
  };

  while (!f.finished) {
    g_read_file_by_line(&f, &data);
    g_log(G_INFO, "Chunk Content: \n%s", data.items);
  }

  return 0;
}

