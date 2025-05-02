use chumsky::{
    IterParser, Parser,
    pratt::{infix, left, prefix},
    prelude::{choice, recursive},
    primitive::just,
    select,
};

use crate::lexer::Lexeme;

#[derive(Debug, Clone, PartialEq, Eq)]
pub struct Ast<'src> {
    pub functions: Vec<Function<'src>>,
}

pub fn parse<'src>(lexemes: &'src [Lexeme<'src>]) -> Ast<'src> {
    parser()
        .parse(lexemes)
        .into_result()
        .expect("could not parse input")
}

fn parser<'src>() -> impl Parser<'src, &'src [Lexeme<'src>], Ast<'src>> + Clone {
    function_parser()
        .repeated()
        .collect()
        .map(|functions| Ast { functions })
}

#[derive(Debug, Clone, PartialEq, Eq)]
pub struct Function<'src> {
    pub name: &'src str,
    pub parameters: Vec<&'src str>,
    pub body: Vec<Statement<'src>>,
}

fn function_parser<'src>() -> impl Parser<'src, &'src [Lexeme<'src>], Function<'src>> + Clone {
    just(Lexeme::Fn)
        .ignore_then(
            select! {Lexeme::Ident(param) => param}.then(
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

#[derive(Debug, Clone, PartialEq, Eq)]
pub enum Statement<'src> {
    Expression(Expression<'src>),
    If {
        condition: Expression<'src>,
        then: Vec<Statement<'src>>,
        otherwise: Vec<Statement<'src>>,
    },
    Return(Expression<'src>),
    While {
        condition: Expression<'src>,
        body: Vec<Statement<'src>>,
    },
    VariableAssignment(&'src str, Box<Expression<'src>>),
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
            just(Lexeme::Return)
                .ignore_then(expression_parser())
                .map(Statement::Return),
            just(Lexeme::While)
                .ignore_then(braced_expression_parser())
                .then(statement_block_parser(statement_parser))
                .map(|(condition, body)| Statement::While { condition, body }),
            select! {Lexeme::Ident(name) => name}
                .then_ignore(just(Lexeme::EqualSign))
                .then(expression_parser())
                .map(|(name, expression)| {
                    Statement::VariableAssignment(name, Box::new(expression))
                }),
            expression_parser().map(Statement::Expression),
        ))
        .then_ignore(just(Lexeme::Semicolon))
    })
}

#[derive(Debug, Clone, PartialEq, Eq)]
pub enum Expression<'src> {
    Variable(&'src str),
    FunctionCall(&'src str, Vec<Expression<'src>>),
    Literal(i64),
    Negation(Box<Expression<'src>>),
    Equal(Box<Expression<'src>>, Box<Expression<'src>>),
    NotEqual(Box<Expression<'src>>, Box<Expression<'src>>),
    LessThen(Box<Expression<'src>>, Box<Expression<'src>>),
    LessThenOrEqualTo(Box<Expression<'src>>, Box<Expression<'src>>),
    GreaterThen(Box<Expression<'src>>, Box<Expression<'src>>),
    GreaterThenOrEqualTo(Box<Expression<'src>>, Box<Expression<'src>>),
    LogicalNot(Box<Expression<'src>>),
    BitwiseNot(Box<Expression<'src>>),
    Or(Box<Expression<'src>>, Box<Expression<'src>>),
    And(Box<Expression<'src>>, Box<Expression<'src>>),
    Xor(Box<Expression<'src>>, Box<Expression<'src>>),
    Add(Box<Expression<'src>>, Box<Expression<'src>>),
    Sub(Box<Expression<'src>>, Box<Expression<'src>>),
    Mul(Box<Expression<'src>>, Box<Expression<'src>>),
    Div(Box<Expression<'src>>, Box<Expression<'src>>),
    Mod(Box<Expression<'src>>, Box<Expression<'src>>),
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
                select! {Lexeme::Ident(name) => name}
                    .then(
                        expression_parser
                            .separated_by(just(Lexeme::Comma))
                            .allow_trailing()
                            .collect(),
                    )
                    .map(|(name, arguments)| Expression::FunctionCall(name, arguments)),
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
        ))
    })
}
