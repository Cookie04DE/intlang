use std::{
    collections::{HashMap, HashSet},
    fmt::Write,
    fs,
    ops::{Deref, DerefMut},
    path::Path,
    process::Command,
};

use tempfile::TempDir;

use crate::ast::{Expression, Function, SourceFile, Statement};

const PREAMBLE: &str = r#"
section .data
    input_format db "%ld", 0
    output_format db "%ld", 10, 0

section .bss
    number resq 1

section .text
    global main
    extern scanf
    extern printf

read:
    push rbp
    mov rbp, rsp
    lea rdi, [input_format]
    lea rsi, [number]
    xor eax, eax
    call scanf
    mov rax, [number]
    leave
    ret

write:
    push rbp
    mov rbp, rsp
    lea rdi, [output_format]
    mov rsi, rax
    xor eax, eax
    call printf
    leave
    ret

main:
    push rbp
    mov rbp, rsp
"#;

const POSTAMBLE: &str = r"
    leave
    ret
";

fn run_command(cmd: &mut Command) {
    let out = cmd.output().expect("failed running command");
    assert!(
        out.status.success(),
        "Command failed; Stdout:\n{}\nStderr:\n{}",
        String::from_utf8_lossy(&out.stdout),
        String::from_utf8_lossy(&out.stderr)
    );
}

#[derive(Debug, Default)]
struct CodeGen {
    content: String,
    label_counter: usize,
}

pub fn generate_binary(ast: &SourceFile<'_>, target: &Path) {
    let tmp_dir = TempDir::new().expect("could not create temp dir");

    let asm_file = tmp_dir.path().join("program.asm");

    let mut content = String::new();

    content.push_str(PREAMBLE);
    content.push_str(
        r"
    call intlang_main
",
    );
    content.push_str(POSTAMBLE);

    let mut codegen = CodeGen::default();

    for f in &ast.functions {
        let mut codegen_function = CodeGenFunction {
            parent: &mut codegen,
            vars: HashMap::new(),
            intermediate_counter: 0,
            loop_entries_stack: vec![],
            loop_entries_by_name: HashMap::new(),
        };
        codegen_function.generate_function(f);
    }

    content.push_str(&codegen.content);

    println!("{content}");

    fs::write(&asm_file, &content).expect("failed writing temp assembly file");

    run_command(
        Command::new("nasm")
            .args(["-f", "elf64", "-o", "program.o", "program.asm"])
            .current_dir(&tmp_dir),
    );

    run_command(
        Command::new("gcc")
            .args(["-no-pie", "-o", "program", "program.o"])
            .current_dir(&tmp_dir),
    );

    fs::copy(tmp_dir.path().join("program"), target).expect("failed copying final executable");
}

impl CodeGen {
    fn get_next_label(&mut self) -> String {
        let label = format!("L{}", self.label_counter);
        self.label_counter += 1;
        label
    }
}

struct LoopEntry {
    start: String,
    end: String,
}

struct CodeGenFunction<'a> {
    parent: &'a mut CodeGen,
    vars: HashMap<String, usize>,
    intermediate_counter: usize,
    loop_entries_by_name: HashMap<String, LoopEntry>,
    loop_entries_stack: Vec<LoopEntry>,
}

impl Deref for CodeGenFunction<'_> {
    type Target = CodeGen;
    fn deref(&self) -> &Self::Target {
        self.parent
    }
}

impl DerefMut for CodeGenFunction<'_> {
    fn deref_mut(&mut self) -> &mut Self::Target {
        self.parent
    }
}

