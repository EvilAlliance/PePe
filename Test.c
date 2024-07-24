#include <stdio.h>

int main(void) {
  FILE *f = fopen("./Example/FirstStep.pp", "r");
  printf("%p", f);

  return 0;
}
