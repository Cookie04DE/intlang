fn main() {
    s = "Hello, World!\n";
    i = 0;
    while(i < s[0]) {
        write_c(s[i+1]);
        i = i + 1;
    };
    return 0;
}
