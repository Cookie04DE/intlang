const s_vec_size = 3;
const s_vec_count = 0;
const s_vec_capacity = 1;
const s_vec_data = 2;

fn new_vec() {
    v = malloc(s_vec_size);
    v[s_vec_count] = 0;
    v[s_vec_capacity] = 0;

    return v;
}

// vec needs to be empty or contained elements need not require freeing
fn vec_free(v) {
    if(v[s_vec_capacity]) {
        free(v[s_vec_data]);
    };
    free(v);

    return 0;
}

fn _vec_reserve_one(v) {
    if(!v[s_vec_capacity]) {
        v[s_vec_capacity] = 1;
        v[s_vec_data] = malloc(1);
    } else {
        if(v[s_vec_capacity] == v[s_vec_count]) {
            v[s_vec_capacity] = v[s_vec_capacity] * 2;
            v[s_vec_data] = realloc(v[s_vec_data], v[s_vec_capacity]);
        };
    };

    return 0;
}

fn vec_push(v, i) {
    _vec_reserve_one(v);
    v[s_vec_data][v[s_vec_count]] = i;
    v[s_vec_count] = v[s_vec_count] + 1;

    return 0;
}

fn vec_clone(v) {
    v2 = new_vec();
    v2[s_vec_capacity] = v[s_vec_count];
    if(v[s_vec_count] > 0) {
        v2[s_vec_data] = malloc(v[s_vec_count]);
        i = 0;
        while(i < v[s_vec_count]) {
            vec_push(v2, v[s_vec_data][i]);
            i = i + 1;
        };
    };
    return v2;
}

const s_scanner_size = 2;
const s_scanner_backtrack_vec = 0;
const s_scanner_backtrack_pos = 1;

fn new_scanner() {
    s = malloc(s_scanner_size);
    s[s_scanner_backtrack_vec] = new_vec();
    s[s_scanner_backtrack_pos] = 0;
    return s;
}

fn scanner_free(s) {
    vec_free(s[s_scanner_backtrack_vec]);
    free(s);

    return 0;
}

const eof = -1;

fn scanner_peek(s) {
    if(s[s_scanner_backtrack_pos] < s[s_scanner_backtrack_vec][s_vec_count]) {
        c = s[s_scanner_backtrack_vec][s_vec_data][s[s_scanner_backtrack_pos]];
        return c;
    };
    c = read_c();
    vec_push(s[s_scanner_backtrack_vec], c);
    return c;
}

fn scanner_next(s) {
    // the same as peeking and advancing
    c = scanner_peek(s);
    s[s_scanner_backtrack_pos] = s[s_scanner_backtrack_pos] + 1;
    return c;
}

fn char_is_white(c) {
    return c == '\t' | c == '\n' | c == '\x0C' | c == '\r' | c == ' ';
}

fn scanner_skip_white(s) {
    while(char_is_white(scanner_peek(s))) {
        scanner_next(s);
    };

    return 0;
}

fn scanner_is_keyword(s, keyword_str) {
    old_pos = s[s_scanner_backtrack_pos];
    i = 0;
    while(i < keyword_str[0]) {
        if(scanner_next(s) != keyword_str[i+1]) {
            s[s_scanner_backtrack_pos] = old_pos;
            return 0;
        };
        i = i + 1;
    };

    if(char_is_ident_continue(scanner_peek(s))) {
        s[s_scanner_backtrack_pos] = old_pos;
        return 0;
    };

    return 1;
}

fn scanner_is_str(s, str) {
    old_pos = s[s_scanner_backtrack_pos];
    i = 0;
    while(i < str[0]) {
        if(scanner_next(s) != str[i+1]) {
            s[s_scanner_backtrack_pos] = old_pos;
            return 0;
        };
        i = i + 1;
    };

    return 1;
}

const token_err = 0;
const token_eof = 1;
const token_fn = 2;
const token_const = 3;
const token_break = 4;
const token_continue = 5;
const token_ident = 6; // data is string vec
const token_open_brace = 7;
const token_close_brace = 8;
const token_comma = 9;
const token_colon = 10;
const token_open_curly = 11;
const token_close_curly = 12;
const token_return = 13;
const token_semicolon = 14;
const token_open_square = 15;
const token_close_square = 16;
const token_literal = 17; // data is integer value
const token_string = 18; // data is decoded string vec (no original escape sequences)
const token_if = 19;
const token_else = 20;
const token_while = 21;
const token_double_equal_sign = 22;
const token_exclamation_point_equal_sign = 23;
const token_less_than_sign = 24;
const token_less_than_sign_equal_sign = 25;
const token_greater_than_sign = 26;
const token_greater_than_sign_equal_sign = 27;
const token_exclamation_point = 28;
const token_tilde = 29;
const token_or_sign = 30;
const token_and_sign = 31;
const token_caret = 32;
const token_equal_sign = 33;
const token_plus_sign = 34;
const token_minus_sign = 35;
const token_asterisk = 36;
const token_slash = 37;
const token_percent_sign = 38;

const s_lexeme_size = 2;
const s_lexeme_token = 0;
const s_lexeme_data = 1;

fn new_lexeme(token) {
    l = malloc(s_lexeme_size);
    l[s_lexeme_token] = token;

    return l;
}

fn lexeme_free(l) {
    if(l[s_lexeme_token] == token_ident | l[s_lexeme_token] == token_string) {
        vec_free(l[s_lexeme_data]);
    };
    free(l);

    return 0;
}

fn char_is_ident_start(c) {
    return c >= 'a' & c <= 'z' | c >= 'A' & c <= 'Z' | c == '_';
}

fn char_is_ident_continue(c) {
    return char_is_ident_start(c) | c >= '0' & c <= '9';
}

const scanner_escaped_char_eof = -1;
const scanner_escaped_char_invalid_sequence = -2;
const scanner_escaped_char_no_match = -3;

// scans only the escape sequence, i.e. \n, \x0C, etc.
fn scanner_next_escaped_char(s) {
    c = scanner_peek(s);
    if(c == eof) {
        return scanner_escaped_char_eof;
    } else if(c != '\\') {
        return scanner_escaped_char_no_match;
    };

    scanner_next(s);
    c = scanner_next(s);

    if(c == eof) {
        return scanner_escaped_char_eof;
    } else if(c == '0') {
        return '\0';
    } else if(c == 't') {
        return '\t';
    } else if(c == 'r') {
        return '\r';
    } else if(c == '\\') {
        return '\\';
    } else if(c == 'n') {
        return '\n';
    } else if(c == '"') {
        return '"';
    } else if(c == '\'') {
        return '\'';
    } else if(c == 'x') {
        first = scanner_next(s);
        if(first == eof) {
            return scanner_escaped_char_eof;
        };

        if(first < '0' | first > '7') {
            return scanner_escaped_char_invalid_sequence;
        };

        first = first - '0';

        second = scanner_next(s);
        if(second == eof) {
            return scanner_escaped_char_eof;
        };

        if(second >= '0' & second <= '9') {
            second = second - '0';
        } else if(second >= 'a' & second <= 'f') {
            second = second - 'a' + 10;
        } else if(second >= 'A' & second <= 'F') {
            second = second - 'A' + 10;
        } else {
            return scanner_escaped_char_invalid_sequence;
        };

        return first * 16 + second;
    };

    return scanner_escaped_char_invalid_sequence;
}

fn scanner_next_lexeme(s) {
    lex: while(1) {
        scanner_skip_white(s);
        if(scanner_peek(s) == eof) {
            return new_lexeme(token_eof);
        } else if(scanner_is_str(s, "//")) {
            while(scanner_peek(s) != '\n') {
                if(scanner_peek(s) == eof) {
                    return new_lexeme(token_eof);
                };
                scanner_next(s);
            };

            scanner_next(s);
            continue lex;
        } else if(scanner_is_str(s, "/*")) {
            while(!scanner_is_str(s, "*/")) {
                if(scanner_next(s) == eof) {
                    return new_lexeme(token_err);
                };
            };

            continue lex;
        } else if(scanner_is_keyword(s, "fn")) {
            return new_lexeme(token_fn);
        } else if(scanner_is_keyword(s, "continue")) {
            return new_lexeme(token_continue);
        } else if(scanner_is_keyword(s, "const")) {
            return new_lexeme(token_const);
        } else if(scanner_is_keyword(s, "return")) {
            return new_lexeme(token_return);
        } else if (scanner_is_keyword(s, "break")) {
            return new_lexeme(token_break);
        } else if (scanner_is_keyword(s, "if")) {
            return new_lexeme(token_if);
        } else if (scanner_is_keyword(s, "else")) {
            return new_lexeme(token_else);
        } else if (scanner_is_keyword(s, "while")) {
            return new_lexeme(token_while);
        } else if(char_is_ident_start(scanner_peek(s))) {
            l = new_lexeme(token_ident);
            l[s_lexeme_data] = new_vec();
            vec_push(l[s_lexeme_data], scanner_next(s));

            while(char_is_ident_continue(scanner_peek(s))) {
                vec_push(l[s_lexeme_data], scanner_next(s));
            };

            return l;
        } else if(scanner_peek(s) == '(') {
            scanner_next(s);
            return new_lexeme(token_open_brace);
        } else if(scanner_peek(s) == ')') {
            scanner_next(s);
            return new_lexeme(token_close_brace);
        } else if(scanner_peek(s) == ',') {
            scanner_next(s);
            return new_lexeme(token_comma);
        } else if(scanner_peek(s) == '{') {
            scanner_next(s);
            return new_lexeme(token_open_curly);
        } else if(scanner_peek(s) == '}') {
            scanner_next(s);
            return new_lexeme(token_close_curly);
        } else if(scanner_peek(s) == ';') {
            scanner_next(s);
            return new_lexeme(token_semicolon);
        } else if(scanner_peek(s) == ':') {
            scanner_next(s);
            return new_lexeme(token_colon);
        } else if(scanner_peek(s) == '[') {
            scanner_next(s);
            return new_lexeme(token_open_square);
        } else if(scanner_peek(s) == ']') {
            scanner_next(s);
            return new_lexeme(token_close_square);
        } else if(scanner_peek(s) == '\'') {
            scanner_next(s);
            l = new_lexeme(token_literal);

            escaped = scanner_next_escaped_char(s);
            if(escaped >= 0) {
                l[s_lexeme_data] = escaped;
            } else if(escaped == scanner_escaped_char_no_match) {
                l[s_lexeme_data] = scanner_next(s);
            } else if(escaped == scanner_escaped_char_eof | escaped == scanner_escaped_char_invalid_sequence) {
                lexeme_free(l);
                return new_lexeme(token_err);
            };

            if(scanner_next(s) != '\'') {
                lexeme_free(l);
                return new_lexeme(token_err);
            };

            return l;
        } else if(scanner_peek(s) >= '0' & scanner_peek(s) <= '9') {
            num = 0;
            c = scanner_peek(s);
            while(c >= '0' & c <= '9') {
                scanner_next(s);
                num = num * 10 + c - '0';
                c = scanner_peek(s);
            };
            l = new_lexeme(token_literal);
            l[s_lexeme_data] = num;
            return l;
        } else if(scanner_peek(s) == '"') {
            scanner_next(s);
            l = new_lexeme(token_string);
            l[s_lexeme_data] = new_vec();

            while(scanner_peek(s) != '"') {
                escaped = scanner_next_escaped_char(s);
                if(escaped >= 0) {
                    vec_push(l[s_lexeme_data], escaped);
                } else if(escaped == scanner_escaped_char_no_match) {
                    vec_push(l[s_lexeme_data], scanner_next(s));
                } else if(escaped == scanner_escaped_char_eof | escaped == scanner_escaped_char_invalid_sequence) {
                    vec_free(l[s_lexeme_data]);
                    lexeme_free(l);
                    return new_lexeme(token_err);
                };
            };

            scanner_next(s);

            return l;
        } else if(scanner_peek(s) == '!') {
            scanner_next(s);
            c = scanner_peek(s);

            if(c == '=') {
                scanner_next(s);
                return new_lexeme(token_exclamation_point_equal_sign);
            } else {
                return new_lexeme(token_exclamation_point);
            };
        } else if(scanner_peek(s) == '=') {
            scanner_next(s);
            c = scanner_peek(s);

            if(c == '=') {
                scanner_next(s);
                return new_lexeme(token_double_equal_sign);
            } else {
                return new_lexeme(token_equal_sign);
            };
        } else if(scanner_peek(s) == '<') {
            scanner_next(s);
            c = scanner_peek(s);

            if(c == '=') {
                scanner_next(s);
                return new_lexeme(token_less_than_sign_equal_sign);
            } else {
                return new_lexeme(token_less_than_sign);
            };
        } else if(scanner_peek(s) == '>') {
            scanner_next(s);
            c = scanner_peek(s);

            if(c == '=') {
                scanner_next(s);
                return new_lexeme(token_greater_than_sign_equal_sign);
            } else {
                return new_lexeme(token_greater_than_sign);
            };
        } else if(scanner_peek(s) == '~') {
            scanner_next(s);
            return new_lexeme(token_tilde);
        } else if(scanner_peek(s) == '|') {
            scanner_next(s);
            return new_lexeme(token_or_sign);
        } else if(scanner_peek(s) == '&') {
            scanner_next(s);
            return new_lexeme(token_and_sign);
        } else if(scanner_peek(s) == '^') {
            scanner_next(s);
            return new_lexeme(token_caret);
        } else if(scanner_peek(s) == '+') {
            scanner_next(s);
            return new_lexeme(token_plus_sign);
        } else if(scanner_peek(s) == '-') {
            scanner_next(s);
            return new_lexeme(token_minus_sign);
        } else if(scanner_peek(s) == '*') {
            scanner_next(s);
            return new_lexeme(token_asterisk);
        } else if(scanner_peek(s) == '/') {
            scanner_next(s);
            return new_lexeme(token_slash);
        } else if(scanner_peek(s) == '%') {
            scanner_next(s);
            return new_lexeme(token_percent_sign);
        };

        return new_lexeme(token_err);
    };
}

