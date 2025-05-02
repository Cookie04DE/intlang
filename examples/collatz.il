fn main() {
    write(collatz(read()));
    return 0;
}

fn collatz(n) {
    counter = 0;
    while (n != 1) {
        if (n % 2 == 0) {
            n = n / 2;
        } else {
            n = 3 * n + 1;
        };
        counter = counter + 1;
    };
    return counter;
}
