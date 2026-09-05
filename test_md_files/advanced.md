[← Back to Overview](overview.md)

# MarkdownTiny Demo — Advanced

More lists, tables, and code snippets to exercise the viewer.

## Nested Lists

- Fruits
  - Apple
  - Banana
    - Cavendish
    - Plantain
  - Cherry
- Vegetables
  - Carrot
  - Broccoli

1. Setup
   - Install Swift toolchain
   - Clone the repository
2. Build
   - Run `swift build`
   - Run `swift run MarkdownTiny overview.md`
3. Read
   - Press `Tab` to jump between links
   - Press `Enter` to open the selected link
   - Press `q` to quit

## Table

| Language   | Type     | Year |
|------------|----------|------|
| Swift      | Compiled | 2014 |
| Python     | Dynamic  | 1991 |
| JavaScript | Dynamic  | 1995 |
| Bash       | Script   | 1989 |

## Code

```bash
#!/usr/bin/env bash
# Build and open the overview file
set -euo pipefail
swift build
.build/debug/MarkdownTiny test_md_files/overview.md
```

```javascript
// Sum an array of numbers
function sum(values) {
  let total = 0;
  for (const v of values) {
    total += v;
  }
  return total;
}

console.log(sum([1, 2, 3]));
```

[← Back to Overview](overview.md)