const s_parser_size = 2;
const s_parser_lexemes_vec = 0;
const s_parser_pos = 1;

fn new_parser(lexemes) {
    p = malloc(s_parser_size);
    p[s_parser_lexemes_vec] = lexemes;
    p[s_parser_pos] = 0;

    return p;
}

fn parser_reset_pos(p, pos) {
    p[s_parser_pos] = pos;
    return 0;
}

fn parser_free(p) {
    lexemes = p[s_parser_lexemes_vec];
    i = 0;
    while(i < lexemes[s_vec_count]) {
        lexeme_free(lexemes[s_vec_data][i]);
        i = i + 1;
    };
    vec_free(lexemes);
    free(p);

    return 0;
}

fn parser_peek(p) {
    if(p[s_parser_pos] == p[s_parser_lexemes_vec][s_vec_count]) {
        return eof;
    };

    return p[s_parser_lexemes_vec][s_vec_data][p[s_parser_pos]];
}

fn parser_peek_token(p) {
    l = parser_peek(p);
    if(l == eof) {
        return token_eof;
    };
    return l[s_lexeme_token];
}

fn parser_next(p) {
    l = parser_peek(p);
    if(l == eof) {
        return eof;
    };
    p[s_parser_pos] = p[s_parser_pos] + 1;

    return l;
}

fn parser_next_token(p) {
    l = parser_next(p);
    if(l == eof) {
        return token_eof;
    };
    return l[s_lexeme_token];
}

const parser_parse_fail = -1;

const constant_kind_int = 0;
const constant_kind_string = 1;

const s_constant_size = 3;
const s_constant_name_vec = 0;
const s_constant_kind = 1;
const s_constant_value = 2;

fn new_constant(name, kind, value) {
    c = malloc(s_constant_size);
    c[s_constant_name_vec] = name;
    c[s_constant_kind] = kind;
    c[s_constant_value] = value;

    return c;
}

fn constant_free(c) {
    vec_free(c[s_constant_name_vec]);
    if(c[s_constant_kind] == constant_kind_string) {
        vec_free(c[s_constant_value]);
    };
    free(c);

    return 0;
}

// returns a heap pointer to enable indicating failure
fn parser_parse_literal(p) {
    l = parser_next(p);

    if(l == eof) {
        return parser_parse_fail;
    } else if((t = l[s_lexeme_token]) == token_literal) {
        r = malloc(1);
        r[0] = l[s_lexeme_data];
        return r;
    } else if(t == token_minus_sign) {
        factor = -1;
    } else if(t == token_plus_sign) {
        factor = 1;
    } else {
        return parser_parse_fail;
    };

    if((l = parser_next(p)) == eof) {
        return parser_parse_fail;
    };

    if(l[s_lexeme_token] != token_literal) {
        return parser_parse_fail;
    };

    r = malloc(1);
    r[0] = factor * l[s_lexeme_data];

    return r;
}

// expect the next lexeme to be a specific token and return the tokens data
fn parser_next_token_and_data(p, token) {
    if((ident = parser_next(p)) == eof) {
        return parser_parse_fail;
    };
    if(ident[s_lexeme_token] != token) {
        return parser_parse_fail;
    };

    return ident[s_lexeme_data];
}

fn parser_parse_constant(p) {
    if(parser_next_token(p) != token_const) {
        return parser_parse_fail;
    };

    if((name = parser_next_token_and_data(p, token_ident)) == parser_parse_fail) {
        return parser_parse_fail;
    };

    if(parser_next_token(p) != token_equal_sign) {
        return parser_parse_fail;
    };

    prev_pos = p[s_parser_pos];

    if((int = parser_parse_literal(p)) != parser_parse_fail) {
        c = new_constant(vec_clone(name), constant_kind_int, int[0]);
        free(int);
    } else {
        p[s_parser_pos] = prev_pos;

        if((string = parser_next_token_and_data(p, token_string)) == parser_parse_fail) {
            return parser_parse_fail;
        };

        c = new_constant(vec_clone(name), constant_kind_string, vec_clone(string));
    };

    if(parser_next_token(p) != token_semicolon) {
        constant_free(c);
        return parser_parse_fail;
    };
    return c;
}

const s_expression_size = 2;
const s_expression_kind = 0;
const s_expression_data = 1;

fn new_expression(kind, data) {
    e = malloc(s_expression_size);
    e[s_expression_kind] = kind;
    e[s_expression_data] = data;

    return e;
}

fn parser_parse_base_expression(p) {
    prev_pos = p[s_parser_pos];

    if((expr = parser_parse_expression_function_call(p)) != parser_parse_fail) {
        return expr;
    } else if(parser_reset_pos(p, prev_pos) | (expr = parser_parse_braced_expression(p)) != parser_parse_fail) {
        return expr;
    } else if(parser_reset_pos(p, prev_pos) | (expr = parser_parse_expression_literal(p)) != parser_parse_fail) {
        return expr;
    } else if(parser_reset_pos(p, prev_pos) | (expr = parser_parse_expression_ident(p)) != parser_parse_fail) {
        return expr;
    } else if(parser_reset_pos(p, prev_pos) | (expr = parser_parse_expression_string(p)) != parser_parse_fail) {
        return expr;
    };

    return parser_parse_fail;
}

fn prefix_operator_binding_power(operator_token) {
    if(operator_token == token_minus_sign) {
        return 8 * 2;
    } else if(operator_token == token_exclamation_point) {
        return 8 * 2;
    } else if(operator_token == token_tilde) {
        return 8 * 2;
    };

    return 0;
}

fn prefix_expression(operator_token, operand) {
    if(operator_token == token_minus_sign) {
        return new_expression_negation(operand);
    } else if(operator_token == token_exclamation_point) {
        return new_expression_logical_not(operand);
    } else if(operator_token == token_tilde) {
        return new_expression_bitwise_not(operand);
    };
}

const s_infix_operator_binding_power_size = 2;
const s_infix_operator_binding_power_left = 0;
const s_infix_operator_binding_power_right = 1;

fn new_infix_operator_binding_power(left, right) {
    bp = malloc(s_infix_operator_binding_power_size);

    bp[s_infix_operator_binding_power_left] = left;
    bp[s_infix_operator_binding_power_right] = right;

    return bp;
}

fn infix_operator_binding_power_free(bp) {
    free(bp);

    return 0;
}

fn infix_operator_binding_power_left(original) {
    return new_infix_operator_binding_power(original * 2, original * 2 + 1);
}

fn infix_operator_binding_power_right(original) {
    return new_infix_operator_binding_power(original * 2 + 1, original * 2);
}

fn infix_operator_binding_power(operator_token) {
    if(operator_token == token_equal_sign) {
        return infix_operator_binding_power_right(0);
    } else if(operator_token == token_or_sign) {
        return infix_operator_binding_power_left(1);
    } else if(operator_token == token_caret) {
        return infix_operator_binding_power_left(2);
    } else if(operator_token == token_and_sign) {
        return infix_operator_binding_power_left(3);
    } else if(operator_token == token_double_equal_sign | operator_token == token_exclamation_point_equal_sign) {
        return infix_operator_binding_power_left(4);
    } else if(operator_token == token_less_than_sign | operator_token == token_less_than_sign_equal_sign | operator_token == token_greater_than_sign | operator_token == token_greater_than_sign_equal_sign) {
        return infix_operator_binding_power_left(5);
    } else if(operator_token == token_plus_sign | operator_token == token_minus_sign) {
        return infix_operator_binding_power_left(6);
    } else if(operator_token == token_asterisk | operator_token == token_slash | operator_token == token_percent_sign) {
        return infix_operator_binding_power_left(7);
    };

    return 0;
}

fn infix_expression(lhs, operator_token, rhs) {
    if(operator_token == token_equal_sign) {
        return new_expression_assignment(lhs, rhs);
    } else if(operator_token == token_or_sign) {
        return new_expression_or(lhs, rhs);
    } else if(operator_token == token_caret) {
        return new_expression_xor(lhs, rhs);
    } else if(operator_token == token_and_sign) {
        return new_expression_and(lhs, rhs);
    } else if(operator_token == token_double_equal_sign) {
        return new_expression_equal(lhs, rhs);
    } else if(operator_token == token_exclamation_point_equal_sign) {
        return new_expression_not_equal(lhs, rhs);
    } else if(operator_token == token_less_than_sign) {
        return new_expression_less_than(lhs, rhs);
    } else if(operator_token == token_less_than_sign_equal_sign) {
        return new_expression_less_than_or_equal_to(lhs, rhs);
    } else if(operator_token == token_greater_than_sign) {
        return new_expression_greater_than(lhs, rhs);
    } else if(operator_token == token_greater_than_sign_equal_sign) {
        return new_expression_greater_than_or_equal_to(lhs, rhs);
    } else if(operator_token == token_plus_sign) {
        return new_expression_add(lhs, rhs);
    } else if(operator_token == token_minus_sign) {
        return new_expression_sub(lhs, rhs);
    } else if(operator_token == token_asterisk) {
        return new_expression_mul(lhs, rhs);
    } else if(operator_token == token_slash) {
        return new_expression_div(lhs, rhs);
    } else if(operator_token == token_percent_sign) {
        return new_expression_mod(lhs, rhs);
    };
}

fn parser_pratt_parse_expression(p, min_power) {
    if(power = prefix_operator_binding_power(operator = parser_peek_token(p))) {
        parser_next_token(p);
        operand = parser_pratt_parse_expression(p, power);
        lhs = prefix_expression(operator, operand);
    } else {
        if((lhs = parser_parse_base_expression(p)) == parser_parse_fail) {
            return parser_parse_fail;
        };
    };

    while(1) {
        if(bp = infix_operator_binding_power(operator = parser_peek_token(p))) {
            if(bp[s_infix_operator_binding_power_left] <= min_power) {
                infix_operator_binding_power_free(bp);
                break;
            };
            parser_next_token(p);
            if((rhs = parser_pratt_parse_expression(p, bp[s_infix_operator_binding_power_right])) == parser_parse_fail) {
                infix_operator_binding_power_free(bp);
                expression_free(lhs);
                return parser_parse_fail;
            };
            lhs = infix_expression(lhs, operator, rhs);
            infix_operator_binding_power_free(bp);

            continue;
        } else if(operator == token_open_square) {
            if(9 * 2 <= min_power) {
                break;
            };
            parser_next_token(p);
            if((index = parser_parse_expression(p)) == parser_parse_fail) {
                expression_free(lhs);
                return parser_parse_fail;
            };
            lhs = new_expression_index(lhs, index);
            if(parser_next_token(p) != token_close_square) {
                expression_free(lhs);
                return parser_parse_fail;
            };

            continue;
        };

        break;
    };

    return lhs;
}

fn parser_parse_expression(p) {
    return parser_pratt_parse_expression(p, 0);
}

fn parser_parse_braced_expression(p) {
    if(parser_next_token(p) != token_open_brace) {
        return parser_parse_fail;
    };

    if((expr = parser_parse_expression(p)) == parser_parse_fail) {
        return parser_parse_fail;
    };

    if(parser_next_token(p) != token_close_brace) {
        expression_free(expr);
        return parser_parse_fail;
    };

    return expr;
}

const expression_ident = 0;
const s_expression_ident_size = 1;
const s_expression_ident_ident = 0;

fn new_expression_ident(ident) {
    e = malloc(s_expression_ident_size);
    e[s_expression_ident_ident] = ident;

    return new_expression(expression_ident, e);
}

