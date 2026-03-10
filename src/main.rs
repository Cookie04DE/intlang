#![deny(clippy::pedantic)]
use std::{fs, path::PathBuf};

use clap::Parser;

pub(crate) mod ast;
mod codegen;
mod lexer;
mod parser;

/// The stage0 intlang compiler written in Rust
#[derive(Debug, Parser)]
struct Args {
    /// The intlang source file to compile
    source_file: PathBuf,
    /// The target binary path
    target_path: Option<PathBuf>,
}

fn main() {
    let args = Args::parse();
    let source_code = fs::read_to_string(&args.source_file).expect("failed reading source code");
    let lexemes = lexer::lex(&source_code);
    let ast = parser::parse(&lexemes);
    codegen::generate_binary(
        &ast,
        &args
            .target_path
            .unwrap_or(args.source_file.with_extension("")),
    );
}
