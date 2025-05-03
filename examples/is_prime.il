fn main() {
    write(is_prime(read()));
    return 0;
}

fn is_prime(num) {
    counter = 2;
    while(counter < num) {
        if (num % counter == 0) {
            return 0;
        };
        counter = counter + 1;
    };

    return 1;
}
