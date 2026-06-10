#include <stdio.h>
#include <string.h>

#define VERSION "1.2.3"

int main(int argc, char **argv) {
    if (argc > 1 && strcmp(argv[1], "--version") == 0) {
        printf("hello %s\n", VERSION);
        return 0;
    }
    if (argc > 1 && argv[1][0] == '-') {
        fprintf(stderr, "hello: unknown option: %s\n", argv[1]);
        return 2;
    }
    printf("Hello, %s!\n", argc > 1 ? argv[1] : "world");
    return 0;
}
