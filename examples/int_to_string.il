fn main() {
    s = i_to_s(420);
    i = 0;
    while(i < s[0]) {
        write_c(s[i+1]);
        i = i + 1;
    };
    write_c('\n');
    s = i_to_s(-1054);
    i = 0;
    while(i < s[0]) {
        write_c(s[i+1]);
        i = i + 1;
    };
    write_c('\n');
    return 0;
}
