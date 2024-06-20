#define G_USE
#include "./src/G.h"

#include <assert.h>
#include <stdlib.h>
#include <stdio.h>
#include <stdbool.h>
#include <string.h>

#define FILE_NAME "./example/FirstStep.pp"

typedef enum TokenType {
  OPEN_BRACKET,
  CLOSE_BRACKET,

  OPEN_BRACES,
  CLOSE_BRACES,

  SEMICOLON,

  ENTRY,
  INTEGER_TYPE,
  RETURN,

  IDENTIFIER,
  NUMBER_LITERAL,

  MAX,
} TokenType;

typedef struct TokenString {
  char *beg;
  char *end;
} TokenString;

typedef struct TokenList {
  TokenType type;
  char *beg;
  char *end;
  struct TokenList *next;
  struct TokenList *prev;
} TokenList;

const char *zoneDelimiters = " \r\t\n";
const char *delimiters = " \r\t\n(){};";
const char *lineComments = "//";

bool lex(char *src, char **beg, char **end) {
  if (!src)
    return 0;
  *beg = src + strspn(src, zoneDelimiters);
  if (**beg == '\0' || **beg == '\n')
    return 0;

  *end = strpbrk(*beg, delimiters);

  if (*beg == *end)
    (*end)++;

  return 1;
}

bool isNumber(char n){
return 48 <= n && n <= 57;
}

bool isCharsNumber(char* beg, char* end){
    assert(beg < end);
    while(beg != end){
        if(!isNumber(*beg)) return 0;
        beg++;
    }
    return 1;
}

bool isAlpha(char n){
    return 65 <= n && n <= 90 || 97 <= n && n <= 122;
}

bool isCharsAlpha(char* beg, char* end){
    assert(beg < end);
    while(beg != end){
        if(!isAlpha(*beg)) return 0;
        beg++;
    }
    return 1;
}


void parseToken(char *beg, char *end, TokenList *t) {
  assert(MAX == 10 && "Update");
  if (!strncmp(beg, "i", end - beg)) {
    t->type = INTEGER_TYPE;
  } else if (!strncmp(beg, "entry", end - beg)) {
    t->type = ENTRY;
  } else if (!strncmp(beg, "(", end - beg)) {
    t->type = OPEN_BRACKET;
  } else if (!strncmp(beg, ")", end - beg)) {
    t->type = CLOSE_BRACKET;
  } else if (!strncmp(beg, "{", end - beg)) {
    t->type = OPEN_BRACES;
  } else if (!strncmp(beg, "}", end - beg)) {
    t->type = CLOSE_BRACES;
  } else if (!strncmp(beg, "return", end - beg)) {
    t->type = RETURN;
  } else if (!strncmp(beg, ";", end - beg)) {
    t->type = SEMICOLON;
  }else if(isCharsNumber(beg, end)){
      t->type = NUMBER_LITERAL;
      t->beg = beg;
      t->end = end;
  } else if(isCharsAlpha(beg, end)){
    t->type = IDENTIFIER;
    t->beg = beg;
    t->end = end;
  }else {
      printf("Unknown token: %.*s", (int) (end - beg), beg);
      exit(1);
  }
}

void printToken(TokenList *t) {
    assert(MAX == 10);
  while (t != NULL) {
      switch (t->type) {
          case OPEN_BRACES:{
              printf("OPEN_BRACES({)");
              break;
          }
          case CLOSE_BRACES:{
              printf("CLOSE_BRACES(})");
              break;
          }
          case OPEN_BRACKET:{
              printf("OPEN_BRACKET(()");
              break;
          }
          case CLOSE_BRACKET:{
              printf("CLOSE_BRACKET())");
              break;
          }
          case SEMICOLON:{
              printf("SEMICOLON");
              break;
          }
          case ENTRY:{
              printf("ENTRY");
              break;
          }
          case INTEGER_TYPE:{
              printf("INTEGER");
              break;
          }
          case NUMBER_LITERAL:{
              printf("NUMBER:");
              break;
          }
          case IDENTIFIER :{
              printf("IDENTIFIER:");
              break;
          }
          case RETURN: {
              printf("RETURN");
              break;
          }
          case MAX: {
              assert(0 && "Unrechable");
              break;
          }
          default:{
              printf("%d", t->type);
              break;
          }
      }
      if (t->type == IDENTIFIER || t->type == NUMBER_LITERAL)
      printf("    %.*s", (int)(t->end - t->beg), t->beg);
    printf("\n");
    t = t->next;
  }
}

void freeToken(TokenList *t) {
  while (t != NULL) {
    free(t);
    t = t->next;
  }
}

int main(int argc, char *argv[]) {
  Read_File f = {
      .path = FILE_NAME,
  };
  if (!g_start_reading_file(&f)) {
    g_log(G_ERROR, "Could not start reading, file name: %s", FILE_NAME);
    return 1;
  }

  String_Builder sb = {0};
  char *beg;
  char *end;

  g_read_file_by_bulk(&f, &sb);

  lex(sb.items, &beg, &end);

  TokenList *head = calloc(1, sizeof(*head));
  TokenList *tail = head;

  parseToken(beg, end, head);

  while (lex(end, &beg, &end)) {
    TokenList *current = calloc(1, sizeof(*head));
    assert(current != NULL && "Buy more RAM");
    parseToken(beg, end, current);
    current->prev = tail;
    tail->next = current;
    tail = tail->next;
  }
  printToken(head);

  freeToken(head);
  g_da_free(&sb);
  return 0;
}
