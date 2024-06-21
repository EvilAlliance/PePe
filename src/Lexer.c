#include "./Lexer.h"
#include "./G.h"

#include <string.h>
#include <assert.h>
#include <stdio.h>
#include <malloc.h>

const char *zoneDelimiters = " \r\t\n";
const char *delimiters = " \r\t\n(){};";
const char *lineComments = "//";

bool isCharsAlpha(char* beg, char* end){
    assert(beg < end);
    while(beg != end){
        if(!isAlpha(*beg)) return 0;
        beg++;
    }
    return 1;
}

bool isCharsNumber(char* beg, char* end){
    assert(beg < end);
    while(beg != end){
        if(!isNumber(*beg)) return 0;
        beg++;
    }
    return 1;
}

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

void tokenParse(char *beg, char *end, TokenList *t) {
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
  }
}

void tokenPrint(TokenList *t) {
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

void tokenFree(TokenList *t) {
  while (t != NULL) {
    free(t);
    t = t->next;
  }
}
