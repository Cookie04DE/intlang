fn main() {
    p = malloc(10);
    i = 0;
    while(i < 10) {
        p[i] = i;
        i = i + 1;
    };
    p = realloc(p, 20);
    while(i < 20) {
        p[i] = i;
        i = i + 1;
    };
    sum = 0;
    i = 0;
    while(i < 20) {
        sum = sum + p[i];
        i = i + 1;
    };
    free(p);
    write(sum);
    return 0;
}
