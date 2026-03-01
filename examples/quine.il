fn main() {
    x = "fn main() {
    x = \"?\";
    i = 0;
    while(i < x[0]) {
        c = x[i+1];
        if(c == 63) {
            j = 0;
            while(j < x[0]) {
                c = x[j+1];
                if(c == '\\\\') {
                    write_c('\\\\');
                    write_c('\\\\');
                } else {
                    if(c == '\"') {
                        write_c('\\\\');
                        write_c('\"');
                    } else {
                        write_c(c);
                    };
                };
                j = j + 1;
            };
        } else {
            write_c(c);
        };
        i = i + 1;
    };

    return 0;
}
";
    i = 0;
    while(i < x[0]) {
        c = x[i+1];
        if(c == 63) {
            j = 0;
            while(j < x[0]) {
                c = x[j+1];
                if(c == '\\') {
                    write_c('\\');
                    write_c('\\');
                } else {
                    if(c == '"') {
                        write_c('\\');
                        write_c('"');
                    } else {
                        write_c(c);
                    };
                };
                j = j + 1;
            };
        } else {
            write_c(c);
        };
        i = i + 1;
    };

    return 0;
}
