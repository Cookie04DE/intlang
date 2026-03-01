use chumsky::{
    IterParser, Parser,
    primitive::{any, choice, just},
    text::{ident, int, whitespace},
};

#[derive(Debug, Clone, Copy, PartialEq, Eq)]
pub enum StringComponent<'src> {
    Literal(&'src str),
    EscapedBackslash,
    EscapedNewline,
    EscapedDoubleQuote,
}

#[derive(Debug, Clone, PartialEq, Eq)]
pub enum Lexeme<'src> {
    Fn,
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
    LessThenSign,
    LessThenSignEqualSign,
    GreaterThenSign,
    GreaterThenSignEqualSign,
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

fn lexer<'src>() -> impl Parser<'src, &'src str, Vec<Lexeme<'src>>> {
    choice((
        just("fn").to(Lexeme::Fn),
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
        any()
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
            just("\\\\").to(StringComponent::EscapedBackslash),
            just("\\n").to(StringComponent::EscapedNewline),
            just("\\\"").to(StringComponent::EscapedDoubleQuote),
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
            just("<=").to(Lexeme::LessThenSignEqualSign),
            just('<').to(Lexeme::LessThenSign),
            just(">=").to(Lexeme::GreaterThenSignEqualSign),
            just('>').to(Lexeme::GreaterThenSign),
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
    .separated_by(whitespace())
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
