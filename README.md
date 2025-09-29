<!-- github markdown trick -->
> [!CAUTION]
> ## Academic Integrity Notice
>
> This project is part of an academic assignment. If you are a student:
> - You **must** implement the core emulator logic yourself
> - Using this repository's tooling/infrastructure is allowed
> - Copying implementation code from others violates academic integrity policies

# λ-Calculus Parser and Interpreter

A lexer, parser, and interpreter for lambda calculus expressions with β-reduction and α-conversion, created for the CoPL (Concepts of Programming Languages) course at Leiden University.


## Project Structure

```
.
├── src/                     # OCaml source code
│   ├── main.ml              # Lambda calculus lexer, parser, and interpreter
│   ├── dune                 # Build configuration
│   └── .ocamlformat
├── tests/                   # OCaml test suite
│   ├── fixtures/            # Test input files (18 fixtures)
│   ├── dune                 # Test configuration
│   └── parser.t             # Cram tests
├── justfile                 # Task runner commands
├── dune-project             # Dune project configuration
├── main.opam                # OCaml package dependencies
├── .gitignore
└── README.md
```

## Prerequisites

- **opam** - OCaml package manager
- **just** - Command runner

All other dependencies (dune, ocamlformat, etc.) are installed via `just install`.

## Quick Start

### 1. Install System Tools

```bash
# Install opam (OCaml package manager)
sudo apt-get update && sudo apt-get install -y opam
opam init --disable-sandboxing -y

# Install just (task runner)
curl --proto '=https' --tlsv1.2 -sSf https://just.systems/install.sh | bash -s -- --to ~/bin
export PATH="$HOME/bin:$PATH"
```

### 2. Install Project Dependencies

```bash
# Install all dependencies
just install
```

### 3. Build the Project

```bash
just build
```

### 4. Run the Interpreter

```bash
# Interpret expressions from a file
just run tests/fixtures/simple_variables.txt

# Test beta-reduction
echo "(\x x)(\y y)" > my_input.txt
just run my_input.txt  # Output: (\y y)

# Church numeral arithmetic (optional feature)
just calc 2 + 3   # Outputs Church numeral for 5
just calc 3 "*" 4  # Outputs Church numeral for 12
just calc 5 - 2   # Outputs Church numeral for 3 (monus)
```

## Commands

All commands are managed via `just`:

### Build

```bash
# Build the OCaml project
just build
```

### Run

```bash
# Run the interpreter on a file
just run <input-file>

# Examples - File mode
just run tests/fixtures/simple_variables.txt
just run tests/fixtures/beta_simple.txt

# Examples - Church numeral arithmetic
just calc 2 + 3
just calc 4 "*" 5
just calc 7 - 2
```

### Test

```bash
# Run all tests
just test

# See all available commands
just --list
```

### Format

```bash
# Format OCaml code
just format
```

### CI

```bash
# Run build and test (used in CI)
just ci
```

### Clean

```bash
# Clean build artifacts
just clean
```

## Interpreter Implementation

### Evaluation Strategy

The interpreter uses **Normal Order (leftmost-outermost) evaluation strategy**:
- Reduces the leftmost-outermost redex first
- Guarantees finding normal form if it exists
- Example: `(λx.y)((λx.(x x))(λx.(x x)))` correctly reduces to `y` instead of diverging

### Reduction Features

**β-Reduction**: Applies function arguments to their bodies
- `(λx.x)(λy.y)` → `λy.y`
- `((λx.x) x)((λx.x) x)` → `(x x)`

**α-Conversion**: Automatic variable renaming to avoid capture
- `(λx.λy.x)(λz.y)` → `(λy0.(λz.y))` (renames `y` to avoid capture)

**Step Limit**: Maximum **1000 reduction steps**
- Prevents infinite loops on non-terminating expressions
- Raises `Reduction_limit` exception when limit is reached
- Example: `(λx.(x x))(λx.(x x))` (omega combinator) hits limit