fn determine_max_intermediate_count_and_variables<'src>(
    stms: &[Statement<'src>],
) -> (usize, HashSet<&'src str>) {
    fn expr_max<'src>(expr: &Expression<'src>) -> (usize, HashSet<&'src str>) {
        match expr {
            Expression::Add(left, right)
            | Expression::Div(left, right)
            | Expression::And(left, right)
            | Expression::Equal(left, right)
            | Expression::GreaterThen(left, right)
            | Expression::GreaterThenOrEqualTo(left, right)
            | Expression::LessThen(left, right)
            | Expression::LessThenOrEqualTo(left, right)
            | Expression::Mod(left, right)
            | Expression::Mul(left, right)
            | Expression::NotEqual(left, right)
            | Expression::Or(left, right)
            | Expression::Sub(left, right)
            | Expression::Xor(left, right) => {
                let (left_inter, left_vars) = expr_max(left);
                let (right_inter, right_vars) = expr_max(right);

                (
                    left_inter.max(right_inter) + 1,
                    left_vars.union(&right_vars).copied().collect(),
                )
            }
            Expression::Variable(name) => (0, HashSet::from([*name])),
            Expression::Literal(_) => (0, HashSet::new()),
            Expression::FunctionCall(_, args) => {
                let (inter, vars) = args.iter().map(expr_max).fold(
                    (0, HashSet::new()),
                    |(prev_inter, prev_vars), (next_inter, next_vars)| {
                        (
                            prev_inter.max(next_inter),
                            prev_vars.union(&next_vars).copied().collect(),
                        )
                    },
                );
                (inter + args.len(), vars)
            }
            Expression::Negation(expr)
            | Expression::LogicalNot(expr)
            | Expression::BitwiseNot(expr) => expr_max(expr),
        }
    }

    fn stm_max<'src>(stm: &Statement<'src>) -> (usize, HashSet<&'src str>) {
        match stm {
            Statement::Break(_) | Statement::Continue(_) => (0, HashSet::new()),
            Statement::If {
                condition,
                then,
                otherwise,
            } => {
                let (condition_inter, condition_vars) = expr_max(condition);
                let (then_inter, then_vars) = determine_max_intermediate_count_and_variables(then);
                let (otherwise_inter, otherwise_vars) =
                    determine_max_intermediate_count_and_variables(otherwise);
                (
                    condition_inter.max(then_inter).max(otherwise_inter),
                    condition_vars
                        .union(&then_vars)
                        .copied()
                        .collect::<HashSet<&'src str>>()
                        .union(&otherwise_vars)
                        .copied()
                        .collect(),
                )
            }
            Statement::While {
                label: _,
                condition,
                body,
            } => {
                let (condition_inter, condition_vars) = expr_max(condition);
                let (body_inter, body_vars) = determine_max_intermediate_count_and_variables(body);
                (
                    condition_inter.max(body_inter),
                    condition_vars.union(&body_vars).copied().collect(),
                )
            }
            Statement::Expression(expr) | Statement::Return(expr) => expr_max(expr),
            Statement::VariableAssignment(var, expr) => {
                let (expr_inter, mut expr_vars) = expr_max(expr);

                expr_vars.insert(var);

                (expr_inter, expr_vars)
            }
        }
    }

    stms.iter().map(stm_max).fold(
        (0, HashSet::new()),
        |(prev_inter, prev_vars), (next_inter, next_vars)| {
            (
                prev_inter.max(next_inter),
                prev_vars.union(&next_vars).copied().collect(),
            )
        },
    )
}

const PARAMETER_REGISTERS: [&str; 6] = ["rdi", "rsi", "rdx", "rcx", "r8", "r9"];

