set shell := ["bash", "-uc"]

# List available commands
default:
    @just --list

# Install dependencies (ocamlformat, etc.)
install:
    eval $(opam env) && opam install . --deps-only --with-test --with-doc -y

# Build the OCaml project
build:
    eval $(opam env) && dune build

# Run the parser/interpreter on a file
run file:
    eval $(opam env) && dune exec main -- {{file}}

# Run with Church numeral arithmetic (e.g: just calc 2 + 3)
calc +args:
    eval $(opam env) && dune exec main -- {{args}}

# Format OCaml code
format:
    eval $(opam env) && dune build @fmt --auto-promote

# Run all tests
test:
    eval $(opam env) && dune runtest

# Build and run tests
ci: build test

# Clean build artifacts
clean:
    eval $(opam env) && dune clean
