use std::{
    collections::{HashMap, HashSet},
    fmt::Write,
    fs, iter,
    ops::{Deref, DerefMut},
    path::Path,
    process::Command,
};

use either::Either::{Left, Right};
use itertools::Itertools;
use tempfile::TempDir;

use crate::ast::{ConstantValue, Expression, Function, SourceFile, Statement, StringComponent};

const BUILTIN_DATA: &str = r#"
section .data
    input_format db "%ld", 0
    output_format db "%ld", 10, 0
"#;

const BUILTIN_STATIC: &str = r"
section .bss
    number resq 1
    utf8 resb 4
    decimal_number resq 21
";

const BUILTIN_FUNCTIONS: &str = r"
section .text
    global main
    extern scanf
    extern printf
    extern malloc
    extern realloc
    extern free

intlang_read:
    push rbp
    mov rbp, rsp
    mov rdi, input_format
    mov rsi, number
    xor eax, eax
    call scanf
    mov rax, [number]
    leave
    ret

intlang_write:
    push rbp
    mov rbp, rsp
    mov rsi, rdi
    mov rdi, output_format
    xor eax, eax
    call printf
    leave
    ret

intlang_malloc:
    push rbp
    mov rbp, rsp
    shl rdi, 3
    call malloc
    leave
    ret

intlang_realloc:
    push rbp
    mov rbp, rsp
    shl rsi, 3
    call realloc
    leave
    ret

intlang_read_c:
    xor rax, rax
    xor rdi, rdi
    mov rsi, utf8
    mov rdx, 1
    syscall
    test rax, rax
    jz read_utf8_eof
    movzx r8, byte [utf8]
    cmp r8, 0b11110000
    jae read_utf8_four_byte
    cmp r8, 0b11100000
    jae read_utf8_three_byte
    cmp r8, 0b11000000
    jae read_utf8_two_byte
    mov rax, r8
    ret

read_utf8_two_byte:
    mov rdx, 1
    and r8, 0b00011111
    jmp read_utf8_common

read_utf8_three_byte:
    mov rdx, 2
    and r8, 0b00001111
    jmp read_utf8_common

read_utf8_four_byte:
    mov rdx, 3
    and r8, 0b00000111

read_utf8_common:
    xor rax, rax
    xor rdi, rdi
    lea rsi, [utf8+1]
    syscall
read_utf8_loop:
    shl r8, 6
    movzx rax, byte [rsi]
    and al, 0b00111111
    add r8, rax
    inc rsi
    dec rdx
    jnz read_utf8_loop
    mov rax, r8
    ret

read_utf8_eof:
    mov rax, -1
    ret

intlang_write_c:
    cmp rax, 0x10000
    jae write_utf8_four_byte
    cmp rax, 0x800
    jae write_utf8_three_byte
    cmp rax, 0x80
    jae write_utf8_two_byte

    mov byte [utf8], al
    mov rax, 1
    mov rdi, 1
    mov rsi, utf8
    mov rdx, 1
    syscall
    ret

write_utf8_two_byte:
    mov rdx, 2
    mov rdi, rax
    shr rdi, 6
    and rdi, 0b00011111
    or rdi, 0b11000000
    mov byte [utf8], dil
    jmp write_utf8_common

write_utf8_three_byte:
    mov rdx, 3
    mov rdi, rax
    shr rdi, 12
    and rdi, 0b00001111
    or rdi, 0b11100000
    mov byte [utf8], dil
    jmp write_utf8_common

write_utf8_four_byte:
    mov rdx, 4
    mov rdi, rax
    shr rdi, 18
    and rdi, 0b00000111
    or rdi, 0b11110000
    mov byte [utf8], dil

write_utf8_common:
    lea rsi, [utf8+rdx-1]

write_utf8_loop:
    mov rdi, rax
    and rdi, 0b00111111
    or rdi, 0b10000000
    mov byte [rsi], dil
    shr rax, 6
    dec rsi
    cmp rsi, utf8
    jne write_utf8_loop

    mov rax, 1
    mov rdi, 1
    mov rsi, utf8
    syscall
    ret

intlang_free:
    push rbp
    mov rbp, rsp
    call free
    leave
    ret

intlang_s_to_i:
    xor rax, rax
    lea rdx, [rsi+rdi*8]
    mov rcx, [rsi]
    cmp rcx, '+'
    je s_to_i_plus_sign
    cmp rcx, '-'
    je s_to_i_minus_sign
    jmp s_to_i_no_sign
s_to_i_plus_sign:
    add rsi, 8
