Add two options to `inventory report`:

- `--format {text,json}` (default `text`). JSON prints the summary as an object with
  `total_value`, `categories` (keys sorted, values rounded to 2 decimals) and `low_stock`.
- `--category NAME` limits the report to one category. An unknown category prints
  `unknown category: NAME` to stderr and returns exit code 2.