fn parser_parse_expression_ident(p) {
    if ((ident = parser_next_token_and_data(p, token_ident)) == parser_parse_fail) {
        return parser_parse_fail;
    };

    return new_expression_ident(vec_clone(ident));
}

fn expression_ident_free(e) {
    vec_free(e[s_expression_ident_ident]);
    free(e);

    return 0;
}

const expression_function_call = 1;
const s_expression_function_call_size = 2;
const s_expression_function_call_function_name = 0;
const s_expression_function_call_arg_vec = 1;

fn new_expression_function_call(function_name, args) {
    e = malloc(s_expression_function_call_size);
    e[s_expression_function_call_function_name] = function_name;
    e[s_expression_function_call_arg_vec] = args;

    return new_expression(expression_function_call, e);
}

fn free_expression_vec(exprs) {
    i = 0;
    while(i < exprs[s_vec_count]) {
        expression_free(exprs[s_vec_data][i]);
        i = i + 1;
    };

    vec_free(exprs);

    return 0;
}

fn parser_parse_expression_function_call(p) {
    if((ident = parser_next_token_and_data(p, token_ident)) == parser_parse_fail) {
        return parser_parse_fail;
    };

    if(parser_next_token(p) != token_open_brace) {
        return parser_parse_fail;
    };

    args = new_vec();
    if(parser_peek_token(p) == token_close_brace) {
        parser_next_token(p);
        return new_expression_function_call(vec_clone(ident), args);
    };

    if((arg = parser_parse_expression(p)) == parser_parse_fail) {
        vec_free(args);
        return parser_parse_fail;
    };

    vec_push(args, arg);

    while(1) {
        comma_or_close_brace = parser_next(p);
        if(comma_or_close_brace == eof) {
            free_expression_vec(args);
            return parser_parse_fail;
        } else if(comma_or_close_brace[s_lexeme_token] == token_close_brace) {
            return new_expression_function_call(vec_clone(ident), args);
        } else if(comma_or_close_brace[s_lexeme_token] == token_comma) {
            // no-op
        } else {
            free_expression_vec(args);
            return parser_parse_fail;
        };

        if((arg = parser_parse_expression(p)) == parser_parse_fail) {
            free_expression_vec(args);
            return parser_parse_fail;
        };

        vec_push(args, arg);
    };
}

fn expression_function_call_free(e) {
    vec_free(e[s_expression_function_call_function_name]);
    free_expression_vec(e[s_expression_function_call_arg_vec]);
    free(e);

    return 0;
}

const expression_index = 2;
const s_expression_index_size = 2;
const s_expression_index_base = 0;
const s_expression_index_index = 1;

fn new_expression_index(base, index) {
    e = malloc(s_expression_index_size);
    e[s_expression_index_base] = base;
    e[s_expression_index_index] = index;

    return new_expression(expression_index, e);
}

fn expression_index_free(e) {
    expression_free(e[s_expression_index_base]);
    expression_free(e[s_expression_index_index]);
    free(e);

    return 0;
}

const expression_literal = 3;
const s_expression_literal_size = 1;
const s_expression_literal_value = 0;

fn new_expression_literal(value) {
    e = malloc(s_expression_literal_size);
    e[s_expression_literal_value] = value;

    return new_expression(expression_literal, e);
}

fn parser_parse_expression_literal(p) {
    if((literal = parser_parse_literal(p)) == parser_parse_fail) {
        return parser_parse_fail;
    };

    value = literal[0];
    free(literal);

    return new_expression_literal(value);
}

fn expression_literal_free(e) {
    free(e);

    return 0;
}

const expression_string = 4;
const s_expression_string_size = 1;
const s_expression_string_string = 0;

fn new_expression_string(string) {
    e = malloc(s_expression_string_size);
    e[s_expression_string_string] = string;

    return new_expression(expression_string, e);
}

fn parser_parse_expression_string(p) {
    if((literal = parser_next_token_and_data(p, token_string)) == parser_parse_fail) {
        return parser_parse_fail;
    };

    return new_expression_string(vec_clone(literal));
}

fn expression_string_free(e) {
    vec_free(e[s_expression_string_string]);
    free(e);

    return 0;
}

const expression_negation = 5;
const s_expression_negation_size = 1;
const s_expression_negation_expr = 0;

fn new_expression_negation(expr) {
    e = malloc(s_expression_negation_size);
    e[s_expression_negation_expr] = expr;

    return new_expression(expression_negation, e);
}

fn expression_negation_free(e) {
    expression_free(e[s_expression_negation_expr]);
    free(e);

    return 0;
}

const expression_equal = 6;
const s_expression_equal_size = 2;
const s_expression_equal_first = 0;
const s_expression_equal_second = 1;

fn new_expression_equal(first, second) {
    e = malloc(s_expression_equal_size);
    e[s_expression_equal_first] = first;
    e[s_expression_equal_second] = second;

    return new_expression(expression_equal, e);
}

fn expression_equal_free(e) {
    expression_free(e[s_expression_equal_first]);
    expression_free(e[s_expression_equal_second]);
    free(e);

    return 0;
}

const expression_not_equal = 7;
const s_expression_not_equal_size = 2;
const s_expression_not_equal_first = 0;
const s_expression_not_equal_second = 1;

fn new_expression_not_equal(first, second) {
    e = malloc(s_expression_not_equal_size);
    e[s_expression_not_equal_first] = first;
    e[s_expression_not_equal_second] = second;

    return new_expression(expression_not_equal, e);
}

fn expression_not_equal_free(e) {
    expression_free(e[s_expression_not_equal_first]);
    expression_free(e[s_expression_not_equal_second]);
    free(e);

    return 0;
}

const expression_less_than = 8;
const s_expression_less_than_size = 2;
const s_expression_less_than_first = 0;
const s_expression_less_than_second = 1;

fn new_expression_less_than(first, second) {
    e = malloc(s_expression_less_than_size);
    e[s_expression_less_than_first] = first;
    e[s_expression_less_than_second] = second;

    return new_expression(expression_less_than, e);
}

fn expression_less_than_free(e) {
    expression_free(e[s_expression_less_than_first]);
    expression_free(e[s_expression_less_than_second]);
    free(e);

    return 0;
}

const expression_less_than_or_equal_to = 9;
const s_expression_less_than_or_equal_to_size = 2;
const s_expression_less_than_or_equal_to_first = 0;
const s_expression_less_than_or_equal_to_second = 1;

fn new_expression_less_than_or_equal_to(first, second) {
    e = malloc(s_expression_less_than_or_equal_to_size);
    e[s_expression_less_than_or_equal_to_first] = first;
    e[s_expression_less_than_or_equal_to_second] = second;

    return new_expression(expression_less_than_or_equal_to, e);
}

fn expression_less_than_or_equal_to_free(e) {
    expression_free(e[s_expression_less_than_or_equal_to_first]);
    expression_free(e[s_expression_less_than_or_equal_to_second]);
    free(e);

    return 0;
}

const expression_greater_than = 10;
const s_expression_greater_than_size = 2;
const s_expression_greater_than_first = 0;
const s_expression_greater_than_second = 1;

fn new_expression_greater_than(first, second) {
    e = malloc(s_expression_greater_than_size);
    e[s_expression_greater_than_first] = first;
    e[s_expression_greater_than_second] = second;

    return new_expression(expression_greater_than, e);
}

fn expression_greater_than_free(e) {
    expression_free(e[s_expression_greater_than_first]);
    expression_free(e[s_expression_greater_than_second]);
    free(e);

    return 0;
}

const expression_greater_than_or_equal_to = 11;
const s_expression_greater_than_or_equal_to_size = 2;
const s_expression_greater_than_or_equal_to_first = 0;
const s_expression_greater_than_or_equal_to_second = 1;

fn new_expression_greater_than_or_equal_to(first, second) {
    e = malloc(s_expression_greater_than_or_equal_to_size);
    e[s_expression_greater_than_or_equal_to_first] = first;
    e[s_expression_greater_than_or_equal_to_second] = second;

    return new_expression(expression_greater_than_or_equal_to, e);
}

fn expression_greater_than_or_equal_to_free(e) {
    expression_free(e[s_expression_greater_than_or_equal_to_first]);
    expression_free(e[s_expression_greater_than_or_equal_to_second]);
    free(e);

    return 0;
}

const expression_logical_not = 12;
const s_expression_logical_not_size = 1;
const s_expression_logical_not_expr = 0;

fn new_expression_logical_not(expr) {
    e = malloc(s_expression_logical_not_size);
    e[s_expression_logical_not_expr] = expr;

    return new_expression(expression_logical_not, e);
}

fn expression_logical_not_free(e) {
    expression_free(e[s_expression_logical_not_expr]);
    free(e);

    return 0;
}

const expression_bitwise_not = 13;
const s_expression_bitwise_not_size = 1;
const s_expression_bitwise_not_expr = 0;

fn new_expression_bitwise_not(expr) {
    e = malloc(s_expression_bitwise_not_size);
    e[s_expression_bitwise_not_expr] = expr;

    return new_expression(expression_bitwise_not, e);
}

fn expression_bitwise_not_free(e) {
    expression_free(e[s_expression_bitwise_not_expr]);
    free(e);

    return 0;
}

const expression_or = 14;
const s_expression_or_size = 2;
const s_expression_or_first = 0;
const s_expression_or_second = 1;

fn new_expression_or(first, second) {
    e = malloc(s_expression_or_size);
    e[s_expression_or_first] = first;
    e[s_expression_or_second] = second;

    return new_expression(expression_or, e);
}

fn expression_or_free(e) {
    expression_free(e[s_expression_or_first]);
    expression_free(e[s_expression_or_second]);
    free(e);

    return 0;
}

const expression_and = 15;
const s_expression_and_size = 2;
const s_expression_and_first = 0;
const s_expression_and_second = 1;

fn new_expression_and(first, second) {
    e = malloc(s_expression_and_size);
    e[s_expression_and_first] = first;
    e[s_expression_and_second] = second;

    return new_expression(expression_and, e);
}

fn expression_and_free(e) {
    expression_free(e[s_expression_and_first]);
    expression_free(e[s_expression_and_second]);
    free(e);

    return 0;
}

const expression_xor = 16;
const s_expression_xor_size = 2;
const s_expression_xor_first = 0;
const s_expression_xor_second = 1;

fn new_expression_xor(first, second) {
    e = malloc(s_expression_xor_size);
    e[s_expression_xor_first] = first;
    e[s_expression_xor_second] = second;

    return new_expression(expression_xor, e);
}

fn expression_xor_free(e) {
    expression_free(e[s_expression_xor_first]);
    expression_free(e[s_expression_xor_second]);
    free(e);

    return 0;
}

const expression_add = 17;
const s_expression_add_size = 2;
const s_expression_add_first = 0;
const s_expression_add_second = 1;

fn new_expression_add(first, second) {
    e = malloc(s_expression_add_size);
    e[s_expression_add_first] = first;
    e[s_expression_add_second] = second;

    return new_expression(expression_add, e);
}

fn expression_add_free(e) {
    expression_free(e[s_expression_add_first]);
    expression_free(e[s_expression_add_second]);
    free(e);

    return 0;
}

const expression_sub = 18;
const s_expression_sub_size = 2;
const s_expression_sub_first = 0;
const s_expression_sub_second = 1;

fn new_expression_sub(first, second) {
    e = malloc(s_expression_sub_size);
    e[s_expression_sub_first] = first;
    e[s_expression_sub_second] = second;

    return new_expression(expression_sub, e);
}

fn expression_sub_free(e) {
    expression_free(e[s_expression_sub_first]);
    expression_free(e[s_expression_sub_second]);
    free(e);

    return 0;
}

const expression_mul = 19;
const s_expression_mul_size = 2;
const s_expression_mul_first = 0;
const s_expression_mul_second = 1;

fn new_expression_mul(first, second) {
    e = malloc(s_expression_mul_size);
    e[s_expression_mul_first] = first;
    e[s_expression_mul_second] = second;

    return new_expression(expression_mul, e);
}

fn expression_mul_free(e) {
    expression_free(e[s_expression_mul_first]);
    expression_free(e[s_expression_mul_second]);
    free(e);

    return 0;
}

const expression_div = 20;
const s_expression_div_size = 2;
const s_expression_div_first = 0;
const s_expression_div_second = 1;

fn new_expression_div(first, second) {
    e = malloc(s_expression_div_size);
    e[s_expression_div_first] = first;
    e[s_expression_div_second] = second;

    return new_expression(expression_div, e);
}

fn expression_div_free(e) {
    expression_free(e[s_expression_div_first]);
    expression_free(e[s_expression_div_second]);
    free(e);

    return 0;
}

const expression_mod = 21;
const s_expression_mod_size = 2;
const s_expression_mod_first = 0;
const s_expression_mod_second = 1;

