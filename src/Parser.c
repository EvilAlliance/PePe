#include "./Parser.h"
#include "./G.h"
#include <assert.h>
#include <stdbool.h>
#include <stdlib.h>
#include <string.h>

bool var(TokenList *t, Node *n) { return 0; }
bool func(TokenList *t, Node *n) {
  assert(t != NULL);
  return 0;
}

Node *parseArgs(TokenList** t) {
  TODO("Parse Argumnet of Function");
  return NULL;
}

Expresion parseExpression(TokenList *t) {
  if (t == NULL) {
    printf("Es NULL");
    return (Expresion){0};
  }
  return t->data.literal;
}


Node *parseProgram(TokenList *t) {
    if(t == NULL) return NULL;
  switch (t->type) {
  case TOKEN_TYPE: {
      assert(0 && "Not Possible for now");
  } break;

  case TOKEN_RETURN: {
    Node *node = calloc(1, sizeof(*node));
    node->type = NODE_RETURN;
    assert(t->next != NULL && t->next->type == TOKEN_NUMBER_LITERAL && "No Expretion");
    node->data.expr = parseExpression(t->next);
    t = t->next;
    assert(t->next != NULL && t->next->type == TOKEN_SEMICOLON && "Incomplete Return statemant");
    node->next = parseProgram(t->next->next);
    return node;
  } break;

  case TOKEN_CLOSE_BRACKET :{
      return NULL;
      break;
  };

  default: {
    printf("Unkown %d \n", t->type);
    tokenPrint(t);
    exit(1);
  } break;
  }

  assert(0 && "Unreachable");
  return NULL;
}

Node *parseFunction(TokenList *t) {
  Node *node = calloc(1, sizeof(*node));

  assert(t != NULL && t->type == TOKEN_TYPE);
  Type returnType = t->data.type;
  t = t->next;

  assert(t != NULL && t->type == TOKEN_IDENTIFIER && "Missing Identifier");;
  String_View s = t->data.literal;
  t = t->next;

  assert(t != NULL && t->type == TOKEN_OPEN_BRACES && "Missing Open Braces for the function args");;

  if (s.count == 4 &&
      !strncmp(s.beg, "main", 4)) {
          node->type = NODE_MAIN_FUNCTION;
  }else{

      node->type = NODE_FUNCTION;
  }

  node->data.function = calloc(1, sizeof(NodeFunction));
  node->data.function->returnType = returnType;
  node->data.function->s = s;
  node->data.function->args = parseArgs(&t);
  t = t->next;

  assert(t != NULL && t->type == TOKEN_CLOSE_BRACES && "Missing Close Braces for the function ending args");;
  t = t->next;

  assert(t != NULL && t->type == TOKEN_OPEN_BRACKET && "Missing Open Brakets for the function starting code");;
  t = t->next;

  assert(t != NULL && "Missing Code inside function");

  node->data.function->program = parseProgram(t);

  return node;
}

Node *parseToken(TokenList *t) {
    assert(t != NULL && t->type == TOKEN_TYPE);
    return parseFunction(t);
}


void nodePrint(Node *n) {
  if (n == NULL) {
    printf("\n");
    return;
  }
  switch (n->type) {
  case NODE_FUNCTION: {
    printf("Function name: " SV_FMT "\n", SV_ARGS(n->data.function->s));
    printf("    Args");
    nodePrint(n->data.function->args);
    printf("    Return Type \n");
    printf("        %s Type \n", typeLiteral[n->data.function->returnType.type]);
    printf("        %s BITS \n", bitsLiteral[n->data.function->returnType.size]);
    printf("    Program ");
    nodePrint(n->data.function->program);
  } break;
  case NODE_RETURN: {
    printf("Return " SV_FMT "\n", SV_ARGS(n->data.expr));
  } break;
  case NODE_ARGS: {
    printf("Args\n");
  } break;
  default: {
  } break;
  }
}
