# MarkdownTiny Demo — Overview

Welcome to the **MarkdownTiny** demo. This file shows plain text, lists,
tables, and code blocks. Continue with [Advanced Examples](advanced.md).

## Text

MarkdownTiny renders *italic*, **bold**, and `inline code`. It also
supports [external links](https://example.com) opened in your browser.

> Blockquotes are rendered with a subtle sidebar.
> — The Viewer

---

## Lists

1. First ordered item
   - Nested bullet one
   - Nested bullet two
     - Deeper nested bullet
   - Back to the nested level
2. Second ordered item
3. Third ordered item

- Top-level bullet
  - Nested bullet
  - Another nested bullet
- One more top-level bullet

## Table

| Command   | Action          | Key     |
|-----------|-----------------|---------|
| Save file | Write to disk   | `Ctrl+S` |
| Quit      | Exit the viewer | `q`     |
| Search    | Find in file    | `/`     |

## Code

```swift
import Foundation

// Greet by name
func greet(_ name: String) -> String {
    let count = 1 + 2
    return "Hello, \(name) #\(count)"
}

print(greet("Ada"))
```

```python
# Factorial, iterative
def factorial(n: int) -> int:
    result = 1
    for i in range(2, n + 1):
        result *= i
    return result

print(f"5! = {factorial(5)}")
```

Next: [Advanced Examples](advanced.md).
