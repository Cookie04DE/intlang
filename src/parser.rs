use std::convert::identity;

use chumsky::{
    IterParser, Parser,
    pratt::{infix, left, postfix, prefix, right},
    primitive::{choice, empty, just},
    recursive::recursive,
    select,
};
use either::Either::{Left, Right};
use itertools::Itertools;

use crate::{
    ast::{ConstantValue, Expression, Function, SourceFile, Statement},
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
        .map(Left)
        .or(constant_parser().map(Right))
        .repeated()
        .collect()
        .map(|functions_or_constants: Vec<_>| {
            let (functions, constants) = functions_or_constants.into_iter().partition_map(identity);
            SourceFile {
                functions,
                constants,
            }
        })
}

fn literal<'src>() -> impl Parser<'src, &'src [Lexeme<'src>], i64> + Clone {
    choice((
        just(Lexeme::MinusSign).to(true),
        just(Lexeme::PlusSign).to(false),
        empty().to(false),
    ))
    .then(select! {Lexeme::Literal(num) => num})
    .map(|(negative, num)| if negative { -num } else { num })
}

fn constant_parser<'src>()
-> impl Parser<'src, &'src [Lexeme<'src>], (&'src str, ConstantValue<'src>)> + Clone {
    just(Lexeme::Const)
        .ignore_then(select! {Lexeme::Ident(name) => name})
        .then_ignore(just(Lexeme::EqualSign))
        .then(
            literal().map(ConstantValue::Integer)
                .or(select! {Lexeme::String(s) => ConstantValue::String(s.into_iter().map(Into::into).collect())}),
        )
        .then_ignore(just(Lexeme::Semicolon))
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
            recursive(|if_parser| {
                just(Lexeme::If)
                    .ignore_then(braced_expression_parser())
                    .then(statement_block_parser(statement_parser.clone()))
                    .then(
                        just(Lexeme::Else)
                            .ignore_then(
                                statement_block_parser(statement_parser.clone())
                                    .or(if_parser.map(|if_stm| vec![if_stm])),
                            )
                            .or_not(),
                    )
                    .map(|((condition, then), otherwise)| Statement::If {
                        condition,
                        then,
                        otherwise: otherwise.unwrap_or_default(),
                    })
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
                literal().map(Expression::Literal),
                select! {Lexeme::Ident(name) => Expression::Ident(name)},
                select! {Lexeme::String(s) => Expression::String(s.into_iter().map(Into::into).collect())},
            ))
        }
        .pratt((
            infix(right(0), just(Lexeme::EqualSign), |left, _, right, _| {
                Expression::Assignment(Box::new(left), Box::new(right))
            }),
            infix(left(1), just(Lexeme::OrSign), |left, _, right, _| {
                Expression::Or(Box::new(left), Box::new(right))
            }),
            infix(left(2), just(Lexeme::Caret), |left, _, right, _| {
                Expression::Xor(Box::new(left), Box::new(right))
            }),
            infix(left(3), just(Lexeme::AndSign), |left, _, right, _| {
                Expression::And(Box::new(left), Box::new(right))
            }),
            infix(
                left(4),
                just(Lexeme::DoubleEqualSign),
                |left, _, right, _| Expression::Equal(Box::new(left), Box::new(right)),
            ),
            infix(
                left(4),
                just(Lexeme::ExclamationPointEqualSign),
                |left, _, right, _| Expression::NotEqual(Box::new(left), Box::new(right)),
            ),
            infix(left(5), just(Lexeme::LessThanSign), |left, _, right, _| {
                Expression::LessThan(Box::new(left), Box::new(right))
            }),
            infix(
                left(5),
                just(Lexeme::LessThanSignEqualSign),
                |left, _, right, _| Expression::LessThanOrEqualTo(Box::new(left), Box::new(right)),
            ),
            infix(
                left(5),
                just(Lexeme::GreaterThanSign),
                |left, _, right, _| Expression::GreaterThan(Box::new(left), Box::new(right)),
            ),
            infix(
                left(5),
                just(Lexeme::GreaterThanSignEqualSign),
                |left, _, right, _| {
                    Expression::GreaterThanOrEqualTo(Box::new(left), Box::new(right))
                },
            ),
            infix(left(6), just(Lexeme::PlusSign), |left, _, right, _| {
                Expression::Add(Box::new(left), Box::new(right))
            }),
            infix(left(6), just(Lexeme::MinusSign), |left, _, right, _| {
                Expression::Sub(Box::new(left), Box::new(right))
            }),
            infix(left(7), just(Lexeme::Asterisk), |left, _, right, _| {
                Expression::Mul(Box::new(left), Box::new(right))
            }),
            infix(left(7), just(Lexeme::Slash), |left, _, right, _| {
                Expression::Div(Box::new(left), Box::new(right))
            }),
            infix(left(7), just(Lexeme::PercentSign), |left, _, right, _| {
                Expression::Mod(Box::new(left), Box::new(right))
            }),
            prefix(8, just(Lexeme::MinusSign), |_, expr, _| {
                Expression::Negation(Box::new(expr))
            }),
            prefix(8, just(Lexeme::ExclamationPoint), |_, expr, _| {
                Expression::LogicalNot(Box::new(expr))
            }),
            prefix(8, just(Lexeme::Tilde), |_, expr, _| {
                Expression::BitwiseNot(Box::new(expr))
            }),
            postfix(
                9,
                expression_parser.delimited_by(
                    just(Lexeme::OpenSquareBracket),
                    just(Lexeme::CloseSquareBracket),
                ),
                |a, b, _| Expression::Index(Box::new(a), Box::new(b)),
            ),
        ))
    })
}
