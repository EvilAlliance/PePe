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
  if (**beg == '\0')
    return 0;

  *end = strpbrk(*beg, delimiters);

  if (*beg == *end)
    (*end)++;

  return 1;
}

char *keyWords[TOKEN_MAX] = {
    [TOKEN_OPEN_BRACES] = "(",  [TOKEN_CLOSE_BRACES] = ")",

    [TOKEN_OPEN_BRACKET] = "{", [TOKEN_CLOSE_BRACKET] = "}",

    [TOKEN_SEMICOLON] = ";",

    [TOKEN_RETURN] = "return",

    [TOKEN_IDENTIFIER] = "",    [TOKEN_NUMBER_LITERAL] = "", [TOKEN_TYPE] = "",
};

char *bitsLiteral[BITS_MAX] = {
    [BITS_8] = "8",   [BITS_16] = "16",   [BITS_32] = "32",
    [BITS_64] = "64", [BITS_128] = "128",
};

void tokenParse(char *beg, char *end, TokenList *t) {
  assert(beg < end);
  for (size_t i = 0; i < TOKEN_MAX; i++) {
    if ((end - beg) == strlen(keyWords[i]) &&
        !strncmp(beg, keyWords[i], end - beg)) {
      t->type = i;
      return;
    }
  }
  if (*beg == 'i' && ((end - beg) > 1 && (end - beg) < 5) &&
      isCharsNumber(++beg, end)) {
    t->type = TOKEN_TYPE;
    t->data.type = (Type){
        .type = TYPES_INTEGER,
    };

    for (size_t i = 0; i < BITS_MAX; i++) {
      if (!strncmp(beg, bitsLiteral[i], end - beg)) {
        t->data.type.size = i;
        return;
      }
    }
  }
  char* tempBeg = beg + 1;
  if (isCharsNumber(beg, end) || (*beg == '-' && isCharsNumber(tempBeg, end))) {
    t->type = TOKEN_NUMBER_LITERAL;
    t->data.literal.beg = beg;
    t->data.literal.count = end - beg;
  } else if (isCharsAlpha(beg, end)) {
    t->type = TOKEN_IDENTIFIER;
    t->data.literal.beg = beg;
    t->data.literal.count = end - beg;
  } else {
    printf("Unknown token: %.*s \n", (int)(end - beg), beg);
  }
}

char *literal[TOKEN_MAX] = {
    [TOKEN_OPEN_BRACES] = "OPEN_BRACES",
    [TOKEN_CLOSE_BRACES] = "CLOSE_BRACES",

    [TOKEN_OPEN_BRACKET] = "OPEN_BRACKET",
    [TOKEN_CLOSE_BRACKET] = "CLOSE_BRACES",

    [TOKEN_SEMICOLON] = "SEMICOLON",

    [TOKEN_TYPE] = "TYPE",

    [TOKEN_RETURN] = "RETURN",

    [TOKEN_NUMBER_LITERAL] = "NUMBER_LITERAL",
    [TOKEN_IDENTIFIER] = "INDENTIFIER",
};

char *typeLiteral[TYPES_MAX] = {
    [TYPES_INTEGER] = "Integer",
};

void tokenPrint(TokenList *t) {
  while (t != NULL) {
    printf("%s", literal[t->type]);

    if (t->type == TOKEN_IDENTIFIER || t->type == TOKEN_NUMBER_LITERAL)
      printf(": " SV_FMT, SV_ARGS(t->data.literal));
    else if (t->type == TOKEN_TYPE) {
      printf("\n");
      printf("    - %s Type \n", typeLiteral[t->data.type.type]);
      printf("    - %s BITS", bitsLiteral[t->data.type.size]);
    }
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