### Church Numerals (Optional Feature)

Supports Church numeral arithmetic via command line:
- **Addition**: `just calc 2 + 3` → Church numeral for 5
- **Multiplication**: `just calc 3 "*" 4` → Church numeral for 12
- **Monus (truncated subtraction)**: `just calc 5 - 2` → Church numeral for 3

Church numeral encoding: `n = λf.λx.f(f(...f(x)...))` (n applications of f)

## Lambda Calculus Syntax

The interpreter supports the following syntax:

- **Variables**: `x`, `y`, `foo`, `bar123` (letter followed by alphanumerics)
- **Lambda abstraction**: `\x body` (represents λx.body)
- **Application**: `f x` (function application, left-associative)
- **Parentheses**: `(expr)` for grouping

### Examples (with β-reduction)

```
x                  → x                    # No reduction needed
\x x               → (\x x)               # Identity function (irreducible)
(\x x) y           → y                    # Identity applied: reduces to y
\x \y x            → (\x (\y x))          # Constant function (irreducible)
f x y              → ((f x) y)            # Application (irreducible without definition)
(\x x)(\y y)       → (\y y)               # Identity applied to identity
\f \x f (f x)      → (\f (\x (f (f x)))) # Church numeral 2 (irreducible)
```

## Testing

The project includes comprehensive test coverage with **18 test fixtures** organized into categories:

### Test Fixtures

The `tests/fixtures/` directory contains:

**Parser fixtures:**
- `empty.txt` - Empty file
- `blank_lines.txt` - Only whitespace
- `simple_variables.txt` - Basic variable names
- `lambda_abstractions.txt` - Various lambda abstractions
- `applications.txt` - Function applications
- `complex_expressions.txt` - Advanced expressions
- `parenthesized.txt` - Parenthesized expressions
- `mixed_valid.txt` - Valid with blank lines

**Interpreter fixtures:**
- `beta_simple.txt` - Simple β-reductions
- `beta_reduction.txt` - Complex β-reductions
- `alpha_conversion.txt` - Variable capture cases
- `normal_order.txt` - Normal order evaluation test
- `omega.txt` - Non-terminating omega combinator

**Invalid inputs:**
- `invalid_missing_var.txt` - Lambda without variable
- `invalid_missing_body.txt` - Lambda without body
- `invalid_unclosed_paren.txt` - Unclosed parenthesis
- `invalid_unexpected_char.txt` - Invalid character (+)
- `invalid_number_start.txt` - Identifier starting with number

## Development Workflow

### Make Changes to OCaml Code

1. Edit `src/main.ml`
2. Format: `just format`
3. Build: `just build`
4. Test: `just test`

### Add New Tests

1. Add fixture file to `tests/fixtures/`
2. Add test case to `tests/parser.t` (cram test format)
3. Run tests: `just test`

### Direct OCaml Commands

If you prefer to use OCaml tools directly:

```bash
eval $(opam env)

# Build
dune build

# Run
dune exec main -- tests/fixtures/simple_variables.txt

# Test
dune runtest

# Format
dune build @fmt --auto-promote
```

## Troubleshooting

### `opam: command not found`

Install opam: `sudo apt-get install -y opam`

### `dune: command not found`

Source opam environment: `eval $(opam env)`

### `just: command not found`

Install just: `curl --proto '=https' --tlsv1.2 -sSf https://just.systems/install.sh | bash -s -- --to ~/bin`

Then add to PATH: `export PATH="$HOME/bin:$PATH"`

## License

MIT License - see [LICENSE](LICENSE) file for details.

## Acknowledgments

Created for the Concepts of Programming Languages course at Leiden University.

## Resources

- [OCaml Manual](https://ocaml.org/manual/)
- [Dune Documentation](https://dune.build/)
- [just Documentation](https://just.systems/)
- [Lambda Calculus (Wikipedia)](https://en.wikipedia.org/wiki/Lambda_calculus)