fn new_expression_mod(first, second) {
    e = malloc(s_expression_mod_size);
    e[s_expression_mod_first] = first;
    e[s_expression_mod_second] = second;

    return new_expression(expression_mod, e);
}

fn expression_mod_free(e) {
    expression_free(e[s_expression_mod_first]);
    expression_free(e[s_expression_mod_second]);
    free(e);

    return 0;
}

const expression_assignment = 22;
const s_expression_assignment_size = 2;
const s_expression_assignment_target = 0;
const s_expression_assignment_expr = 1;

fn new_expression_assignment(target, expr) {
    e = malloc(s_expression_assignment_size);
    e[s_expression_assignment_target] = target;
    e[s_expression_assignment_expr] = expr;

    return new_expression(expression_assignment, e);
}

fn expression_assignment_free(e) {
    expression_free(e[s_expression_assignment_target]);
    expression_free(e[s_expression_assignment_expr]);
    free(e);

    return 0;
}

fn expression_free(e) {
    if((kind = e[s_expression_kind]) == expression_ident) {
        expression_ident_free(e[s_expression_data]);
    } else if(kind == expression_function_call) {
        expression_function_call_free(e[s_expression_data]);
    } else if(kind == expression_index) {
        expression_index_free(e[s_expression_data]);
    } else if(kind == expression_literal) {
        expression_literal_free(e[s_expression_data]);
    } else if(kind == expression_string) {
        expression_string_free(e[s_expression_data]);
    } else if(kind == expression_negation) {
        expression_negation_free(e[s_expression_data]);
    } else if(kind == expression_equal) {
        expression_equal_free(e[s_expression_data]);
    } else if(kind == expression_not_equal) {
        expression_not_equal_free(e[s_expression_data]);
    } else if(kind == expression_less_than) {
        expression_less_than_free(e[s_expression_data]);
    } else if(kind == expression_less_than_or_equal_to) {
        expression_less_than_or_equal_to_free(e[s_expression_data]);
    } else if(kind == expression_greater_than) {
        expression_greater_than_free(e[s_expression_data]);
    } else if(kind == expression_greater_than_or_equal_to) {
        expression_greater_than_or_equal_to_free(e[s_expression_data]);
    } else if(kind == expression_logical_not) {
        expression_logical_not_free(e[s_expression_data]);
    } else if(kind == expression_bitwise_not) {
        expression_bitwise_not_free(e[s_expression_data]);
    } else if(kind == expression_or) {
        expression_or_free(e[s_expression_data]);
    } else if(kind == expression_and) {
        expression_and_free(e[s_expression_data]);
    } else if(kind == expression_xor) {
        expression_xor_free(e[s_expression_data]);
    } else if(kind == expression_add) {
        expression_add_free(e[s_expression_data]);
    } else if(kind == expression_sub) {
        expression_sub_free(e[s_expression_data]);
    } else if(kind == expression_mul) {
        expression_mul_free(e[s_expression_data]);
    } else if(kind == expression_div) {
        expression_div_free(e[s_expression_data]);
    } else if(kind == expression_mod) {
        expression_mod_free(e[s_expression_data]);
    } else if(kind == expression_assignment) {
        expression_assignment_free(e[s_expression_data]);
    };
    free(e);
    return 0;
}


const s_statement_size = 2;
const s_statement_kind = 0;
const s_statement_data = 1;

fn new_statement(kind, data) {
    s = malloc(s_statement_size);
    s[s_statement_kind] = kind;
    s[s_statement_data] = data;

    return s;
}

fn parser_parse_statement(p) {
    prev_pos = p[s_parser_pos];

    if((stm = parser_parse_statement_if(p)) != parser_parse_fail) {
        // no-op
    } else if(parser_reset_pos(p, prev_pos) | (stm = parser_parse_statement_return(p)) != parser_parse_fail) {
        // no-op
    } else if(parser_reset_pos(p, prev_pos) | (stm = parser_parse_statement_break(p)) != parser_parse_fail) {
        // no-op
    } else if(parser_reset_pos(p, prev_pos) | (stm = parser_parse_statement_continue(p)) != parser_parse_fail) {
        // no-op
    } else if(parser_reset_pos(p, prev_pos) | (stm = parser_parse_statement_while(p)) != parser_parse_fail) {
        // no-op
    } else if(parser_reset_pos(p, prev_pos) | (stm = parser_parse_statement_expression(p)) != parser_parse_fail) {
        // no-op
    };

    if(stm == parser_parse_fail) {
        return parser_parse_fail;
    };

    if(parser_next_token(p) != token_semicolon) {
        statement_free(stm);
        return parser_parse_fail;
    };

    return stm;
}

fn parser_parse_statement_block(p) {
    if(parser_next_token(p) != token_open_curly) {
        return parser_parse_fail;
    };

    stms = new_vec();

    while(1) {
        if(parser_peek_token(p) == token_close_curly) {
            parser_next_token(p);
            return stms;
        };

        if((stm = parser_parse_statement(p)) == parser_parse_fail) {
            free_statement_vec(stms);
            return parser_parse_fail;
        };

        vec_push(stms, stm);
    };
}

const statement_expression = 0;
const s_statement_expression_size = 1;
const s_statement_expression_expression = 0;

fn new_statement_expression(expr) {
    s = malloc(s_statement_expression_size);
    s[s_statement_expression_expression] = expr;

    return new_statement(statement_expression, s);
}

fn parser_parse_statement_expression(p) {
    if((expr = parser_parse_expression(p)) == parser_parse_fail) {
        return parser_parse_fail;
    };

    return new_statement_expression(expr);
}

fn statement_expression_free(s) {
    expression_free(s[s_statement_expression_expression]);
    free(s);

    return 0;
}

const statement_if = 1;
const s_statement_if_size = 3;
const s_statement_if_condition = 0;
const s_statement_if_then = 1;
const s_statement_if_otherwise = 2; // empty vec means no else body

fn new_statement_if(condition, then, otherwise) {
    s = malloc(s_statement_if_size);
    s[s_statement_if_condition] = condition;
    s[s_statement_if_then] = then;
    s[s_statement_if_otherwise] = otherwise;

    return new_statement(statement_if, s);
}

fn parser_parse_statement_if(p) {
    if(parser_next_token(p) != token_if) {
        return parser_parse_fail;
    };

    if((condition = parser_parse_braced_expression(p)) == parser_parse_fail) {
        return parser_parse_fail;
    };

    if((then = parser_parse_statement_block(p)) == parser_parse_fail) {
        expression_free(condition);
        return parser_parse_fail;
    };

    if(parser_peek_token(p) != token_else) {
        return new_statement_if(condition, then, new_vec());
    };

    parser_next_token(p);

    prev_pos = p[s_parser_pos];
    if((else_if = parser_parse_statement_if(p)) != parser_parse_fail) {
        otherwise = new_vec();
        vec_push(otherwise, else_if);
        return new_statement_if(condition, then, otherwise);
    } else if(parser_reset_pos(p, prev_pos) | (otherwise = parser_parse_statement_block(p)) != parser_parse_fail) {
        return new_statement_if(condition, then, otherwise);
    };

    expression_free(condition);
    free_statement_vec(then);
    return parser_parse_fail;
}

fn statement_if_free(s) {
    expression_free(s[s_statement_if_condition]);
    free_statement_vec(s[s_statement_if_then]);
    free_statement_vec(s[s_statement_if_otherwise]);
    free(s);

    return 0;
}

const statement_return = 2;
const s_statement_return_size = 1;
const s_statement_return_expression = 0;

fn new_statement_return(expr) {
    s = malloc(s_statement_return_size);
    s[s_statement_return_expression] = expr;

    return new_statement(statement_return, s);
}

fn parser_parse_statement_return(p) {
    if(parser_next_token(p) != token_return) {
        return parser_parse_fail;
    };

    if((expr = parser_parse_expression(p)) == parser_parse_fail) {
        return parser_parse_fail;
    };

    return new_statement_return(expr);
}

fn statement_return_free(s) {
    expression_free(s[s_statement_return_expression]);
    free(s);

    return 0;
}

const statement_break = 3;
const s_statement_break_size = 1;
const s_statement_break_label = 0; // empty vec means no label

fn new_statement_break(label) {
    s = malloc(s_statement_break_size);
    s[s_statement_break_label] = label;

    return new_statement(statement_break, s);
}

fn parser_parse_statement_break(p) {
    if(parser_next_token(p) != token_break) {
        return parser_parse_fail;
    };

    if((label = parser_peek(p)) == eof) {
        return parser_parse_fail;
    };

    if(label[s_lexeme_token] != token_ident) {
        return new_statement_break(new_vec());
    };

    parser_next(p);

    return new_statement_break(vec_clone(label[s_lexeme_data]));
}

fn statement_break_free(s) {
    vec_free(s[s_statement_break_label]);
    free(s);

    return 0;
}

const statement_continue = 4;
const s_statement_continue_size = 1;
const s_statement_continue_label = 0; // empty vec means no label

fn new_statement_continue(label) {
    s = malloc(s_statement_continue_size);
    s[s_statement_continue_label] = label;

    return new_statement(statement_continue, s);
}

fn parser_parse_statement_continue(p) {
    if(parser_next_token(p) != token_continue) {
        return parser_parse_fail;
    };

    if((label = parser_peek(p)) == eof) {
        return parser_parse_fail;
    };

    if(label[s_lexeme_token] != token_ident) {
        return new_statement_continue(new_vec());
    };

    parser_next(p);

    return new_statement_continue(vec_clone(label[s_lexeme_data]));
}

fn statement_continue_free(s) {
    vec_free(s[s_statement_continue_label]);
    free(s);

    return 0;
}

const statement_while = 5;
const s_statement_while_size = 3;
const s_statement_while_label = 0; // empty vec means no label
const s_statement_while_condition = 1;
const s_statement_while_body = 2;

fn new_statement_while(label, condition, body) {
    s = malloc(s_statement_while_size);
    s[s_statement_while_label] = label;
    s[s_statement_while_condition] = condition;
    s[s_statement_while_body] = body;

    return new_statement(statement_while, s);
}

fn parser_parse_statement_while(p) {
    prev_pos = p[s_parser_pos];

    label = new_vec();

    if((l = parser_next_token_and_data(p, token_ident)) != parser_parse_fail) {
        vec_free(label);

        if(parser_next_token(p) != token_colon) {
            return parser_parse_fail;
        };

        label = vec_clone(l);
    } else {
        parser_reset_pos(p, prev_pos);
    };

    if(parser_next_token(p) != token_while) {
        vec_free(label);
        return parser_parse_fail;
    };

    if((condition = parser_parse_braced_expression(p)) == parser_parse_fail) {
        vec_free(label);
        return parser_parse_fail;
    };

    if((body = parser_parse_statement_block(p)) == parser_parse_fail) {
        vec_free(label);
        expression_free(condition);
        return parser_parse_fail;
    };

    return new_statement_while(label, condition, body);
}

fn statement_while_free(s) {
    vec_free(s[s_statement_while_label]);
    expression_free(s[s_statement_while_condition]);
    free_statement_vec(s[s_statement_while_body]);
    free(s);

    return 0;
}

fn statement_free(s) {
    if((kind = s[s_statement_kind]) == statement_expression) {
        statement_expression_free(s[s_statement_data]);
    } else if(kind == statement_if) {
        statement_if_free(s[s_statement_data]);
    } else if(kind == statement_return) {
        statement_return_free(s[s_statement_data]);
    } else if(kind == statement_break) {
        statement_break_free(s[s_statement_data]);
    } else if(kind == statement_continue) {
        statement_continue_free(s[s_statement_data]);
    } else if(kind == statement_while) {
        statement_while_free(s[s_statement_data]);
    };

    free(s);
    return 0;
}

fn free_statement_vec(stms) {
    i = 0;
    while(i < stms[s_vec_count]) {
        statement_free(stms[s_vec_data][i]);
        i = i + 1;
    };
    vec_free(stms);

    return 0;
}

const s_function_size = 3;
const s_function_name_vec = 0;
const s_function_param_names_vec_vec = 1;
const s_function_statements_vec = 2;

fn new_function(name, params, statements) {
    f = malloc(s_function_size);
    f[s_function_name_vec] = name;
    f[s_function_param_names_vec_vec] = params;
    f[s_function_statements_vec] = statements;

    return f;
}

fn function_params_free(params) {
    i = 0;
    while(i < params[s_vec_count]) {
        vec_free(params[s_vec_data][i]);
        i = i + 1;
    };
    vec_free(params);

    return 0;
}

