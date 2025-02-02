# Notes

## Basics

### adding theme

```bash
git submodule add <url> themes/<theme name>
```

Then, add `theme = <theme name>' in hugo.toml

### adding content

```bash
hugo new content content/posts/<content-name>.md
```

Add draft = true in content metadata

```bash
hugo server -D
```

Set draft = false after content completion.
