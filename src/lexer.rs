use chumsky::{
    IterParser, Parser,
    primitive::{any, choice, just},
    text::{digits, ident, int, newline},
};

#[derive(Debug, Clone, Copy, PartialEq, Eq)]
pub enum StringComponent<'src> {
    Literal(&'src str),
    Escaped(char),
}

#[derive(Debug, Clone, PartialEq, Eq)]
pub enum Lexeme<'src> {
    Fn,
    Const,
    Break,
    Continue,
    Ident(&'src str),
    OpenBrace,
    CloseBrace,
    Comma,
    Colon,
    OpenCurly,
    CloseCurly,
    Return,
    Semicolon,
    OpenSquareBracket,
    CloseSquareBracket,
    Literal(i64),
    String(Vec<StringComponent<'src>>),
    If,
    Else,
    While,
    DoubleEqualSign,
    ExclamationPointEqualSign,
    LessThanSign,
    LessThanSignEqualSign,
    GreaterThanSign,
    GreaterThanSignEqualSign,
    ExclamationPoint,
    Tilde,
    OrSign,
    AndSign,
    Caret,
    EqualSign,
    PlusSign,
    Minus,
    Asterisk,
    Slash,
    PercentSign,
}

fn escaped_char<'src>() -> impl Parser<'src, &'src str, char> {
    just('\\').ignore_then(choice((
        just('0').to('\0'),
        just('t').to('\t'),
        just('r').to('\r'),
        just('\\').to('\\'),
        just('n').to('\n'),
        just('"').to('"'),
        just('\'').to('\''),
        just('x').ignore_then(
            digits(8)
                .exactly(1)
                .then(digits(16).exactly(1))
                .to_slice()
                .map(|s| char::try_from(u32::from_str_radix(s, 16).unwrap()).unwrap()),
        ),
    )))
}

fn whitespace_or_comments<'src>() -> impl Parser<'src, &'src str, ()> {
    choice((
        any().filter(|c: &char| c.is_whitespace()).ignored(),
        just("//")
            .then(any().and_is(newline().not()).repeated())
            .ignored(),
        just("/*")
            .then(any().and_is(just("*/").not()).repeated())
            .then(just("*/"))
            .ignored(),
    ))
    .repeated()
}

fn lexer<'src>() -> impl Parser<'src, &'src str, Vec<Lexeme<'src>>> {
    choice((
        just("fn").to(Lexeme::Fn),
        just("const").to(Lexeme::Const),
        just("return").to(Lexeme::Return),
        just("break").to(Lexeme::Break),
        just("continue").to(Lexeme::Continue),
        just("if").to(Lexeme::If),
        just("else").to(Lexeme::Else),
        just("while").to(Lexeme::While),
        ident().map(Lexeme::Ident),
        just('(').to(Lexeme::OpenBrace),
        just(')').to(Lexeme::CloseBrace),
        just(',').to(Lexeme::Comma),
        just('{').to(Lexeme::OpenCurly),
        just('}').to(Lexeme::CloseCurly),
        just(';').to(Lexeme::Semicolon),
        just(':').to(Lexeme::Colon),
        just('[').to(Lexeme::OpenSquareBracket),
        just(']').to(Lexeme::CloseSquareBracket),
        escaped_char()
            .or(any())
            .delimited_by(just('\''), just('\''))
            .map(|c: char| u32::from(c).into())
            .map(Lexeme::Literal),
        int(10)
            .map(str::parse)
            .map(Result::unwrap)
            .map(Lexeme::Literal),
        choice((
            any()
                .filter(|c| !matches!(c, '"' | '\\'))
                .repeated()
                .at_least(1)
                .to_slice()
                .map(StringComponent::Literal),
            escaped_char().map(StringComponent::Escaped),
        ))
        .repeated()
        .collect()
        .map(Lexeme::String)
        .delimited_by(just('"'), just('"')),
        just("!=").to(Lexeme::ExclamationPointEqualSign),
        just("==").to(Lexeme::DoubleEqualSign),
        // avoid overwhelming choice
        choice((
            just('!').to(Lexeme::ExclamationPoint),
            just("<=").to(Lexeme::LessThanSignEqualSign),
            just('<').to(Lexeme::LessThanSign),
            just(">=").to(Lexeme::GreaterThanSignEqualSign),
            just('>').to(Lexeme::GreaterThanSign),
            just('~').to(Lexeme::Tilde),
            just('|').to(Lexeme::OrSign),
            just('&').to(Lexeme::AndSign),
            just('^').to(Lexeme::Caret),
            just('=').to(Lexeme::EqualSign),
            just('+').to(Lexeme::PlusSign),
            just('-').to(Lexeme::Minus),
            just('*').to(Lexeme::Asterisk),
            just('/').to(Lexeme::Slash),
            just('%').to(Lexeme::PercentSign),
        )),
    ))
    .separated_by(whitespace_or_comments())
    .allow_leading()
    .allow_trailing()
    .collect()
}

pub fn lex(source: &str) -> Vec<Lexeme<'_>> {
    lexer()
        .parse(source)
        .into_result()
        .expect("could not lex source code")
}
