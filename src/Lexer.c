#include "./Lexer.h"
#include "./G.h"
#include <stdio.h>
#include <string.h>

const char *zoneDelimiters = " \r\t\n";
const char *delimiters = " \r\t\n(){};";
const char *lineComments = "//";

bool isCharsAlpha(char *beg, char *end) {
  assert(beg < end);
  while (beg != end) {
    if (!isAlpha(*beg))
      return 0;
    beg++;
  }
  return 1;
}

bool isCharsNumber(char *beg, char *end) {
  assert(beg < end);
  while (beg != end) {
    if (!isNumber(*beg))
      return 0;
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

char *keyWords[MAX] = {
    [OPEN_BRACES] = "(",
    [CLOSE_BRACES] = ")",

    [OPEN_BRACKET] = "{",
    [CLOSE_BRACKET] = "}",

    [SEMICOLON] = ";",

    [INTERGER_8_BIT_TYPE] = "i8",
    [INTERGER_16_BIT_TYPE] = "i16",
    [INTERGER_32_BIT_TYPE] = "i32",
    [INTERGER_64_BIT_TYPE] = "i64",
    [INTERGER_128_BIT_TYPE] = "i128",

    [MAIN] = "main",
    [RETURN] = "return",

    [IDENTIFIER] = "",
    [NUMBER_LITERAL] = "",
};

void tokenParse(char *beg, char *end, TokenList *t) {
  for (size_t i = 0; i < MAX; i++) {
    if ((end - beg) == strlen(keyWords[i]) &&
        !strncmp(beg, keyWords[i], strlen(keyWords[i]))) {
      t->type = i;
      printf("size of token %zu, size of real token %zu\n", (end - beg),
             strlen(keyWords[i]));
      printf("Theorical Token %.*s , Real Token %s\n", (int)(end - beg), beg,
             keyWords[i]);
      tokenPrint(t);
      printf("______________________________________________\n");
      return;
    }
  }
  if (isCharsNumber(beg, end)) {
    t->type = NUMBER_LITERAL;
    t->beg = beg;
    t->end = end;
  } else if (isCharsAlpha(beg, end)) {
    t->type = IDENTIFIER;
    t->beg = beg;
    t->end = end;
  } else {
    printf("Unknown token: %.*s \n", (int)(end - beg), beg);
  }
}

char *literal[MAX] = {
    [OPEN_BRACES] = "OPEN_BRACES",
    [CLOSE_BRACES] = "CLOSE_BRACES",

    [OPEN_BRACKET] = "OPEN_BRACKET",
    [CLOSE_BRACKET] = "CLOSE_BRACES",

    [SEMICOLON] = "SEMICOLON",

    [INTERGER_8_BIT_TYPE] = "8 Bit Integer",
    [INTERGER_16_BIT_TYPE] = "16 Bit Integer",
    [INTERGER_32_BIT_TYPE] = "32 Bit Integer",
    [INTERGER_64_BIT_TYPE] = "64 Bit Integer",
    [INTERGER_128_BIT_TYPE] = "128 Bit Integer",

    [MAIN] = "MAIN",
    [RETURN] = "RETURN",

    [NUMBER_LITERAL] = "NUMBER_LITERAL",
    [IDENTIFIER] = "INDENTIFIER",
};

void tokenPrint(TokenList *t) {
  while (t != NULL) {
    printf("%s", literal[t->type]);

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
