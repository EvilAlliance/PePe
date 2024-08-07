#ifndef G_H_
#define G_H_

#include <assert.h>
#include <malloc.h>
#include <stdarg.h>
#include <stdbool.h>
#include <stdio.h>

// TODO

#define TODO(msg, ...)                                                         \
  g_log(G_TODO, "File : %s Func: %s Line: %d. " msg "\n", __FILE__,            \
        __FUNCTION__, __LINE__)

// DYNAMIC ARRAY

typedef struct String_Builder {
  char *items;
  size_t count;
  size_t capacity;
} String_Builder;

#define G_DA_INIT_CAP 10
#define g_da_append(da, item, items_type)                                      \
  {                                                                            \
    if ((da)->count >= (da)->capacity) {                                       \
      (da)->capacity =                                                         \
          (da)->capacity == 0 ? G_DA_INIT_CAP : (da)->capacity * 2;            \
      (da)->items = (items_type)realloc(                                       \
          (da)->items, (da)->capacity * sizeof(*(da)->items));                 \
      assert((da)->items != NULL && "Buy more RAM!");                          \
    }                                                                          \
    (da)->items[(da)->count] = (item);                                         \
    (da)->count++;                                                             \
  }

#define g_da_free(da) free((da)->items);

// LOGGING

typedef enum G_Log_Level { G_INFO, G_WARNING, G_ERROR, G_TODO } G_Log_Level;

void g_log(G_Log_Level l, const char *m, ...);

// READING FILE

typedef struct Read_File {
  FILE *f;
  char *path;
  bool finished;
} Read_File;

bool g_start_reading_file(Read_File *f);

bool g_read_file_by_bulk(Read_File *f, String_Builder *sb);

bool g_read_file_by_chunk(Read_File *f, String_Builder *sb);

bool g_read_file_by_line(Read_File *f, String_Builder *sb);

bool g_read_file_by_char(Read_File *f, char *data);

bool isNumber(char n);

bool isAlpha(char n);

// String_View

typedef struct String_View {
  char *beg;
  size_t count;
} String_View;

#define SV_FMT "%.*s"
#define SV_ARGS(sv) (int)(sv).count, (sv).beg

int g_svCmp(String_View one, String_View two);
int g_svStringCmp(String_View one, String_View two);

#endif // G_H_

#ifdef G_IMPLEMENTATION

// LOGGING
void g_log(G_Log_Level l, const char *m, ...) {
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
  case G_TODO:
    fprintf(stderr, "[TODO] ");
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

// REAFING FILES

bool g_start_reading_file(Read_File *f) {
  f->f = fopen(f->path, "r");

  if (f->f == NULL) {
    g_log(G_ERROR, "Could not open file %s", f->path);
    return 0;
  }

  return 1;
}

bool g_read_file_by_bulk(Read_File *f, String_Builder *sb) {
  assert(f->f != NULL && "A File Must be Open");
  if (fseek(f->f, 0, SEEK_END) < 0) {
    f->finished = 1;
    g_log(G_ERROR,
          "The stream is unbuffered or the streams buffer needed to be "
          "flushed. FILE %s",
          f->path);
    return 0;
  }

  long fsize = ftell(f->f);
  if (fsize < 0) {
    f->finished = 1;
    g_log(G_ERROR,
          "The file descriptor underlying stream is not an open file "
          "descriptor %s",
          f->path);
    return 0;
  }

  rewind(f->f);

  sb->count = fsize + 1;
  if (sb->count > sb->capacity) {
    sb->items = (char *)realloc(sb->items, sizeof(char) * sb->count);
    assert(sb->items != NULL && "Buy more RAM!");
    sb->capacity = sb->count;
  }

  size_t readChars = fread(sb->items, 1, fsize, f->f);

  if (readChars != fsize) {
    g_log(G_ERROR, "Could not read entire file: %s", f->path);
  }

  sb->items[readChars] = '\0';

  if (ferror(f->f)) {
    f->finished = 1;
    g_log(G_ERROR, "An error ocurred when reading file: %s", f->path);
    return 0;
  } else {
    f->finished = 1;
    fclose(f->f);
    return 1;
  }
}

bool g_read_file_by_chunk(Read_File *f, String_Builder *sb) {
  assert(sb->capacity > 0 && "Chunk can't be zero or less");
  assert(f->f != NULL && "A File Must be Open");
  size_t readChars = fread(sb->items, 1, sb->capacity - 1, f->f);

  sb->items[readChars] = '\0';

  if (ferror(f->f)) {
    f->finished = 1;
    g_log(G_ERROR, "An error ocurred when reading file: %s", f->path);
    return 0;
  } else if (readChars != sb->capacity - 1) {
    f->finished = 1;
    fclose(f->f);
    return 1;
  }

  return 1;
}

bool g_read_file_by_line(Read_File *f, String_Builder *sb) {
  assert(f->f != NULL && "A File Must be Open");
  sb->count = 0;

  char data = 0;
  while (1) {
    size_t charsRead = fread(&data, 1, 1, f->f);

    if (ferror(f->f)) {
      f->finished = 1;
      g_log(G_ERROR, "An error ocurred when reading file: %s", f->path);
      return 0;
    }

    if (data == '\n' || charsRead == 0) {
      g_da_append(sb, '\0', char *);

      if (charsRead == 0)
        f->finished = 1;

      return 1;
    }

    g_da_append(sb, data, char *);
  }
}

bool g_read_file_by_char(Read_File *f, char *data) {
  assert(f->f != NULL && "A File Must be Open");
  size_t readChars = fread(data, 1, 1, f->f);

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

bool isNumber(char n) { return 48 <= n && n <= 57; }

bool isAlpha(char n) { return 65 <= n && n <= 90 || 97 <= n && n <= 122; }
#endif // G_IMPLEMENTATION