s_to_i_no_sign:
s_to_i_positive_loop:
    imul rax, 10
    mov rcx, [rsi]
    sub rcx, '0'
    add rax, rcx
    add rsi, 8
    cmp rsi, rdx
    jne s_to_i_positive_loop
    ret
s_to_i_minus_sign:
    add rsi, 8
s_to_i_negative_loop:
    imul rax, 10
    mov rcx, [rsi]
    sub rcx, '0'
    sub rax, rcx
    add rsi, 8
    cmp rsi, rdx
    jne s_to_i_negative_loop
    ret

intlang_i_to_s:
    mov rax, rdi
    xor rdi, rdi
    mov rcx, 10
    lea rsi, [decimal_number+8*20]
    cmp rax, 0
    jl i_to_s_negative_loop
i_to_s_positive_loop:
    cqo
    idiv rcx
    add rdx, '0'
    mov [rsi], rdx
    sub rsi, 8
    inc rdi
    test rax, rax
    jnz i_to_s_positive_loop

    mov [rsi], rdi
    mov rax, rsi
    ret

i_to_s_negative_loop:
    cqo
    idiv rcx
    neg rdx
    add rdx, '0'
    mov [rsi], rdx
    sub rsi, 8
    inc rdi
    test rax, rax
    jnz i_to_s_negative_loop

    mov [rsi], '-'
    sub rsi, 8
    inc rdi
    mov [rsi], rdi
    mov rax, rsi
    ret
";

const MAIN: &str = r"
main:
    push rbp
    mov rbp, rsp
";

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
    strings: HashMap<Vec<char>, usize>,
    constants: HashMap<String, String>,
}

