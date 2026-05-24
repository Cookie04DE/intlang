use crate::lexer;

#[derive(Debug, Clone, PartialEq, Eq)]
pub struct SourceFile<'src> {
    pub functions: Vec<Function<'src>>,
    pub constants: Vec<(&'src str, ConstantValue<'src>)>,
}

#[derive(Debug, Clone, PartialEq, Eq)]
pub enum ConstantValue<'src> {
    Integer(i64),
    String(Vec<StringComponent<'src>>),
}

#[derive(Debug, Clone, PartialEq, Eq)]
pub struct Function<'src> {
    pub name: &'src str,
    pub parameters: Vec<&'src str>,
    pub body: Vec<Statement<'src>>,
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
    Break(Option<&'src str>),
    Continue(Option<&'src str>),
    While {
        label: Option<&'src str>,
        condition: Expression<'src>,
        body: Vec<Statement<'src>>,
    },
}

#[derive(Debug, Clone, Copy, PartialEq, Eq)]
pub enum StringComponent<'src> {
    Literal(&'src str),
    Escaped(char),
}

impl<'src> From<lexer::StringComponent<'src>> for StringComponent<'src> {
    fn from(value: lexer::StringComponent<'src>) -> Self {
        match value {
            lexer::StringComponent::Literal(s) => Self::Literal(s),
            lexer::StringComponent::Escaped(c) => Self::Escaped(c),
        }
    }
}

#[derive(Debug, Clone, Copy, PartialEq, Eq)]
pub enum UnaryOp {
    Negation,
    LogicalNot,
    BitwiseNot,
}

#[derive(Debug, Clone, Copy, PartialEq, Eq)]
pub enum BinaryOp {
    Index,
    Equal,
    NotEqual,
    LessThan,
    LessThanOrEqualTo,
    GreaterThan,
    GreaterThanOrEqualTo,
    Or,
    And,
    Xor,
    Add,
    Sub,
    Mul,
    Div,
    Mod,
    Assignment,
}

#[derive(Debug, Clone, PartialEq, Eq)]
pub enum Expression<'src> {
    Ident(&'src str),
    FunctionCall(&'src str, Vec<Expression<'src>>),
    Literal(i64),
    String(Vec<StringComponent<'src>>),
    UnaryOperation {
        operand: Box<Expression<'src>>,
        op: UnaryOp,
    },
    BinaryOperation {
        left: Box<Expression<'src>>,
        right: Box<Expression<'src>>,
        op: BinaryOp,
    },
}