fn parser_parse_function_params(p) {
    if(parser_next_token(p) != token_open_brace) {
        return parser_parse_fail;
    };

    params = new_vec();
    if(parser_peek_token(p) == token_close_brace) {
        parser_next_token(p);
        return params;
    };

    if((param_name = parser_next_token_and_data(p, token_ident)) == parser_parse_fail) {
        vec_free(params);
        return parser_parse_fail;
    };

    vec_push(params, vec_clone(param_name));

    while(1) {
        comma_or_close_brace = parser_next(p);
        if(comma_or_close_brace == eof) {
            return parser_parse_fail;
        } else if(comma_or_close_brace[s_lexeme_token] == token_close_brace) {
            return params;
        } else if(comma_or_close_brace[s_lexeme_token] == token_comma) {
            // no-op
        } else {
            function_params_free(params);
            return parser_parse_fail;
        };

        if((param_name = parser_next_token_and_data(p, token_ident)) == parser_parse_fail) {
            function_params_free(params);
            return parser_parse_fail;
        };

        vec_push(params, vec_clone(param_name));
    };
}

fn parser_parse_function(p) {
    if(parser_next_token(p) != token_fn) {
        return parser_parse_fail;
    };

    if((name = parser_next_token_and_data(p, token_ident)) == parser_parse_fail) {
        return parser_parse_fail;
    };

    if((params = parser_parse_function_params(p)) == parser_parse_fail) {
        return parser_parse_fail;
    };

    if((body = parser_parse_statement_block(p)) == parser_parse_fail) {
        function_params_free(params);
        return parser_parse_fail;
    };

    return new_function(vec_clone(name), params, body);
}

fn function_free(f) {
    vec_free(f[s_function_name_vec]);
    function_params_free(f[s_function_param_names_vec_vec]);
    free_statement_vec(f[s_function_statements_vec]);
    free(f);

    return 0;
}

const s_function_or_constant_size = 2;
const s_function_or_constant_kind = 0;
const s_function_or_constant_data = 1;

const function_or_constant_function = 0;
const function_or_constant_constant = 1;

fn new_function_or_constant(kind, function_or_constant) {
    f_or_c = malloc(s_function_or_constant_size);
    f_or_c[s_function_or_constant_kind] = kind;
    f_or_c[s_function_or_constant_data] = function_or_constant;

    return f_or_c;
}

fn function_or_constant_free(f_or_c) {
    if((kind = f_or_c[s_function_or_constant_kind]) == function_or_constant_constant) {
        constant_free(f_or_c[s_function_or_constant_data]);
    } else {
        function_free(f_or_c[s_function_or_constant_data]);
    };

    free(f_or_c);

    return 0;
}

fn parser_parse_function_or_constant(p) {
    prev_pos = p[s_parser_pos];

    if((function = parser_parse_function(p)) != parser_parse_fail) {
        return new_function_or_constant(function_or_constant_function, function);
    } else if(parser_reset_pos(p, prev_pos) | (constant = parser_parse_constant(p)) != parser_parse_fail) {
        return new_function_or_constant(function_or_constant_constant, constant);
    };

    return parser_parse_fail;
}

fn write_str(s) {
    i = 0;
    while(i < s[0]) {
        write_c(s[i+1]);
        i = i + 1;
    };

    return 0;
}

fn write_str_vec(v) {
    i = 0;
    while(i < v[s_vec_count]) {
        write_c(v[s_vec_data][i]);
        i = i + 1;
    };

    return 0;
}

fn vecs_equal(v1, v2) {
    if(v1[s_vec_count] != v2[s_vec_count]) {
        return 0;
    };

    i = 0;
    while(i < v1[s_vec_count]) {
        if(v1[s_vec_data][i] != v2[s_vec_data][i]) {
            return 0;
        };
        i = i + 1;
    };

    return 1;
}

const s_constant_value_size = 3;
const s_constant_value_name = 0; // non owning
const s_constant_value_kind = 1;
const s_constant_value_data = 2; // non owning

const constant_value_int = 0;

fn new_constant_value_int(name, value) {
    cv = malloc(s_constant_value_size);
    cv[s_constant_value_name] = name;
    cv[s_constant_value_kind] = constant_value_int;
    cv[s_constant_value_data] = value; // int value or string index

    return cv;
}

const constant_value_string = 1;

fn new_constant_value_string(name, string_idx) {
    cv = malloc(s_constant_value_size);
    cv[s_constant_value_name] = name;
    cv[s_constant_value_kind] = constant_value_string;
    cv[s_constant_value_data] = string_idx;

    return cv;
}

fn constants_get_constant_value(constants, name) {
    i = 0;
    while(i < constants[s_vec_count]) {
        c = constants[s_vec_data][i];
        if(vecs_equal(c[s_constant_value_name], name)) {
            return c;
        };
        i = i + 1;
    };

    return 0;
}

fn constant_value_free(cv) {
    free(cv);

    return 0;
}

// index of the vec in vecs if found; -1 otherwise
fn vec_index_vec(vec, vecs) {
    i = 0;
    while(i < vecs[s_vec_count]) {
        if(vecs_equal(vecs[s_vec_data][i], vec)) {
            return i;
        };
        i = i + 1;
    };

    return -1;
}

// returns index of vec in vecs
fn add_unique_vec(vec, vecs) {
    if((idx = vec_index_vec(vec, vecs)) != -1) {
        return idx;
    };

    vec_push(vecs, vec_clone(vec));

    return vecs[s_vec_count] - 1;
}

fn constant_values(functions_and_constants, strings) {
    constants = new_vec();
    i = 0;
    while(i < functions_and_constants[s_vec_count]) {
        if((f_or_c = functions_and_constants[s_vec_data][i])[s_function_or_constant_kind] != function_or_constant_constant) {
            i = i + 1;
            continue;
        };
        constant = f_or_c[s_function_or_constant_data];
        if((kind = constant[s_constant_kind]) == constant_kind_string) {
            vec_push(constants, new_constant_value_string(constant[s_constant_name_vec], vec_index_vec(constant[s_constant_value], strings)));
        } else if(kind == constant_kind_int) {
            vec_push(constants, new_constant_value_int(constant[s_constant_name_vec], constant[s_constant_value]));
        };
        i = i + 1;
    };

    return constants;
}

fn unique_strings_expression(strings, expr) {
    if((kind = expr[s_expression_kind]) == expression_function_call) {
        args = expr[s_expression_data][s_expression_function_call_arg_vec];
        i = 0;
        while(i < args[s_vec_count]) {
            unique_strings_expression(strings, args[s_vec_data][i]);
            i = i + 1;
        };
    } else if(kind == expression_index) {
        unique_strings_expression(strings, expr[s_expression_data][s_expression_index_base]);
        unique_strings_expression(strings, expr[s_expression_data][s_expression_index_index]);
    } else if(kind == expression_string) {
        add_unique_vec(expr[s_expression_data][s_expression_string_string], strings);
    } else if(kind == expression_negation) {
        unique_strings_expression(strings, expr[s_expression_data][s_expression_negation_expr]);
    } else if(kind == expression_equal) {
        unique_strings_expression(strings, expr[s_expression_data][s_expression_equal_first]);
        unique_strings_expression(strings, expr[s_expression_data][s_expression_equal_second]);
    } else if(kind == expression_not_equal) {
        unique_strings_expression(strings, expr[s_expression_data][s_expression_not_equal_first]);
        unique_strings_expression(strings, expr[s_expression_data][s_expression_not_equal_second]);
    } else if(kind == expression_less_than) {
        unique_strings_expression(strings, expr[s_expression_data][s_expression_less_than_first]);
        unique_strings_expression(strings, expr[s_expression_data][s_expression_less_than_second]);
    } else if(kind == expression_less_than_or_equal_to) {
        unique_strings_expression(strings, expr[s_expression_data][s_expression_less_than_or_equal_to_first]);
        unique_strings_expression(strings, expr[s_expression_data][s_expression_less_than_or_equal_to_second]);
    } else if(kind == expression_greater_than) {
        unique_strings_expression(strings, expr[s_expression_data][s_expression_greater_than_first]);
        unique_strings_expression(strings, expr[s_expression_data][s_expression_greater_than_second]);
    } else if(kind == expression_greater_than_or_equal_to) {
        unique_strings_expression(strings, expr[s_expression_data][s_expression_greater_than_or_equal_to_first]);
        unique_strings_expression(strings, expr[s_expression_data][s_expression_greater_than_or_equal_to_second]);
    } else if(kind == expression_logical_not) {
        unique_strings_expression(strings, expr[s_expression_data][s_expression_logical_not_expr]);
    } else if(kind == expression_bitwise_not) {
        unique_strings_expression(strings, expr[s_expression_data][s_expression_bitwise_not_expr]);
    } else if(kind == expression_or) {
        unique_strings_expression(strings, expr[s_expression_data][s_expression_or_first]);
        unique_strings_expression(strings, expr[s_expression_data][s_expression_or_second]);
    } else if(kind == expression_and) {
        unique_strings_expression(strings, expr[s_expression_data][s_expression_and_first]);
        unique_strings_expression(strings, expr[s_expression_data][s_expression_and_second]);
    } else if(kind == expression_xor) {
        unique_strings_expression(strings, expr[s_expression_data][s_expression_xor_first]);
        unique_strings_expression(strings, expr[s_expression_data][s_expression_xor_second]);
    } else if(kind == expression_add) {
        unique_strings_expression(strings, expr[s_expression_data][s_expression_add_first]);
        unique_strings_expression(strings, expr[s_expression_data][s_expression_add_second]);
    } else if(kind == expression_sub) {
        unique_strings_expression(strings, expr[s_expression_data][s_expression_sub_first]);
        unique_strings_expression(strings, expr[s_expression_data][s_expression_sub_second]);
    } else if(kind == expression_mul) {
        unique_strings_expression(strings, expr[s_expression_data][s_expression_mul_first]);
        unique_strings_expression(strings, expr[s_expression_data][s_expression_mul_second]);
    } else if(kind == expression_div) {
        unique_strings_expression(strings, expr[s_expression_data][s_expression_div_first]);
        unique_strings_expression(strings, expr[s_expression_data][s_expression_div_second]);
    } else if(kind == expression_mod) {
        unique_strings_expression(strings, expr[s_expression_data][s_expression_mod_first]);
        unique_strings_expression(strings, expr[s_expression_data][s_expression_mod_second]);
    } else if(kind == expression_assignment) {
        unique_strings_expression(strings, expr[s_expression_data][s_expression_assignment_target]);
        unique_strings_expression(strings, expr[s_expression_data][s_expression_assignment_expr]);
    };

    return 0;
}

fn unique_strings_statements(strings, stms) {
    i = 0;
    while(i < stms[s_vec_count]) {
        stm = stms[s_vec_data][i];
        if((kind = stm[s_statement_kind]) == statement_expression) {
            unique_strings_expression(strings, stm[s_statement_data][s_statement_expression_expression]);
        } else if(kind == statement_if) {
            unique_strings_expression(strings, stm[s_statement_data][s_statement_if_condition]);
            unique_strings_statements(strings, stm[s_statement_data][s_statement_if_then]);
            unique_strings_statements(strings, stm[s_statement_data][s_statement_if_otherwise]);
        } else if(kind == statement_return) {
            unique_strings_expression(strings, stm[s_statement_data][s_statement_return_expression]);
        } else if(kind == statement_while) {
            unique_strings_expression(strings, stm[s_statement_data][s_statement_while_condition]);
            unique_strings_statements(strings, stm[s_statement_data][s_statement_while_body]);
        };
        i = i + 1;
    };

    return 0;
}

fn unique_strings(functions_and_constants) {
    strings = new_vec();
    i = 0;
    while(i < functions_and_constants[s_vec_count]) {
        if((kind = (f_or_c = functions_and_constants[s_vec_data][i])[s_function_or_constant_kind]) == function_or_constant_constant) {
            constant = f_or_c[s_function_or_constant_data];
            if(constant[s_constant_kind] == constant_kind_string) {
                add_unique_vec(constant[s_constant_value], strings);
            };
        } else if(functions_and_constants[s_vec_data][i][s_function_or_constant_kind] == function_or_constant_function) {
            function = f_or_c[s_function_or_constant_data];
            unique_strings_statements(strings, function[s_function_statements_vec]);
        };
        i = i + 1;
    };

    return strings;
}

const s_prepass_result_size = 4;
const s_prepass_result_unique_strings = 0; // non owning
const s_prepass_result_vars = 1; // inner strings non owning
const s_prepass_result_constant_values = 2; // non owning
const s_prepass_result_max_intermediate_count = 3;

fn new_prepass_result(parameters, strings, constant_values) {
    pr = malloc(s_prepass_result_size);
    pr[s_prepass_result_unique_strings] = strings;
    pr[s_prepass_result_vars] = new_vec();
    pr[s_prepass_result_constant_values] = constant_values;
    pr[s_prepass_result_max_intermediate_count] = 0;

    i = 0;
    while(i < parameters[s_vec_count]) {
        vec_push(pr[s_prepass_result_vars], parameters[s_vec_data][i]);
        i = i + 1;
    };

    return pr;
}

