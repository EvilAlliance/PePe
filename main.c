#include "./src/Parser.h"
#include <stdlib.h>

#define G_IMPLEMENTATION
#include "./src/G.h"

#define FILE_NAME "./Example/FirstStep.pp"

TokenList *lexFile(String_Builder *sb) {
  char *beg;
  char *end;

  lex(sb->items, &beg, &end);

  TokenList *head = calloc(1, sizeof(*head));
  TokenList *tail = head;

  tokenParse(beg, end, head);

  while (lex(end, &beg, &end)) {
    TokenList *current = calloc(1, sizeof(*head));
    assert(current != NULL && "Buy more RAM");
    tokenParse(beg, end, current);
    current->prev = tail;
    tail->next = current;
    tail = tail->next;
  }

  return head;
}

typedef struct Context {
  bool hasMain;
} Context;

void analisysProgram(Context *ctx, Node *n) {
  TODO("Check if everything in the node are a o k");
}

void codeProgram(Node* n, FILE* f){
    switch (n->type) {
        case NODE_FUNCTION:{
            fprintf(f, SV_FMT": \n",SV_ARGS(n->data.function->s));
            codeProgram(n->data.function->program, f);
        } break;

        case NODE_RETURN:{
            fprintf(f,"    mov rax, 60 \n");
            fprintf(f,"    mov rdi, "SV_FMT" \n", SV_ARGS(n->data.expr));
            fprintf(f,"    syscall");
        } break;

        case NODE_ARGS: default:{

        } break;
    }
}

void generateCode(Node *n) {
    FILE* f = fopen("output.asm", "w");
    fputs("format ELF64 executable \n",f);
    fputs("entry main \n",f);
    fputs("segment readable executable \n",f);

    codeProgram(n, f);
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

  g_read_file_by_bulk(&f, &sb);

  TokenList *head = lexFile(&sb);

  tokenPrint(head);

  Node *n = parseToken(head);
  assert(n != NULL);
  nodePrint(n);

  Context ctx = {0};

  analisysProgram(&ctx, n);

  generateCode(n);

  g_da_free(&sb);

  return 0;
}
