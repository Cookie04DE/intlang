fn main() {
    targetDivisor = read();
    skipNumber = read();

    a = 0;
    outer: while (a < 10) {
        a = a + 1;
        if (a % skipNumber == 0) {
            continue outer;
        };

        b = 0;
        inner: while (b < 10) {
            b = b + 1;
            if (b % skipNumber == 0) {
                continue inner;
            };

            product = a * b;
            write(product);

            if (product % targetDivisor == 0) {
                break outer;
            };

            continue inner;
        };
    };

    return 0;
}