fn prepass_result_update_intermediates(pr, intermediate_count) {
    if(intermediate_count > pr[s_prepass_result_max_intermediate_count]) {
        pr[s_prepass_result_max_intermediate_count] = intermediate_count;
    };

    return 0;
}

fn prepass_expression(pr, expr, current_intermediate_count) {
    prepass_result_update_intermediates(pr, current_intermediate_count);
    if((expr_kind = expr[s_expression_kind]) == expression_ident) {
        ident = expr[s_expression_data][s_expression_ident_ident];
        if(constants_get_constant_value(pr[s_prepass_result_constant_values], ident)) {
            return 0;
        };
        add_unique_vec(ident, pr[s_prepass_result_vars]);
    } else if(expr_kind == expression_function_call) {
        args = expr[s_expression_data][s_expression_function_call_arg_vec];
        i = 0;
        while(i < args[s_vec_count]) {
            prepass_expression(pr, args[s_vec_data][i], current_intermediate_count + args[s_vec_count]);
            i = i + 1;
        };
    } else if(expr_kind == expression_index) {
        prepass_expression(pr, expr[s_expression_data][s_expression_index_base], current_intermediate_count);
        prepass_expression(pr, expr[s_expression_data][s_expression_index_index], current_intermediate_count + 1);
    } else if(expr_kind == expression_string) {
        add_unique_vec(expr[s_expression_data][s_expression_string_string], pr[s_prepass_result_unique_strings]);
    } else if(expr_kind == expression_negation) {
        prepass_expression(pr, expr[s_expression_data][s_expression_negation_expr], current_intermediate_count);
    } else if(expr_kind == expression_equal) {
        prepass_expression(pr, expr[s_expression_data][s_expression_equal_first], current_intermediate_count);
        prepass_expression(pr, expr[s_expression_data][s_expression_equal_second], current_intermediate_count + 1);
    } else if(expr_kind == expression_not_equal) {
        prepass_expression(pr, expr[s_expression_data][s_expression_not_equal_first], current_intermediate_count);
        prepass_expression(pr, expr[s_expression_data][s_expression_not_equal_second], current_intermediate_count + 1);
    } else if(expr_kind == expression_less_than) {
        prepass_expression(pr, expr[s_expression_data][s_expression_less_than_first], current_intermediate_count);
        prepass_expression(pr, expr[s_expression_data][s_expression_less_than_second], current_intermediate_count + 1);
    } else if(expr_kind == expression_less_than_or_equal_to) {
        prepass_expression(pr, expr[s_expression_data][s_expression_less_than_or_equal_to_first], current_intermediate_count);
        prepass_expression(pr, expr[s_expression_data][s_expression_less_than_or_equal_to_second], current_intermediate_count + 1);
    } else if(expr_kind == expression_greater_than) {
        prepass_expression(pr, expr[s_expression_data][s_expression_greater_than_first], current_intermediate_count);
        prepass_expression(pr, expr[s_expression_data][s_expression_greater_than_second], current_intermediate_count + 1);
    } else if(expr_kind == expression_greater_than_or_equal_to) {
        prepass_expression(pr, expr[s_expression_data][s_expression_greater_than_or_equal_to_first], current_intermediate_count);
        prepass_expression(pr, expr[s_expression_data][s_expression_greater_than_or_equal_to_second], current_intermediate_count + 1);
    } else if(expr_kind == expression_logical_not) {
        prepass_expression(pr, expr[s_expression_data][s_expression_logical_not_expr], current_intermediate_count);
    } else if(expr_kind == expression_bitwise_not) {
        prepass_expression(pr, expr[s_expression_data][s_expression_bitwise_not_expr], current_intermediate_count);
    } else if(expr_kind == expression_or) {
        prepass_expression(pr, expr[s_expression_data][s_expression_or_first], current_intermediate_count);
        prepass_expression(pr, expr[s_expression_data][s_expression_or_second], current_intermediate_count + 1);
    } else if(expr_kind == expression_and) {
        prepass_expression(pr, expr[s_expression_data][s_expression_and_first], current_intermediate_count);
        prepass_expression(pr, expr[s_expression_data][s_expression_and_second], current_intermediate_count + 1);
    } else if(expr_kind == expression_xor) {
        prepass_expression(pr, expr[s_expression_data][s_expression_xor_first], current_intermediate_count);
        prepass_expression(pr, expr[s_expression_data][s_expression_xor_second], current_intermediate_count + 1);
    } else if(expr_kind == expression_add) {
        prepass_expression(pr, expr[s_expression_data][s_expression_add_first], current_intermediate_count);
        prepass_expression(pr, expr[s_expression_data][s_expression_add_second], current_intermediate_count + 1);
    } else if(expr_kind == expression_sub) {
        prepass_expression(pr, expr[s_expression_data][s_expression_sub_first], current_intermediate_count);
        prepass_expression(pr, expr[s_expression_data][s_expression_sub_second], current_intermediate_count + 1);
    } else if(expr_kind == expression_mul) {
        prepass_expression(pr, expr[s_expression_data][s_expression_mul_first], current_intermediate_count);
        prepass_expression(pr, expr[s_expression_data][s_expression_mul_second], current_intermediate_count + 1);
    } else if(expr_kind == expression_div) {
        prepass_expression(pr, expr[s_expression_data][s_expression_div_first], current_intermediate_count);
        prepass_expression(pr, expr[s_expression_data][s_expression_div_second], current_intermediate_count + 1);
    } else if(expr_kind == expression_mod) {
        prepass_expression(pr, expr[s_expression_data][s_expression_mod_first], current_intermediate_count);
        prepass_expression(pr, expr[s_expression_data][s_expression_mod_second], current_intermediate_count + 1);
    } else if(expr_kind == expression_assignment) {
        prepass_expression(pr, expr[s_expression_data][s_expression_assignment_target], current_intermediate_count);
        prepass_expression(pr, expr[s_expression_data][s_expression_assignment_expr], current_intermediate_count + 1);
    };

    return 0;
}

fn prepass_statements(pr, stms, current_intermediate_count) {
    i = 0;
    while(i < stms[s_vec_count]) {
        stm = stms[s_vec_data][i];
        if((stm_kind = stm[s_statement_kind]) == statement_expression) {
            prepass_expression(pr, stm[s_statement_data][s_statement_expression_expression], current_intermediate_count);
        } else if(stm_kind == statement_if) {
            prepass_expression(pr, stm[s_statement_data][s_statement_if_condition], current_intermediate_count);
            prepass_statements(pr, stm[s_statement_data][s_statement_if_then], current_intermediate_count);
            prepass_statements(pr, stm[s_statement_data][s_statement_if_otherwise], current_intermediate_count);
        } else if(stm_kind == statement_return) {
            prepass_expression(pr, stm[s_statement_data][s_statement_return_expression], current_intermediate_count);
        } else if(stm_kind == statement_while) {
            prepass_expression(pr, stm[s_statement_data][s_statement_while_condition], current_intermediate_count);
            prepass_statements(pr, stm[s_statement_data][s_statement_while_body], current_intermediate_count);
        };
        i = i + 1;
    };

    return 0;
}

fn prepass_result_free(pr) {
    vec_free(pr[s_prepass_result_vars]);
    free(pr);

    return 0;
}

const codegen_fail = -1;

const s_codegen_size = 3;
const s_codegen_strings = 0;
const s_codegen_constants = 1;
const s_codegen_label_counter = 2;

fn new_codegen(strings, constants) {
    cg = malloc(s_codegen_size);
    cg[s_codegen_strings] = strings;
    cg[s_codegen_constants] = constants;
    cg[s_codegen_label_counter] = 0;

    return cg;
}

fn codegen_next_label(cg) {
    l = cg[s_codegen_label_counter];
    cg[s_codegen_label_counter] = cg[s_codegen_label_counter] + 1;

    return l;
}

fn codegen_free(cg) {
    constants = cg[s_codegen_constants];
    i = 0;
    while(i < constants[s_vec_count]) {
        constant_value_free(constants[s_vec_data][i]);
        i = i + 1;
    };
    vec_free(constants);

    strings = cg[s_codegen_strings];
    i = 0;
    while(i < strings[s_vec_count]) {
        vec_free(strings[s_vec_data][i]);
        i = i + 1;
    };
    vec_free(strings);

    free(cg);

    return 0;
}

const s_variable_name_stack_slot_pair_size = 2;
const s_variable_name_stack_slot_pair_name = 0; // non owning
const s_variable_name_stack_slot_pair_stack_slot = 1;

fn new_variable_name_stack_slot_pair(name, stack_slot) {
    pair = malloc(s_variable_name_stack_slot_pair_size);
    pair[s_variable_name_stack_slot_pair_name] = name;
    pair[s_variable_name_stack_slot_pair_stack_slot] = stack_slot;

    return pair;
}

fn variable_name_stack_slot_pair_free(pair) {
    free(pair);

    return 0;
}

const s_loop_entry_size = 3;
const s_loop_entry_start = 0; // just the integer (i.e just 0 for L0)
const s_loop_entry_end = 1; // see above
const s_loop_entry_label = 2; // non owning, empty vec means no label

fn new_loop_entry(start, end, label) {
    le = malloc(s_loop_entry_size);
    le[s_loop_entry_start] = start;
    le[s_loop_entry_end] = end;
    le[s_loop_entry_label] = label;

    return le;
}

fn loop_entry_free(le) {
    free(le);

    return 0;
}

const s_codegen_function_size = 4;
const s_codegen_function_parent = 0; // non owning
const s_codegen_function_vars = 1;
const s_codegen_function_stack_counter = 2; // get's incremented both for new variables as well as for required intermediates
const s_codegen_function_loop_entries = 3;

fn new_codegen_function(parent) {
    cgf = malloc(s_codegen_function_size);
    cgf[s_codegen_function_parent] = parent;
    cgf[s_codegen_function_vars] = new_vec();
    cgf[s_codegen_function_stack_counter] = 0;
    cgf[s_codegen_function_loop_entries] = new_vec();

    return cgf;
}

fn codegen_function_add_var(cgf, var) {
    slot = cgf[s_codegen_function_stack_counter];
    vec_push(cgf[s_codegen_function_vars], new_variable_name_stack_slot_pair(var, slot));
    cgf[s_codegen_function_stack_counter] = cgf[s_codegen_function_stack_counter] + 1;

    return slot;
}

fn codegen_function_generate_intermediate_save(cgf) {
    cgf[s_codegen_function_stack_counter] = cgf[s_codegen_function_stack_counter] + 1;

    write_str("    mov [rbp-");
    write_str(i_to_s(cgf[s_codegen_function_stack_counter] * 8));
    write_str("], rax
"
    );

    return 0;
}

fn codegen_function_generate_intermediate_restore(cgf, target_register) {
    write_str("    mov ");
    write_str(target_register);
    write_str(", [rbp-");
    write_str(i_to_s(cgf[s_codegen_function_stack_counter] * 8));
    write_str("]
"
    );

    cgf[s_codegen_function_stack_counter] = cgf[s_codegen_function_stack_counter] - 1;

    return 0;
}

fn codegen_function_get_var(cgf, var) {
    vars = cgf[s_codegen_function_vars];
    i = 0;
    while(i < vars[s_vec_count]) {
        v = vars[s_vec_data][i];
        if(vecs_equal(v[s_variable_name_stack_slot_pair_name], var)) {
            return v[s_variable_name_stack_slot_pair_stack_slot];
        };
        i = i + 1;
    };

    // we should never get here since the pre pass get's all used variables
    return 0;
}

fn codegen_function_generate_binary_expression(cgf, first, second, instr) {
    if(codegen_function_generate_expression(cgf, first) == codegen_fail) {
        return codegen_fail;
    };
    codegen_function_generate_intermediate_save(cgf);
    if(codegen_function_generate_expression(cgf, second) == codegen_fail) {
        return codegen_fail;
    };
    codegen_function_generate_intermediate_restore(cgf, "rdx");
    write_str(instr);

    return 0;
}

// returns the ith parameter register; in order: rdi, rsi, rdx, rcx, r8, r9
fn parameter_register(i) {
    if(i == 0) {
        return "rdi";
    } else if(i == 1) {
        return "rsi";
    } else if(i == 2) {
        return "rdx";
    } else if(i == 3) {
        return "rcx";
    } else if(i == 4) {
        return "r8";
    } else if(i == 5) {
        return "r9";
    };
}

