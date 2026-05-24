use std::convert::identity;

use chumsky::{
    IterParser, Parser, extra,
    pratt::{Associativity, Operator, infix, left, postfix, prefix, right},
    primitive::{choice, empty, just},
    recursive::recursive,
    select,
};
use either::Either::{Left, Right};
use itertools::Itertools;

use crate::{
    ast::{BinaryOp, ConstantValue, Expression, Function, SourceFile, Statement, UnaryOp},
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
    fn binary<'src>(
        assoc: Associativity,
        operator: Lexeme<'src>,
        op: BinaryOp,
    ) -> impl Operator<'src, &'src [Lexeme<'src>], Expression<'src>, extra::Default> + Clone {
        infix(assoc, just(operator), move |left, _, right, _| {
            Expression::BinaryOperation {
                left: Box::new(left),
                right: Box::new(right),
                op,
            }
        })
    }

    fn unary<'src>(expr: Expression<'src>, op: UnaryOp) -> Expression<'src> {
        Expression::UnaryOperation {
            operand: Box::new(expr),
            op,
        }
    }

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
            binary(right(0), Lexeme::EqualSign, BinaryOp::Assignment),
            binary(left(1), Lexeme::OrSign, BinaryOp::Or),
            binary(left(2), Lexeme::Caret, BinaryOp::Xor),
            binary(left(3), Lexeme::AndSign, BinaryOp::And),
            binary(left(4), Lexeme::DoubleEqualSign, BinaryOp::Equal),
            binary(left(4), Lexeme::ExclamationPointEqualSign, BinaryOp::NotEqual),
            binary(left(5), Lexeme::LessThanSign, BinaryOp::LessThan),
            binary(left(5), Lexeme::LessThanSignEqualSign, BinaryOp::LessThanOrEqualTo),
            binary(left(5), Lexeme::GreaterThanSign, BinaryOp::GreaterThan),
            binary(left(5), Lexeme::GreaterThanSignEqualSign, BinaryOp::GreaterThanOrEqualTo),
            binary(left(6), Lexeme::PlusSign, BinaryOp::Add),
            binary(left(6), Lexeme::MinusSign, BinaryOp::Sub),
            binary(left(7), Lexeme::Asterisk, BinaryOp::Mul),
            binary(left(7), Lexeme::Slash, BinaryOp::Div),
            binary(left(7), Lexeme::PercentSign, BinaryOp::Mod),
            prefix(8, just(Lexeme::MinusSign), |_, expr, _| unary(expr, UnaryOp::Negation)),
            prefix(8, just(Lexeme::ExclamationPoint), |_, expr, _| unary(expr, UnaryOp::LogicalNot)),
            prefix(8, just(Lexeme::Tilde), |_, expr, _| unary(expr, UnaryOp::BitwiseNot)),
            postfix(
                9,
                expression_parser.delimited_by(
                    just(Lexeme::OpenSquareBracket),
                    just(Lexeme::CloseSquareBracket),
                ),
                |a, b, _| Expression::BinaryOperation{
                    left: Box::new(a),
                    right: Box::new(b),
                    op: BinaryOp::Index,
                },
            ),
        ))
    })
}
