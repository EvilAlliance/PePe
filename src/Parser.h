#include "./G.h"
#include "./Lexer.h"

typedef enum NodeType {
  NODE_MAIN_FUNCTION,
  NODE_FUNCTION,
  NODE_ARGS,
  NODE_RETURN,
} NodeType;

typedef String_View Expresion;

typedef struct NodeFunction{
    String_View s;
    Type returnType;
    struct Node *args;
    struct Node *program;
} NodeFunction;

typedef struct Node {
  NodeType type;
  union {
    NodeFunction* function;
    Expresion expr;
  } data;
  struct Node *next;
  struct Node *prev;
} Node;

Node *parseToken(TokenList *t);

void nodePrint(Node *n);
