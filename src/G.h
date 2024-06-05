#include <assert.h>
#include <malloc.h>
#include <stdarg.h>
#include <stdbool.h>
#include <stdio.h>

#define g_daAppend(da, item)                                                   \
  {                                                                            \
    if ((da)->count >= (da)->capacity) {                                       \
      (da)->capacity = (da)->capacity == 0 ? 20 : (da)->capacity * 2;          \
      (da)->items =                                                            \
          realloc((da)->items, (da)->capacity * sizeof(*(da)->items));         \
      assert((da)->items != NULL && "Buy more RAM!");                          \
    }                                                                          \
    (da)->items[(da)->count] = (item);                                         \
    (da)->count++;                                                             \
  }

#define g_daFree(da) free((da)->items);

typedef enum G_LogLevel { G_INFO, G_WARNING, G_ERROR } G_LogLevel;

void g_log(G_LogLevel l, const char *m, ...) {
  switch (l) {
  case G_INFO:
    fprintf(stderr, "[INFO] ");
    break;
  case G_WARNING:
    fprintf(stderr, "[WARNING] ");
    break;
  case G_ERROR:
    fprintf(stderr, "[ERROR] ");
    break;
  default:
    assert(0 && "???");
  }

  va_list args;
  va_start(args, m);
  vfprintf(stderr, m, args);
  va_end(args);
  fprintf(stderr, "\n");
}

typedef struct StringBuilder {
  char *items;
  size_t count;
  size_t capacity;
} StringBuilder;

bool g_readFile(char *path, StringBuilder *sb) {
  FILE *f;
  if (fopen_s(&f, path, "rb")) {
    g_log(G_ERROR, "Could not open file %s", path);
    return 0;
  }

  if (fseek(f, 0, SEEK_END) < 0) {
    g_log(G_ERROR,
          "The stream is unbuffered or the streams buffer needed to be "
          "flushed. FILE %s",
          path);
    return 0;
  }

  long fsize = ftell(f);
  if (fsize < 0) {
    g_log(G_ERROR,
          "The file descriptor underlying stream is not an open file "
          "descriptor %s",
          path);
    return 0;
  }
  rewind(f);

  sb->count = sb->count + fsize + 1;
  if (sb->count > sb->capacity) {
    sb->items = (char *)realloc(sb->items, sizeof(char) * sb->capacity + 1);
    assert(sb->items != NULL && "Buy more RAM!");
    sb->capacity = sb->count;
  }

  long readChars = fread_s(sb->items, fsize, 1, fsize, f);

  if (readChars != fsize) {
    g_log(G_ERROR, "Could not read entire file: %s", path);
    return 0;
  }

  sb->items[readChars] = '\0';

  if (ferror(f)) {
    g_log(G_ERROR, "An error ocurred when reading file: %s", path);
    return 0;
  } else {
    fclose(f);
    return 1;
  }
}

typedef struct ReadFileByChunks {
  FILE *f;
  char *path;
  size_t chunk;
  bool finished;
  StringBuilder output;
} ReadFileByChunks;

bool startReadingFileByChunks(ReadFileByChunks *f) {
  if (fopen_s(&f->f, f->path, "rb")) {
    g_log(G_ERROR, "Could not open file %s", f->path);
    return 0;
  }

  if (f->chunk + 1 > f->output.capacity) {
    f->output.items =
        (char *)realloc(f->output.items, sizeof(char) * (f->chunk + 1));
    assert(f->output.items != NULL && "Buy more RAM!");
    f->output.capacity = f->output.count = f->chunk;
  }
  return 1;
}

bool readFileByChunkNextChunk(ReadFileByChunks *f) {
  long readChars = fread_s(f->output.items, f->chunk, 1, f->chunk, f->f);

  f->output.items[f->chunk] = '\0';

  if (ferror(f->f)) {
    f->finished = 1;
    g_log(G_ERROR, "An error ocurred when reading file: %s", f->path);
    return 0;
  } else if (readChars != f->chunk) {
    f->finished = 1;
    fclose(f->f);
    return 1;
  }

  return 1;
}

typedef struct ReadFileByLine {
  FILE *f;
  char *path;
  bool finished;
  StringBuilder output;
} ReadFileByLine;

bool startReadingFileByLine(ReadFileByLine *f) {
  if (fopen_s(&f->f, f->path, "rb")) {
    g_log(G_ERROR, "Could not open file %s", f->path);
    return 0;
  }

  return 1;
}

bool readFileByLineNextLine(ReadFileByLine *f) {
  f->output.count = 0;

  char data;
  long readChars = 0;
  while (data != '\n') {
    readChars = readChars + fread_s(&data, 1, 1, 1, f->f);
    g_daAppend(&f->output, (data != '\n' ? data : '\0'));
  }

  if (ferror(f->f)) {
    f->finished = 1;
    g_log(G_ERROR, "An error ocurred when reading file: %s", f->path);
    return 0;
  } else if (readChars == 0) {
    f->finished = 1;
    fclose(f->f);
    return 1;
  }

  return 1;
}

typedef struct ReadFileByChar {
  FILE *f;
  char *path;
  bool finished;
  char output;
} ReadFileByChar;

bool startReadingFileByChar(ReadFileByChar *f) {
  if (fopen_s(&f->f, f->path, "rb")) {
    g_log(G_ERROR, "Could not open file %s", f->path);
    return 0;
  }

  return 1;
}

bool readFileByCharNextChar(ReadFileByChar *f) {
  char data;
  long readChars = fread_s(&f->output, 1, 1, 1, f->f);

  if (ferror(f->f)) {
    f->finished = 1;
    g_log(G_ERROR, "An error ocurred when reading file: %s", f->path);
    return 0;
  } else if (readChars == 0) {
    f->finished = 1;
    fclose(f->f);
    return 1;
  }

  return 1;
}
