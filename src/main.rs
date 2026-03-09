#![deny(clippy::pedantic)]
use std::{env::args, fs, path::Path};

pub(crate) mod ast;
mod codegen;
mod lexer;
mod parser;

fn main() {
    for file in args().skip(1) {
        let path = Path::new(&file);
        let source_code = fs::read_to_string(path).expect("failed reading source code");
        let lexemes = lexer::lex(&source_code);
        let ast = parser::parse(&lexemes);
        codegen::generate_binary(&ast, &path.with_extension(""));
    }
}
