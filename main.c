#define G_USE
#include "./src/G.h"

#define FILE_NAME "main.c"

int main(int argc, char *argv[]) {
    ReadFileByChar f = {
	.path = FILE_NAME,
    };

    if(!startReadingFileByChar(&f)){
	g_log(G_ERROR, "Could not start reading");
	return 1;
    }

    g_log(G_INFO, "Reading File: %s", f.path);

    while(!f.finished){
	readFileByCharNextChar(&f);
	g_log(G_INFO, "Chunk Content: \n%c", f.output);
    }

  return 0;
}