impl CodeGenFunction<'_> {
    fn get_var_offset(&mut self, var: &str) -> usize {
        (self.vars[var] + 1) * 8
    }

    fn get_intermediate_offset(&self) -> usize {
        (self.vars.len() + 1 + self.intermediate_counter) * 8
    }

    fn generate_intermediate_save(&mut self) {
        let offset = self.get_intermediate_offset();
        let _ = write!(
            self.content,
            r"
    mov [rbp-{offset}], rax
",
        );
    }

    fn generate_intermediate_restore(&mut self) {
        let offset = self.get_intermediate_offset();
        let _ = write!(
            self.content,
            r"
    mov rdx, [rbp-{offset}]
",
        );
    }

    fn generate_function(&mut self, f: &Function<'_>) {
        assert!(
            f.parameters.len() <= 6,
            "can't handle functions with more than 6 parameters"
        );

        let (max_intermediate_count, mut vars) =
            determine_max_intermediate_count_and_variables(&f.body);

        vars.extend(&f.parameters);

        for var in &vars {
            let idx = self.vars.len();
            self.vars.insert((*var).to_string(), idx);
        }

        let _ = write!(
            self.parent.content,
            r"
intlang_{name}:
    push rbp
    mov rbp, rsp
    sub rsp, {stacksize}
",
            name = f.name,
            stacksize = ((max_intermediate_count + vars.len()) * 8).next_multiple_of(16),
        );

        for (param, reg) in f.parameters.iter().copied().zip(PARAMETER_REGISTERS) {
            let offset = self.get_var_offset(param);
            let _ = write!(
                self.content,
                r"
    mov [rbp-{offset}], {reg}
"
            );
        }
        self.generate_statements(&f.body);
    }

    fn get_loop_entry(&self, label: Option<&str>) -> &LoopEntry {
        match label {
            Some(label) => self
                .loop_entries_by_name
                .get(label)
                .unwrap_or_else(|| panic!("unknown label {label}")),
            None => self.loop_entries_stack.last().expect("not inside a loop"),
        }
    }

    #[allow(clippy::too_many_lines)]
    fn generate_statements(&mut self, stms: &[Statement]) {
        let loop_entries: HashSet<String> = self.loop_entries_by_name.keys().cloned().collect();
        let loop_entries_len = self.loop_entries_stack.len();
        for stm in stms {
            match stm {
                Statement::Expression(expr) => self.generate_expression(expr),
                Statement::VariableAssignment(name, expr) => {
                    self.generate_expression(expr);
                    let offset = self.get_var_offset(name);
                    let _ = write!(
                        self.content,
                        r"
    mov [rbp-{offset}], rax
    "
                    );
                }
                Statement::If {
                    condition,
                    then,
                    otherwise,
                } => {
                    self.generate_expression(condition);
                    let else_label = self.get_next_label();
                    let end_label = self.get_next_label();
                    let _ = write!(
                        self.content,
                        r"
    test rax, rax
    jz {else_label}
    "
                    );
                    self.generate_statements(then);
                    let _ = write!(
                        self.content,
                        r"
    jmp {end_label}
{else_label}:"
                    );
                    self.generate_statements(otherwise);
                    let _ = write!(
                        self.content,
                        r"
{end_label}:"
                    );
                }
                Statement::While {
                    label,
                    condition,
                    body,
                } => {
                    let start_label = self.get_next_label();
                    let end_label = self.get_next_label();

                    if let Some(label) = label {
                        self.loop_entries_by_name.insert(
                            (*label).to_string(),
                            LoopEntry {
                                start: start_label.clone(),
                                end: end_label.clone(),
                            },
                        );
                        self.loop_entries_stack.push(LoopEntry {
                            start: start_label.clone(),
                            end: end_label.clone(),
                        });
                    }

                    let _ = write!(
                        self.content,
                        r"
{start_label}:"
                    );
                    self.generate_expression(condition);
                    let _ = write!(
                        self.content,
                        r"
    test rax, rax
    jz {end_label}
    "
                    );
                    self.generate_statements(body);
                    let _ = write!(
                        self.content,
                        r"
    jmp {start_label}
{end_label}:"
                    );
                }
                Statement::Return(expr) => {
                    self.generate_expression(expr);
                    self.content.push_str(
                        r"
    leave
    ret
    ",
                    );
                }
                Statement::Break(label) => {
                    let end_label = self.get_loop_entry(*label).end.clone();
                    let _ = write!(
                        self.content,
                        r"
    jmp {end_label}
    "
                    );
                }
                Statement::Continue(label) => {
                    let start_label = self.get_loop_entry(*label).start.clone();
                    let _ = write!(
                        self.content,
                        r"
    jmp {start_label}
    "
                    );
                }
            }
        }
        self.loop_entries_by_name
            .retain(|k, _v| loop_entries.contains(k));
        self.loop_entries_stack.truncate(loop_entries_len);
    }

    #[allow(clippy::too_many_lines)]
    fn generate_expression(&mut self, expr: &Expression) {
        fn gen_double(
            cgf: &mut CodeGenFunction,
            first: &Expression<'_>,
            second: &Expression<'_>,
            instr: &str,
        ) {
            cgf.generate_expression(second);
            cgf.generate_intermediate_save();
            cgf.intermediate_counter += 1;
            cgf.generate_expression(first);
            cgf.intermediate_counter -= 1;
            cgf.generate_intermediate_restore();
            cgf.content.push_str(instr);
        }
        match expr {
            Expression::Add(first, second) => gen_double(
                self,
                first,
                second,
                r"
    add rax, rdx
",
            ),
            Expression::And(first, second) => gen_double(
                self,
                first,
                second,
                r"
    and rax, rdx
",
            ),

            Expression::BitwiseNot(expr) => {
                self.generate_expression(expr);
                self.content.push_str(
                    r"
    not rax
",
                );
            }
            Expression::Div(dividend, divisor) => {
                self.generate_expression(dividend);
                self.generate_intermediate_save();
                self.intermediate_counter += 1;
                self.generate_expression(divisor);
                self.intermediate_counter -= 1;
                let offset = self.get_intermediate_offset();
                let _ = write!(
                    self.content,
                    r"
    mov rsi, [rbp-{offset}]
    xchg rax, rsi
    cqo
    idiv rsi
",
                );
            }

            Expression::Equal(first, second) => gen_double(
                self,
                first,
                second,
                r"
    mov rsi, rax
    xor eax, eax
    cmp rsi, rdx
    sete al
",
            ),

            Expression::FunctionCall(name, arguments) => match *name {
                "read" => {
                    assert!(arguments.is_empty(), "read call cannot have any arguments");
                    let _ = write!(
                        self.content,
                        r"
    call read
"
                    );
                }
                "write" => {
                    assert!(
                        arguments.len() == 1,
                        "write call needs to have exactly one argument"
                    );
                    self.generate_expression(&arguments[0]);
                    let _ = write!(
                        self.content,
                        r"
    call write
"
                    );
                }
                _ => {
                    assert!(
                        arguments.len() <= 6,
                        "can't handle call with more than 6 parameters'"
                    );

                    let inner_base = self.intermediate_counter;
                    let outer_base = self.intermediate_counter + arguments.len();

                    for (off, arg) in arguments.iter().enumerate() {
                        self.intermediate_counter = outer_base;
                        self.generate_expression(arg);
                        self.intermediate_counter = inner_base + off;
                        self.generate_intermediate_save();
                    }

                    for (off, reg) in PARAMETER_REGISTERS.iter().take(arguments.len()).enumerate() {
                        self.intermediate_counter = inner_base + off;
                        let offset = self.get_intermediate_offset();
                        let _ = write!(
                            self.content,
                            r"
    mov {reg}, [rbp-{offset}]
",
                        );
                    }

                    let _ = write!(
                        self.content,
                        r"
    call intlang_{name}
    "
                    );

                    self.intermediate_counter = inner_base;
                }
            },
            Expression::Variable(name) => {
                let offset = self.get_var_offset(name);
                let _ = write!(
                    self.content,
                    r"
    mov rax, [rbp-{offset}]
    "
                );
            }
            Expression::Literal(literal) => {
                let _ = write!(
                    self.content,
                    r"
    mov rax, {literal}
    "
                );
            }
            Expression::Negation(expr) => {
                self.generate_expression(expr);
                self.content.push_str(
                    r"
    neg rax
",
                );
            }
            Expression::NotEqual(first, second) => gen_double(
                self,
                first,
                second,
                r"
    mov rsi, rax
    xor eax, eax
    cmp rsi, rdx
    setne al
",
            ),

            Expression::LessThen(first, second) => gen_double(
                self,
                second,
                first,
                r"
    xchg rax, rdx
    mov rsi, rax
    xor eax, eax
    cmp rsi, rdx
    setl al
",
            ),

            Expression::LessThenOrEqualTo(first, second) => gen_double(
                self,
                second,
                first,
                r"
    xchg rax, rdx
    mov rsi, rax
    xor eax, eax
    cmp rsi, rdx
    setle al
",
            ),

            Expression::GreaterThen(first, second) => gen_double(
                self,
                second,
                first,
                r"
    xchg rax, rdx
    mov rsi, rax
    xor eax, eax
    cmp rsi, rdx
    setg al
",
            ),

            Expression::GreaterThenOrEqualTo(first, second) => gen_double(
                self,
                second,
                first,
                r"
    xchg rax, rdx
    mov rsi, rax
    xor eax, eax
    cmp rsi, rdx
    setge al
",
            ),

            Expression::LogicalNot(expr) => {
                self.generate_expression(expr);
                self.content.push_str(
                    r"
    mov rsi, rax
    xor eax, eax
    test rsi, rsi
    sete al
",
                );
            }
            Expression::Or(first, second) => gen_double(
                self,
                first,
                second,
                r"
    or rax, rdx
",
            ),

            Expression::Xor(first, second) => gen_double(
                self,
                first,
                second,
                r"
    xor rax, rdx
",
            ),

            Expression::Sub(first, second) => gen_double(
                self,
                second,
                first,
                r"
    xchg rax, rdx
    sub rax, rdx
",
            ),

            Expression::Mul(first, second) => gen_double(
                self,
                first,
                second,
                r"
    imul rdx
",
            ),

            Expression::Mod(first, second) => {
                self.generate_expression(first);
                self.generate_intermediate_save();
                self.intermediate_counter += 1;
                self.generate_expression(second);
                self.intermediate_counter -= 1;
                let offset = self.get_intermediate_offset();
                let _ = write!(
                    self.content,
                    r"
    mov rsi, [rbp-{offset}]
    xchg rax, rsi
    cqo
    idiv rsi
    mov rax, rdx
",
                );
            }
        }
    }
}