fn codegen_function_generate_expression(cgf, expr) {
    if((kind = expr[s_expression_kind]) == expression_add) {
        expr_add = expr[s_expression_data];
        if(codegen_function_generate_binary_expression(cgf, expr_add[s_expression_add_first], expr_add[s_expression_add_second],
"    add rax, rdx
"
        ) == codegen_fail) {
            return codegen_fail;
        };
    } else if(kind == expression_and) {
        expr_and = expr[s_expression_data];
        if(codegen_function_generate_binary_expression(cgf, expr_and[s_expression_and_first], expr_and[s_expression_and_second],
"    and rax, rdx
"
        ) == codegen_fail) {
            return codegen_fail;
        };
    } else if(kind == expression_bitwise_not) {
        expr_bitwise_not = expr[s_expression_data];
        if(codegen_function_generate_expression(cgf, expr_bitwise_not[s_expression_bitwise_not_expr]) == codegen_fail) {
            return codegen_fail;
        };
        write_str("    not rax
"
        );
    } else if(kind == expression_div) {
        expr_div = expr[s_expression_data];
        if(codegen_function_generate_expression(cgf, expr_div[s_expression_div_first]) == codegen_fail) {
            return codegen_fail;
        };
        codegen_function_generate_intermediate_save(cgf);
        if(codegen_function_generate_expression(cgf, expr_div[s_expression_div_second]) == codegen_fail) {
            return codegen_fail;
        };
        codegen_function_generate_intermediate_restore(cgf, "rsi");
        write_str(
"    xchg rax, rsi
    cqo
    idiv rsi
"
        );
    } else if(kind == expression_equal) {
        expr_equal = expr[s_expression_data];
        if(codegen_function_generate_binary_expression(cgf, expr_equal[s_expression_equal_first], expr_equal[s_expression_equal_second],
"    mov rsi, rax
    xor eax, eax
    cmp rsi, rdx
    sete al
"
        ) == codegen_fail) {
            return codegen_fail;
        };
    } else if(kind == expression_function_call) {
        expr_function_call = expr[s_expression_data];
        args = expr_function_call[s_expression_function_call_arg_vec];

        if(args[s_vec_count] > 6) {
            write_str("Can't handle function calls with more than 6 arguments\n");
            return codegen_fail;
        };

        i = 0;
        while(i < args[s_vec_count]) {
            if(codegen_function_generate_expression(cgf, args[s_vec_data][i]) == codegen_fail) {
                return codegen_fail;
            };
            codegen_function_generate_intermediate_save(cgf);
            i = i + 1;
        };

        i = 0;
        while(i < args[s_vec_count]) {
            codegen_function_generate_intermediate_restore(cgf, parameter_register(args[s_vec_count] - i - 1));
            i = i + 1;
        };

        write_str("    call intlang_");
        write_str_vec(expr_function_call[s_expression_function_call_function_name]);
        write_c('\n');
    } else if(kind == expression_index) {
        expr_index = expr[s_expression_data];
        if(codegen_function_generate_binary_expression(cgf, expr_index[s_expression_index_base], expr_index[s_expression_index_index],
"    mov rax, [rdx + rax * 8]
"
        ) == codegen_fail) {
            return codegen_fail;
        };
    } else if(kind == expression_ident) {
        expr_ident = expr[s_expression_data];
        if((c = constants_get_constant_value(cgf[s_codegen_function_parent][s_codegen_constants], expr_ident[s_expression_ident_ident]))) {
            if((kind = c[s_constant_value_kind]) == constant_value_int) {
                write_str("    mov rax, ");
                write_str(i_to_s(c[s_constant_value_data]));
                write_c('\n');
            } else if(kind == constant_value_string) {
                write_str("    mov rax, intlangstring_");
                write_str(i_to_s(c[s_constant_value_data]));
                write_c('\n');
            };
            return 0;
        };

        slot = codegen_function_get_var(cgf, expr_ident[s_expression_ident_ident]);
        write_str("    mov rax, [rbp-");
        write_str(i_to_s((slot+1) * 8));
        write_str("]
"
        );
    } else if(kind == expression_literal) {
        expr_literal = expr[s_expression_data];
        write_str("    mov rax, ");
        write_str(i_to_s(expr_literal[s_expression_literal_value]));
        write_c('\n');
    } else if(kind == expression_string) {
        expr_string = expr[s_expression_data];
        string = vec_index_vec(expr_string[s_expression_string_string], cgf[s_codegen_function_parent][s_codegen_strings]);
        write_str("    mov rax, intlangstring_");
        write_str(i_to_s(string));
        write_c('\n');
    } else if(kind == expression_negation) {
        expr_negation = expr[s_expression_data];
        if(codegen_function_generate_expression(cgf, expr_negation[s_expression_negation_expr]) == codegen_fail) {
            return codegen_fail;
        };
        write_str("    neg rax
"
        );
    } else if(kind == expression_not_equal) {
        expr_not_equal = expr[s_expression_data];
        if(codegen_function_generate_binary_expression(cgf, expr_not_equal[s_expression_not_equal_first], expr_not_equal[s_expression_not_equal_second],
"    mov rsi, rax
    xor eax, eax
    cmp rsi, rdx
    setne al
"
        ) == codegen_fail) {
            return codegen_fail;
        };
    } else if(kind == expression_less_than) {
        expr_less_than = expr[s_expression_data];
        if(codegen_function_generate_binary_expression(cgf, expr_less_than[s_expression_less_than_first], expr_less_than[s_expression_less_than_second],
"    mov rsi, rax
    xor eax, eax
    cmp rsi, rdx
    setg al
"
        ) == codegen_fail) {
            return codegen_fail;
        };
    } else if(kind == expression_less_than_or_equal_to) {
        expr_less_than_or_equal_to = expr[s_expression_data];
        if(codegen_function_generate_binary_expression(cgf, expr_less_than_or_equal_to[s_expression_less_than_or_equal_to_first], expr_less_than_or_equal_to[s_expression_less_than_or_equal_to_second],
"    mov rsi, rax
    xor eax, eax
    cmp rsi, rdx
    setge al
"
        ) == codegen_fail) {
            return codegen_fail;
        };
    } else if(kind == expression_greater_than) {
        expr_greater_than = expr[s_expression_data];
        if(codegen_function_generate_binary_expression(cgf, expr_greater_than[s_expression_greater_than_first], expr_greater_than[s_expression_greater_than_second],
"    mov rsi, rax
    xor eax, eax
    cmp rsi, rdx
    setl al
"
        ) == codegen_fail) {
            return codegen_fail;
        };
    } else if(kind == expression_greater_than_or_equal_to) {
        expr_greater_than_or_equal_to = expr[s_expression_data];
        if(codegen_function_generate_binary_expression(cgf, expr_greater_than_or_equal_to[s_expression_greater_than_or_equal_to_first], expr_greater_than_or_equal_to[s_expression_greater_than_or_equal_to_second],
"    mov rsi, rax
    xor eax, eax
    cmp rsi, rdx
    setle al
"
        ) == codegen_fail) {
            return codegen_fail;
        };
    } else if(kind == expression_logical_not) {
        expr_logical_not = expr[s_expression_data];
        if(codegen_function_generate_expression(cgf, expr_logical_not[s_expression_logical_not_expr]) == codegen_fail) {
            return codegen_fail;
        };

        write_str(
"    mov rsi, rax
    xor eax, eax
    test rsi, rsi
    sete al
"
        );
    } else if(kind == expression_or) {
        expr_or = expr[s_expression_data];
        if(codegen_function_generate_binary_expression(cgf, expr_or[s_expression_or_first], expr_or[s_expression_or_second],
"    or rax, rdx
"
        ) == codegen_fail) {
            return codegen_fail;
        };
    } else if(kind == expression_xor) {
        expr_xor = expr[s_expression_data];
        if(codegen_function_generate_binary_expression(cgf, expr_xor[s_expression_xor_first], expr_xor[s_expression_xor_second],
"    xor rax, rdx
"
        ) == codegen_fail) {
            return codegen_fail;
        };
    } else if(kind == expression_sub) {
        expr_sub = expr[s_expression_data];
        if(codegen_function_generate_binary_expression(cgf, expr_sub[s_expression_sub_first], expr_sub[s_expression_sub_second],
"    xchg rax, rdx
    sub rax, rdx
"
        ) == codegen_fail) {
            return codegen_fail;
        };
    } else if(kind == expression_mul) {
        expr_mul = expr[s_expression_data];
        if(codegen_function_generate_binary_expression(cgf, expr_mul[s_expression_mul_first], expr_mul[s_expression_mul_second],
"    imul rdx
"
        ) == codegen_fail) {
            return codegen_fail;
        };
    } else if(kind == expression_mod) {
        expr_mod = expr[s_expression_data];
        if(codegen_function_generate_expression(cgf, expr_mod[s_expression_mod_first]) == codegen_fail) {
            return codegen_fail;
        };
        codegen_function_generate_intermediate_save(cgf);
        if(codegen_function_generate_expression(cgf, expr_mod[s_expression_mod_second]) == codegen_fail) {
            return codegen_fail;
        };
        codegen_function_generate_intermediate_restore(cgf, "rsi");
        write_str(
"    xchg rax, rsi
    cqo
    idiv rsi
    mov rax, rdx
"
        );
    } else if(kind == expression_assignment) {
        expr_assignment = expr[s_expression_data];
        target = expr_assignment[s_expression_assignment_target];

        if((target_kind = target[s_expression_kind]) == expression_ident) {
            if(codegen_function_generate_expression(cgf, expr_assignment[s_expression_assignment_expr]) == codegen_fail) {
                return codegen_fail;
            };
            slot = codegen_function_get_var(cgf, target[s_expression_data][s_expression_ident_ident]);
            write_str("    mov [rbp-");
            write_str(i_to_s((slot+1) * 8));
            write_str("], rax
"
            );
        } else if(target_kind == expression_index) {
            index_target = target[s_expression_data];
            if(codegen_function_generate_expression(cgf, index_target[s_expression_index_base]) == codegen_fail) {
                return codegen_fail;
            };
            codegen_function_generate_intermediate_save(cgf);
            if(codegen_function_generate_expression(cgf, index_target[s_expression_index_index]) == codegen_fail) {
                return codegen_fail;
            };
            codegen_function_generate_intermediate_save(cgf);
            if(codegen_function_generate_expression(cgf, expr_assignment[s_expression_assignment_expr]) == codegen_fail) {
                return codegen_fail;
            };
            codegen_function_generate_intermediate_restore(cgf, "rsi");
            codegen_function_generate_intermediate_restore(cgf, "rdx");
            write_str("    mov [rdx + rsi * 8], rax
"
            );
        } else {
            write_str("Invalid assignment target; only index or variable are valid\n");
            return codegen_fail;
        };
    };

    return 0;
}

fn write_label(l) {
    write_str("L");
    write_str(i_to_s(l));
    write_str(":\n");

    return 0;
}

fn codegen_function_generate_statements(cgf, stms) {
    i = 0;
    while(i < stms[s_vec_count]) {
        stm = stms[s_vec_data][i];
        if((kind = stm[s_statement_kind]) == statement_expression) {
            if(codegen_function_generate_expression(cgf, stm[s_statement_data][s_statement_expression_expression]) == codegen_fail) {
                return codegen_fail;
            };
        } else if(kind == statement_if) {
            if_stm = stm[s_statement_data];
            if(codegen_function_generate_expression(cgf, if_stm[s_statement_if_condition]) == codegen_fail) {
                return codegen_fail;
            };
            else_label = codegen_next_label(cgf[s_codegen_function_parent]);
            end_label = codegen_next_label(cgf[s_codegen_function_parent]);
            write_str(
"    test rax, rax
    jz L"
            );
            write_str(i_to_s(else_label));
            write_c('\n');
            if(codegen_function_generate_statements(cgf, if_stm[s_statement_if_then]) == codegen_fail) {
                return codegen_fail;
            };
            write_str(
"    jmp L"
            );
            write_str(i_to_s(end_label));
            write_c('\n');
            write_label(else_label);
            if(codegen_function_generate_statements(cgf, if_stm[s_statement_if_otherwise]) == codegen_fail) {
                return codegen_fail;
            };
            write_label(end_label);
        } else if(kind == statement_while) {
            while_stm = stm[s_statement_data];
            start_label = codegen_next_label(cgf[s_codegen_function_parent]);
            end_label = codegen_next_label(cgf[s_codegen_function_parent]);
            loop_entry = new_loop_entry(start_label, end_label, while_stm[s_statement_while_label]);
            vec_push(cgf[s_codegen_function_loop_entries], loop_entry);

            write_label(start_label);
            if(codegen_function_generate_expression(cgf, while_stm[s_statement_while_condition]) == codegen_fail) {
                return codegen_fail;
            };
            write_str("    test rax, rax
    jz L"
            );
            write_str(i_to_s(end_label));
            write_c('\n');
            if(codegen_function_generate_statements(cgf, while_stm[s_statement_while_body]) == codegen_fail) {
                return codegen_fail;
            };

            write_str("    jmp L");
            write_str(i_to_s(start_label));
            write_c('\n');
            write_label(end_label);

            loop_entry_free(loop_entry);
            cgf[s_codegen_function_loop_entries][s_vec_count] = cgf[s_codegen_function_loop_entries][s_vec_count] - 1;
        } else if(kind == statement_return) {
            return_stm = stm[s_statement_data];
            if(codegen_function_generate_expression(cgf, return_stm[s_statement_return_expression]) == codegen_fail) {
                return codegen_fail;
            };
            write_str(
"    leave
    ret
"
            );
        } else if(kind == statement_break) {
            break_stm = stm[s_statement_data];
            target_label = break_stm[s_statement_break_label];
            loop_entry = 0;
            j = cgf[s_codegen_function_loop_entries][s_vec_count] - 1;
            while(j >= 0) {
                le = cgf[s_codegen_function_loop_entries][s_vec_data][j];
                if(target_label[s_vec_count] == 0 | vecs_equal(target_label, le[s_loop_entry_label])) {
                    loop_entry = le;
                    break;
                };
                j = j - 1;
            };

            if(loop_entry == 0) {
                write_str("No such loop found\n");
                return codegen_fail;
            };

            write_str("    jmp L");
            write_str(i_to_s(loop_entry[s_loop_entry_end]));
            write_c('\n');
        } else if(kind == statement_continue) {
            continue_stm = stm[s_statement_data];
            target_label = continue_stm[s_statement_continue_label];
            loop_entry = 0;
            j = cgf[s_codegen_function_loop_entries][s_vec_count] - 1;
            while(j >= 0) {
                le = cgf[s_codegen_function_loop_entries][s_vec_data][j];
                if(target_label[s_vec_count] == 0 | vecs_equal(target_label, le[s_loop_entry_label])) {
                    loop_entry = le;
                    break;
                };
                j = j - 1;
            };

            if(loop_entry == 0) {
                write_str("No such loop found\n");
                return codegen_fail;
            };

            write_str("    jmp L");
            write_str(i_to_s(loop_entry[s_loop_entry_start]));
            write_c('\n');
        };
        i = i + 1;
    };

    return 0;
}

