#[derive(Debug, Clone, PartialEq, Eq)]
pub struct SourceFile<'src> {
    pub functions: Vec<Function<'src>>,
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
    VariableAssignment(&'src str, Box<Expression<'src>>),
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
