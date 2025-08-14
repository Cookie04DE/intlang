use chumsky::{
    IterParser, Parser,
    pratt::{infix, left, postfix, prefix},
    prelude::{choice, recursive},
    primitive::just,
    select,
};

use crate::{
    ast::{Expression, Function, SourceFile, Statement},
    lexer::Lexeme,
};

pub fn parse<'src>(lexemes: &'src [Lexeme<'src>]) -> SourceFile<'src> {
    parser()
        .parse(lexemes)
        .into_result()
        .expect("could not parse input")
}

fn parser<'src>() -> impl Parser<'src, &'src [Lexeme<'src>], SourceFile<'src>> + Clone {
    function_parser()
        .repeated()
        .collect()
        .map(|functions| SourceFile { functions })
}

fn function_parser<'src>() -> impl Parser<'src, &'src [Lexeme<'src>], Function<'src>> + Clone {
    just(Lexeme::Fn)
        .ignore_then(
            select! {Lexeme::Ident(name) => name}.then(
                select! {Lexeme::Ident(param) => param}
                    .separated_by(just(Lexeme::Comma))
                    .allow_trailing()
                    .collect()
                    .delimited_by(just(Lexeme::OpenBrace), just(Lexeme::CloseBrace)),
            ),
        )
        .then(statement_block_parser(statement_parser()))
        .map(|((name, parameters), body)| Function {
            name,
            parameters,
            body,
        })
}

fn statement_block_parser<'src>(
    statement_parser: impl Parser<'src, &'src [Lexeme<'src>], Statement<'src>> + Clone,
) -> impl Parser<'src, &'src [Lexeme<'src>], Vec<Statement<'src>>> + Clone {
    statement_parser
        .repeated()
        .collect()
        .delimited_by(just(Lexeme::OpenCurly), just(Lexeme::CloseCurly))
}

fn statement_parser<'src>() -> impl Parser<'src, &'src [Lexeme<'src>], Statement<'src>> + Clone {
    recursive(|statement_parser| {
        choice((
            just(Lexeme::If)
                .ignore_then(braced_expression_parser())
                .then(statement_block_parser(statement_parser.clone()))
                .then(
                    just(Lexeme::Else)
                        .ignore_then(statement_block_parser(statement_parser.clone()))
                        .or_not(),
                )
                .map(|((condition, then), otherwise)| Statement::If {
                    condition,
                    then,
                    otherwise: otherwise.unwrap_or_default(),
                }),
            just(Lexeme::Break)
                .ignore_then(select! {Lexeme::Ident(name) => name}.or_not())
                .map(Statement::Break),
            just(Lexeme::Continue)
                .ignore_then(select! {Lexeme::Ident(name) => name}.or_not())
                .map(Statement::Continue),
            just(Lexeme::Return)
                .ignore_then(expression_parser())
                .map(Statement::Return),
            select! {Lexeme::Ident(name) => name}
                .then_ignore(just(Lexeme::Colon))
                .or_not()
                .then_ignore(just(Lexeme::While))
                .then(braced_expression_parser())
                .then(statement_block_parser(statement_parser))
                .map(|((label, condition), body)| Statement::While {
                    label,
                    condition,
                    body,
                }),
            expression_parser()
                .then_ignore(just(Lexeme::EqualSign))
                .then(expression_parser())
                .map(|(left, right)| Statement::Assignment(Box::new(left), Box::new(right))),
            expression_parser().map(Statement::Expression),
        ))
        .then_ignore(just(Lexeme::Semicolon))
    })
}

fn braced_expression_parser<'src>()
-> impl Parser<'src, &'src [Lexeme<'src>], Expression<'src>> + Clone {
    expression_parser().delimited_by(just(Lexeme::OpenBrace), just(Lexeme::CloseBrace))
}

fn expression_parser<'src>() -> impl Parser<'src, &'src [Lexeme<'src>], Expression<'src>> + Clone {
    recursive(|expression_parser| {
        {
            choice((
                select! {Lexeme::Ident(name) => name}
                    .then(
                        expression_parser
                            .clone()
                            .separated_by(just(Lexeme::Comma))
                            .allow_trailing()
                            .collect()
                            .delimited_by(just(Lexeme::OpenBrace), just(Lexeme::CloseBrace)),
                    )
                    .map(|(name, args)| Expression::FunctionCall(name, args)),
                expression_parser
                    .clone()
                    .delimited_by(just(Lexeme::OpenBrace), just(Lexeme::CloseBrace)),
                select! {Lexeme::Ident(name) => Expression::Variable(name)},
                select! {Lexeme::Literal(num) => Expression::Literal(num)},
            ))
        }
        .pratt((
            infix(left(0), just(Lexeme::OrSign), |left, _, right, _| {
                Expression::Or(Box::new(left), Box::new(right))
            }),
            infix(left(1), just(Lexeme::Caret), |left, _, right, _| {
                Expression::Xor(Box::new(left), Box::new(right))
            }),
            infix(left(2), just(Lexeme::AndSign), |left, _, right, _| {
                Expression::And(Box::new(left), Box::new(right))
            }),
            infix(
                left(3),
                just(Lexeme::DoubleEqualSign),
                |left, _, right, _| Expression::Equal(Box::new(left), Box::new(right)),
            ),
            infix(
                left(3),
                just(Lexeme::ExclamationPointEqualSign),
                |left, _, right, _| Expression::NotEqual(Box::new(left), Box::new(right)),
            ),
            infix(left(4), just(Lexeme::LessThenSign), |left, _, right, _| {
                Expression::LessThen(Box::new(left), Box::new(right))
            }),
            infix(
                left(4),
                just(Lexeme::LessThenSignEqualSign),
                |left, _, right, _| Expression::LessThenOrEqualTo(Box::new(left), Box::new(right)),
            ),
            infix(
                left(4),
                just(Lexeme::GreaterThenSign),
                |left, _, right, _| Expression::GreaterThen(Box::new(left), Box::new(right)),
            ),
            infix(
                left(4),
                just(Lexeme::GreaterThenSignEqualSign),
                |left, _, right, _| {
                    Expression::GreaterThenOrEqualTo(Box::new(left), Box::new(right))
                },
            ),
            infix(left(5), just(Lexeme::PlusSign), |left, _, right, _| {
                Expression::Add(Box::new(left), Box::new(right))
            }),
            infix(left(5), just(Lexeme::Minus), |left, _, right, _| {
                Expression::Sub(Box::new(left), Box::new(right))
            }),
            infix(left(6), just(Lexeme::Asterisk), |left, _, right, _| {
                Expression::Mul(Box::new(left), Box::new(right))
            }),
            infix(left(6), just(Lexeme::Slash), |left, _, right, _| {
                Expression::Div(Box::new(left), Box::new(right))
            }),
            infix(left(6), just(Lexeme::PercentSign), |left, _, right, _| {
                Expression::Mod(Box::new(left), Box::new(right))
            }),
            prefix(7, just(Lexeme::Minus), |_, expr, _| {
                Expression::Negation(Box::new(expr))
            }),
            prefix(7, just(Lexeme::ExclamationPoint), |_, expr, _| {
                Expression::LogicalNot(Box::new(expr))
            }),
            prefix(7, just(Lexeme::Tilde), |_, expr, _| {
                Expression::BitwiseNot(Box::new(expr))
            }),
            postfix(
                8,
                expression_parser.delimited_by(
                    just(Lexeme::OpenSquareBracket),
                    just(Lexeme::CloseSquareBracket),
                ),
                |a, b, _| Expression::Index(Box::new(a), Box::new(b)),
            ),
        ))
    })
}
