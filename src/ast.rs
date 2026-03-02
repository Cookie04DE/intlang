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
    Assignment(Box<Expression<'src>>, Box<Expression<'src>>),
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

#[derive(Debug, Clone, PartialEq, Eq)]
pub enum Expression<'src> {
    Ident(&'src str),
    FunctionCall(&'src str, Vec<Expression<'src>>),
    Index(Box<Expression<'src>>, Box<Expression<'src>>),
    Literal(i64),
    String(Vec<StringComponent<'src>>),
    Negation(Box<Expression<'src>>),
    Equal(Box<Expression<'src>>, Box<Expression<'src>>),
    NotEqual(Box<Expression<'src>>, Box<Expression<'src>>),
    LessThan(Box<Expression<'src>>, Box<Expression<'src>>),
    LessThanOrEqualTo(Box<Expression<'src>>, Box<Expression<'src>>),
    GreaterThan(Box<Expression<'src>>, Box<Expression<'src>>),
    GreaterThanOrEqualTo(Box<Expression<'src>>, Box<Expression<'src>>),
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
