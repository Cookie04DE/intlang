fn main() {
    while(1) {
        choice = read();
        if (choice == 0) {
            write(add(read(), read()));
        };
        if (choice == 1) {
            write(sub(read(), read()));
        };
        if (choice == 2) {
            write(mul(read(), read()));
        };
        if (choice == 3) {
            write(div(read(), read()));
        };
        if (choice == 4) {
            write(mod(read(), read()));
        };
    };
}
fn add(a, b) {
    return a + b;
}
fn sub(a, b) {
    return a - b;
}
fn mul(a, b) {
    return a * b;
}
fn div(a, b) {
    return a / b;
}
fn mod(a, b) {
    return a % b;
}
