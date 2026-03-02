fn write_str(s) {
    i = 0;

    while(i < s[0]) {
        write_c(s[i+1]);
        i = i + 1;
    };

    return 0;
}

fn main() {
    i = 0;
    while(i < 20) {
        if(i % 3 == 0 & i % 5 == 0) {
            write_str("fizzbuzz\n");
        } else if(i % 3 == 0) {
            write_str("fizz\n");
        } else if(i % 5 == 0) {
            write_str("buzz\n");
        } else {
            write(i);
        };
        i = i + 1;
    };

    return 0;
}
