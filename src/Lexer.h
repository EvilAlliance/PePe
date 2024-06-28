#include <stdbool.h>

typedef enum TokenType {
  OPEN_BRACKET,
  CLOSE_BRACKET,

  OPEN_BRACES,
  CLOSE_BRACES,

  SEMICOLON,

  INTERGER_8_BIT_TYPE,
  INTERGER_16_BIT_TYPE,
  INTERGER_32_BIT_TYPE,
  INTERGER_64_BIT_TYPE,
  INTERGER_128_BIT_TYPE,

  MAIN,
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

extern const char *zoneDelimiters;
extern const char *delimiters;
extern const char *lineComments;

bool lex(char *src, char **beg, char **end);

void tokenParse(char *beg, char *end, TokenList *t);
void tokenPrint(TokenList *t);
void tokenFree(TokenList *t);
