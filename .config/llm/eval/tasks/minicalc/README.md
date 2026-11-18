minicalc: a tiny expression language.

- Numbers, `+ - * /`, `^` (power, right-associative), unary minus, parentheses.
- `/` is true division (`7/2` is 3.5); dividing by zero raises `EvalError`.
- Unary minus binds looser than `^` (`-2^2` is -4) and tighter than `*`.
- Comparisons `== != < > <= >=` return 1 or 0.
- `let x = expr`, `fn name(a, b) = expr`, `if c then a else b`, statements separated by `;`.
- Functions use lexical scope: a function sees the variables of the scope where it was
  defined, not of the caller. Recursion works.
