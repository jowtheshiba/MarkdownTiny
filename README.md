# MarkdownTiny

A minimal terminal Markdown viewer built with Swift and SwiftyTermUI.

## Installation

To install `markdowntiny` on macOS or Linux, you can use the following command (ensure `swift` is installed):

```bash
curl -sSL https://raw.githubusercontent.com/jowtheshiba/MarkdownTiny/main/install.sh | bash
```

## Run


```bash
swift run MarkdownTiny test_md_files/overview.md
```

## Keys

| Key           | Action                    |
|---------------|---------------------------|
| `j` / `↓`     | Scroll down               |
| `k` / `↑`     | Scroll up                 |
| `g` / `Home`  | Jump to top               |
| `G` / `End`   | Jump to bottom            |
| `PgUp`/`PgDn` | Page up / down            |
| `Tab`         | Next link (jumps to it)   |
| `Shift+Tab`   | Previous link             |
| `Enter`       | Open selected link        |
| `q` / `Esc`   | Quit                      |

## Features

- Headings, lists (nested), tables, blockquotes, code blocks
- Syntax highlighting in fenced code blocks (via Chroma)
- In-app navigation between local Markdown files

## License

MIT — see [LICENSE](LICENSE).