fn codegen_function_free(cgf) {
    vars = cgf[s_codegen_function_vars];
    i = 0;
    while(i < vars[s_vec_count]) {
        variable_name_stack_slot_pair_free(vars[s_vec_data][i]);
        i = i + 1;
    };
    vec_free(vars);

    loop_entries = cgf[s_codegen_function_loop_entries];
    i = 0;
    while(i < loop_entries[s_vec_count]) {
        loop_entry_free(loop_entries[s_vec_data][i]);
        i = i + 1;
    };
    vec_free(loop_entries);

    free(cgf);

    return 0;
}

fn next_multiple_of(x, factor) {
    return (x + (factor - 1)) / factor * factor;
}

fn generate_function(cg, f) {
    params = f[s_function_param_names_vec_vec];
    if(params[s_vec_count] > 6) {
        write_str("Can't handle functions with more than 6 parameters\n");
        return codegen_fail;
    };

    pr = new_prepass_result(params, cg[s_codegen_strings], cg[s_codegen_constants]);
    prepass_statements(pr, f[s_function_statements_vec], 0);

    cgf = new_codegen_function(cg);

    write_str("intlang_");
    write_str_vec(f[s_function_name_vec]);
    write_str(":
    push rbp
    mov rbp, rsp
    sub rsp, ");

    write_str(i_to_s(next_multiple_of((pr[s_prepass_result_vars][s_vec_count] + pr[s_prepass_result_max_intermediate_count]) * 8, 16)));

    i = 0;
    while(i < pr[s_prepass_result_vars][s_vec_count]) {
        codegen_function_add_var(cgf, pr[s_prepass_result_vars][s_vec_data][i]);
        i = i + 1;
    };

    cgf[s_codegen_function_stack_counter] = pr[s_prepass_result_vars][s_vec_count];

    write_c('\n');

    i = 0;
    while(i < params[s_vec_count]) {
        slot = codegen_function_get_var(cgf, params[s_vec_data][i]);
        write_str("    mov [rbp-");
        write_str(i_to_s((slot+1) * 8));
        write_str("], ");
        write_str(parameter_register(i));
        write_c('\n');
        i = i + 1;
    };

    prepass_result_free(pr);

    if(codegen_function_generate_statements(cgf, f[s_function_statements_vec]) == codegen_fail) {
        codegen_function_free(cgf);
        return codegen_fail;
    };

    codegen_function_free(cgf);
    return 0;
}

fn generate_binary(functions_and_constants) {
    write_str(
"default rel
section .data
    input_format db \"%ld\", 0
    output_format db \"%ld\", 10, 0
"
    );

    strings = unique_strings(functions_and_constants);
    constants = constant_values(functions_and_constants, strings);
    i = 0;
    while(i < strings[s_vec_count]) {
        write_str("
    intlangstring_"
        );
        write_str(i_to_s(i));
        write_str(" dq ");
        s = strings[s_vec_data][i];
        write_str(i_to_s(s[s_vec_count]));
        j = 0;
        while(j < s[s_vec_count]) {
            write_str(", ");
            write_str(i_to_s(s[s_vec_data][j]));
            j = j + 1;
        };
        i = i + 1;
    };
    write_str(
"
section .bss
    number resq 1
    utf8 resb 4
    decimal_number resq 21
section .text
    global main
    extern scanf
    extern printf
    extern malloc
    extern realloc
    extern free

intlang_read:
    push rbp
    mov rbp, rsp
    mov rdi, input_format
    mov rsi, number
    xor eax, eax
    call scanf
    mov rax, [number]
    leave
    ret

intlang_write:
    push rbp
    mov rbp, rsp
    mov rsi, rdi
    mov rdi, output_format
    xor eax, eax
    call printf
    leave
    ret

intlang_malloc:
    push rbp
    mov rbp, rsp
    shl rdi, 3
    call malloc
    leave
    ret

intlang_realloc:
    push rbp
    mov rbp, rsp
    shl rsi, 3
    call realloc
    leave
    ret

intlang_read_c:
    xor rax, rax
    xor rdi, rdi
    mov rsi, utf8
    mov rdx, 1
    syscall
    test rax, rax
    jz read_utf8_eof
    movzx r8, byte [utf8]
    cmp r8, 0b11110000
    jae read_utf8_four_byte
    cmp r8, 0b11100000
    jae read_utf8_three_byte
    cmp r8, 0b11000000
    jae read_utf8_two_byte
    mov rax, r8
    ret

read_utf8_two_byte:
    mov rdx, 1
    and r8, 0b00011111
    jmp read_utf8_common

read_utf8_three_byte:
    mov rdx, 2
    and r8, 0b00001111
    jmp read_utf8_common

read_utf8_four_byte:
    mov rdx, 3
    and r8, 0b00000111

read_utf8_common:
    xor rax, rax
    xor rdi, rdi
    lea rsi, [utf8+1]
    syscall
read_utf8_loop:
    shl r8, 6
    movzx rax, byte [rsi]
    and al, 0b00111111
    add r8, rax
    inc rsi
    dec rdx
    jnz read_utf8_loop
    mov rax, r8
    ret

read_utf8_eof:
    mov rax, -1
    ret

intlang_write_c:
    mov rax, rdi
    cmp rax, 0x10000
    jae write_utf8_four_byte
    cmp rax, 0x800
    jae write_utf8_three_byte
    cmp rax, 0x80
    jae write_utf8_two_byte

    mov byte [utf8], al
    mov rax, 1
    mov rdi, 1
    mov rsi, utf8
    mov rdx, 1
    syscall
    ret

write_utf8_two_byte:
    mov rdx, 2
    mov rdi, rax
    shr rdi, 6
    and rdi, 0b00011111
    or rdi, 0b11000000
    mov byte [utf8], dil
    jmp write_utf8_common

write_utf8_three_byte:
    mov rdx, 3
    mov rdi, rax
    shr rdi, 12
    and rdi, 0b00001111
    or rdi, 0b11100000
    mov byte [utf8], dil
    jmp write_utf8_common

write_utf8_four_byte:
    mov rdx, 4
    mov rdi, rax
    shr rdi, 18
    and rdi, 0b00000111
    or rdi, 0b11110000
    mov byte [utf8], dil

write_utf8_common:
    lea rsi, [utf8+rdx-1]

write_utf8_loop:
    mov rdi, rax
    and rdi, 0b00111111
    or rdi, 0b10000000
    mov byte [rsi], dil
    shr rax, 6
    dec rsi
    cmp rsi, utf8
    jne write_utf8_loop

    mov rax, 1
    mov rdi, 1
    mov rsi, utf8
    syscall
    ret

intlang_free:
    push rbp
    mov rbp, rsp
    call free
    leave
    ret

intlang_s_to_i:
    xor rax, rax
    lea rdx, [rsi+rdi*8]
    mov rcx, [rsi]
    cmp rcx, '+'
    je s_to_i_plus_sign
    cmp rcx, '-'
    je s_to_i_minus_sign
    jmp s_to_i_no_sign
s_to_i_plus_sign:
    add rsi, 8
s_to_i_no_sign:
s_to_i_positive_loop:
    imul rax, 10
    mov rcx, [rsi]
    sub rcx, '0'
    add rax, rcx
    add rsi, 8
    cmp rsi, rdx
    jne s_to_i_positive_loop
    ret
s_to_i_minus_sign:
    add rsi, 8
s_to_i_negative_loop:
    imul rax, 10
    mov rcx, [rsi]
    sub rcx, '0'
    sub rax, rcx
    add rsi, 8
    cmp rsi, rdx
    jne s_to_i_negative_loop
    ret

intlang_i_to_s:
    mov rax, rdi
    xor rdi, rdi
    mov rcx, 10
    lea rsi, [decimal_number+8*20]
    cmp rax, 0
    jl i_to_s_negative_loop
i_to_s_positive_loop:
    cqo
    idiv rcx
    add rdx, '0'
    mov [rsi], rdx
    sub rsi, 8
    inc rdi
    test rax, rax
    jnz i_to_s_positive_loop

    mov [rsi], rdi
    mov rax, rsi
    ret

i_to_s_negative_loop:
    cqo
    idiv rcx
    neg rdx
    add rdx, '0'
    mov [rsi], rdx
    sub rsi, 8
    inc rdi
    test rax, rax
    jnz i_to_s_negative_loop

    mov [rsi], '-'
    sub rsi, 8
    inc rdi
    mov [rsi], rdi
    mov rax, rsi
    ret
"
    );

    cg = new_codegen(strings, constants);

    i = 0;
    while(i < functions_and_constants[s_vec_count]) {
        if((f_or_c = functions_and_constants[s_vec_data][i])[s_function_or_constant_kind] != function_or_constant_function) {
            i = i + 1;
            continue;
        };
        if(generate_function(cg, f_or_c[s_function_or_constant_data]) == codegen_fail) {
            codegen_free(cg);

            i = 0;
            while(i < functions_and_constants[s_vec_count]) {
                function_or_constant_free(functions_and_constants[s_vec_data][i]);
                i = i + 1;
            };

            return codegen_fail;
        };
        i = i + 1;
    };

    codegen_free(cg);

    write_str(
"main:
    push rbp
    mov rbp, rsp
    call intlang_main
    leave
    ret
"
    );


    i = 0;
    while(i < functions_and_constants[s_vec_count]) {
        function_or_constant_free(functions_and_constants[s_vec_data][i]);
        i = i + 1;
    };

    return 0;
}

fn main() {
    s = new_scanner();
    lexemes = new_vec();
    while((l = scanner_next_lexeme(s))[s_lexeme_token] != token_eof & l[s_lexeme_token] != token_err) {
        vec_push(lexemes, l);
    };
    // free last eof or err lexeme
    free(l);

    if(l[s_lexeme_token] == token_err) {
        i = 0;
        while(i < lexemes[s_vec_count]) {
            lexeme_free(lexemes[s_vec_data][i]);
            i = i + 1;
        };
        vec_free(lexemes);
        scanner_free(s);
        write_str("Failed to lex!\n");
        return 1;
    };

    scanner_free(s);

    p = new_parser(lexemes);
    functions_and_constants = new_vec();
    while(1) {
        if(parser_peek_token(p) == token_eof) {
            break;
        };
        if((f_or_c = parser_parse_function_or_constant(p)) == parser_parse_fail) {
            i = 0;
            while(i < functions_and_constants[s_vec_count]) {
                function_or_constant_free(functions_and_constants[s_vec_data][i]);
                i = i + 1;
            };
            vec_free(functions_and_constants);
            parser_free(p);
            write_str("Failed to parse!\n");
            return 1;
        };
        vec_push(functions_and_constants, f_or_c);
    };

    parser_free(p);

    if(generate_binary(functions_and_constants) == codegen_fail) {
        return 1;
    };

    return 0;
}