pub fn generate_binary(ast: &SourceFile<'_>, target: &Path) {
    let tmp_dir = TempDir::new().expect("could not create temp dir");

    let asm_file = tmp_dir.path().join("program.asm");

    let mut content = String::new();

    let mut codegen = CodeGen::default();

    for c in &ast.constants {
        let value = match &c.1 {
            ConstantValue::String(s) => {
                format!("intlangstring_{}", codegen.get_or_insert_string(s))
            }
            ConstantValue::Integer(i) => format!("{i}"),
        };

        codegen.constants.insert(c.0.to_string(), value);
    }

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

    content.push_str(BUILTIN_DATA);
    for s in &codegen.strings {
        let _ = writeln!(
            content,
            r"
    intlangstring_{} dq {}",
            s.1,
            iter::once(u64::try_from(s.0.len()).unwrap())
                .chain(s.0.iter().map(|c| u64::from(*c)))
                .join(", ")
        );
    }

    content.push_str(BUILTIN_STATIC);
    content.push_str(BUILTIN_FUNCTIONS);
    content.push_str(&codegen.content);
    content.push_str(MAIN);
    content.push_str(
        r"
    call intlang_main
",
    );
    content.push_str(POSTAMBLE);

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

    fn get_or_insert_string(&mut self, s: &[StringComponent<'_>]) -> usize {
        let key = self.strings.len();
        *self
            .strings
            .entry(
                s.iter()
                    .flat_map(|c| match c {
                        StringComponent::Literal(s) => Left(s.chars()),
                        StringComponent::Escaped(c) => Right(iter::once(*c)),
                    })
                    .collect(),
            )
            .or_insert(key)
    }

    #[allow(clippy::too_many_lines)]
    fn determine_max_intermediate_count_and_variables<'src>(
        &self,
        stms: &[Statement<'src>],
    ) -> (usize, HashSet<&'src str>) {
        fn expr_max<'src>(
            code_gen: &CodeGen,
            expr: &Expression<'src>,
        ) -> (usize, HashSet<&'src str>) {
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
                | Expression::Xor(left, right)
                | Expression::Index(left, right) => {
                    let (left_inter, left_vars) = expr_max(code_gen, left);
                    let (right_inter, right_vars) = expr_max(code_gen, right);

                    (
                        left_inter.max(right_inter) + 1,
                        left_vars.union(&right_vars).copied().collect(),
                    )
                }
                Expression::Ident(name) => (
                    0,
                    if code_gen.constants.contains_key(*name) {
                        HashSet::new()
                    } else {
                        HashSet::from([*name])
                    },
                ),
                Expression::Literal(_) | Expression::String(_) => (0, HashSet::new()),
                Expression::FunctionCall(_, args) => {
                    let (inter, vars) = args.iter().map(|expr| expr_max(code_gen, expr)).fold(
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
                | Expression::BitwiseNot(expr) => expr_max(code_gen, expr),
            }
        }

        fn stm_max<'src>(code_gen: &CodeGen, stm: &Statement<'src>) -> (usize, HashSet<&'src str>) {
            match stm {
                Statement::Break(_) | Statement::Continue(_) => (0, HashSet::new()),
                Statement::If {
                    condition,
                    then,
                    otherwise,
                } => {
                    let (condition_inter, condition_vars) = expr_max(code_gen, condition);
                    let (then_inter, then_vars) =
                        code_gen.determine_max_intermediate_count_and_variables(then);
                    let (otherwise_inter, otherwise_vars) =
                        code_gen.determine_max_intermediate_count_and_variables(otherwise);
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
                    let (condition_inter, mut condition_vars) = expr_max(code_gen, condition);
                    let (body_inter, body_vars) =
                        code_gen.determine_max_intermediate_count_and_variables(body);
                    condition_vars.extend(body_vars);

                    (condition_inter.max(body_inter), condition_vars)
                }
                Statement::Expression(expr) | Statement::Return(expr) => expr_max(code_gen, expr),
                Statement::Assignment(left, right) => match &**left {
                    Expression::Ident(var) => {
                        let (expr_inter, mut expr_vars) = expr_max(code_gen, right);

                        expr_vars.insert(var);

                        (expr_inter, expr_vars)
                    }
                    Expression::Index(base, offset) => {
                        let (base_inter, mut base_vars) = expr_max(code_gen, base);
                        let (offset_inter, offset_vars) = expr_max(code_gen, offset);
                        let (right_inter, right_vars) = expr_max(code_gen, right);

                        base_vars.extend(offset_vars);
                        base_vars.extend(right_vars);

                        (base_inter.max(offset_inter).max(right_inter) + 2, base_vars)
                    }
                    _ => panic!(
                        "Unsupported expression for assignment: {left:?}; only index or variable are supported"
                    ),
                },
            }
        }

        stms.iter().map(|stm| stm_max(self, stm)).fold(
            (0, HashSet::new()),
            |(prev_inter, prev_vars), (next_inter, next_vars)| {
                (
                    prev_inter.max(next_inter),
                    prev_vars.union(&next_vars).copied().collect(),
                )
            },
        )
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
            self.determine_max_intermediate_count_and_variables(&f.body);

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
                Statement::Assignment(left, right) => match &**left {
                    Expression::Ident(name) => {
                        self.generate_expression(right);
                        let offset = self.get_var_offset(name);
                        let _ = write!(
                            self.content,
                            r"
    mov [rbp-{offset}], rax
"
                        );
                    }
                    Expression::Index(base, offset) => {
                        self.generate_expression(base);
                        self.generate_intermediate_save();
                        let base_offset = self.get_intermediate_offset();
                        self.intermediate_counter += 1;
                        self.generate_expression(offset);
                        self.generate_intermediate_save();
                        let offset_offset = self.get_intermediate_offset();
                        self.intermediate_counter += 1;
                        self.generate_expression(right);
                        self.intermediate_counter -= 2;
                        let _ = write!(
                            self.content,
                            r"
    mov rdx, [rbp-{base_offset}]
    mov rsi, [rbp-{offset_offset}]
    mov [rdx + rsi * 8], rax
",
                        );
                    }
                    _ => panic!(
                        "Unsupported expression for assignment: {left:?}; only index or variable are supported"
                    ),
                },
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
                    }

                    self.loop_entries_stack.push(LoopEntry {
                        start: start_label.clone(),
                        end: end_label.clone(),
                    });

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

            Expression::FunctionCall(name, arguments) => {
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
            Expression::Index(left, right) => {
                self.generate_expression(left);
                self.generate_intermediate_save();
                self.intermediate_counter += 1;
                self.generate_expression(right);
                self.intermediate_counter -= 1;
                let offset = self.get_intermediate_offset();
                let _ = write!(
                    self.content,
                    r"
    mov rsi, [rbp-{offset}]
    mov rax, [rsi + rax * 8]
",
                );
            }
            Expression::Ident(name) => {
                if let Some(value) = self.parent.constants.get(*name) {
                    let value = value.clone();
                    let _ = write!(
                        self.content,
                        r"
    mov rax, {value}
"
                    );
                } else {
                    let offset = self.get_var_offset(name);
                    let _ = write!(
                        self.content,
                        r"
    mov rax, [rbp-{offset}]
"
                    );
                }
            }
            Expression::Literal(literal) => {
                let _ = write!(
                    self.content,
                    r"
    mov rax, {literal}
"
                );
            }
            Expression::String(s) => {
                let string = self.parent.get_or_insert_string(s);
                let _ = write!(
                    self.content,
                    r"
    mov rax, intlangstring_{string}
                    ",
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
