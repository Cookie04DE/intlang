#![deny(clippy::pedantic)]
use std::{
    fs,
    io::{Read, Write, stdin, stdout},
    path::PathBuf,
};

use clap::{Parser, Subcommand};

pub(crate) mod ast;
mod codegen;
mod lexer;
mod parser;

/// The stage0 intlang compiler written in Rust
#[derive(Debug, Parser)]
struct Args {
    #[command(subcommand)]
    command: Option<Command>,
}

#[derive(Debug, Subcommand)]
enum Command {
    /// Fully compile, assemble and link an intlang source file into a finished binary
    Full {
        /// The intlang source file to compile
        source_file: PathBuf,
        /// The target binary path
        target_path: Option<PathBuf>,
    },
}

fn main() {
    let args = Args::parse();
    if let Some(Command::Full {
        source_file,
        target_path,
    }) = args.command
    {
        let source_code = fs::read_to_string(&source_file).expect("failed reading source code");
        let lexemes = lexer::lex(&source_code);
        let ast = parser::parse(&lexemes);
        codegen::generate_binary(&ast, &target_path.unwrap_or(source_file.with_extension("")));
    } else {
        let mut source_code = String::new();

        stdin()
            .read_to_string(&mut source_code)
            .expect("failed reading source code from stdin");

        let lexemes = lexer::lex(&source_code);
        let ast = parser::parse(&lexemes);

        stdout()
            .write_all(codegen::generate_asm(&ast).as_bytes())
            .expect("failed writing asm to stdout");
    }
}
