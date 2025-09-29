Test fixtures:
  $ main fixtures/empty.txt
  $ main fixtures/blank_lines.txt
  $ main fixtures/simple_variables.txt
  x
  y
  foo
  bar123
  $ main fixtures/lambda_abstractions.txt
  (\x x)
  (\y y)
  (\foo foo)
  (\x (\y x))
  (\x (\y (\z x)))
  $ main fixtures/applications.txt
  (f x)
  ((f x) y)
  (((f x) y) z)
  ((f x) y)
  (f (g x))
  $ main fixtures/parenthesized.txt
  x
  x
  (f x)
  (\x x)
  y
  $ main fixtures/complex_expressions.txt
  y
  a
  (succ (succ zero))
  z
  (\x ((x y) z))
  $ main fixtures/mixed_valid.txt
  x
  (\x x)
  ((f x) y)
  y
  (\x (\y x))
  $ main fixtures/beta_simple.txt
  (\y y)
  (x y)
  (\x (\y (x (\z y))))
  $ main fixtures/beta_reduction.txt
  (x x)
  $ main fixtures/alpha_conversion.txt
  (\y1 (\z y))
  $ main fixtures/normal_order.txt
  y

Invalid inputs should fail:
  $ main fixtures/invalid_missing_var.txt
  Fatal error: exception Dune__exe__Main.Syntax_error("Missing variable after lambda")
  [2]
  $ main fixtures/invalid_missing_body.txt
  Fatal error: exception Dune__exe__Main.Syntax_error("Missing expression after lambda abstraction")
  [2]
  $ main fixtures/invalid_unclosed_paren.txt
  Fatal error: exception Dune__exe__Main.Syntax_error("Missing closing parenthesis")
  [2]
  $ main fixtures/invalid_unexpected_char.txt
  Fatal error: exception Dune__exe__Main.Syntax_error("Unexpected character: +")
  [2]
  $ main fixtures/invalid_number_start.txt
  Fatal error: exception Dune__exe__Main.Syntax_error("Unexpected character: 1")
  [2]

Omega combinator should hit reduction limit:
  $ main fixtures/omega.txt
  Fatal error: exception Dune__exe__Main.Reduction_limit(1000)
  [2]
