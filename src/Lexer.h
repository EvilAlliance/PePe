#include "./G.h"
#include <stdbool.h>

typedef enum TokenType {
  TOKEN_OPEN_BRACKET,
  TOKEN_CLOSE_BRACKET,

  TOKEN_OPEN_BRACES,
  TOKEN_CLOSE_BRACES,

  TOKEN_SEMICOLON,

  TOKEN_TYPE,

  TOKEN_RETURN,

  TOKEN_IDENTIFIER,
  TOKEN_NUMBER_LITERAL,

  TOKEN_MAX,
} TokenType;

typedef enum TYPES { TYPES_INTEGER, TYPES_MAX } TYPES;

typedef enum BITS {
  BITS_8,
  BITS_16,
  BITS_32,
  BITS_64,
  BITS_128,
  BITS_MAX,
} BITS;

typedef struct Type {
  BITS size;
  TYPES type;
} Type;

typedef struct NumberLiteral{

}NumberLiteral;

typedef struct TokenList {
  TokenType type;
  union {
    Type type;
    String_View literal;
    NumberLiteral numLit;
  } data;
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

extern char* typeLiteral[TYPES_MAX];
extern char* bitsLiteral[BITS_MAX];
