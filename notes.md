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

### Add a cover

In the front matter. Add the below

```yaml
cover:
  image: <path to image in static dir>
  alt: 'alt to image'
  caption: 'caption for the image'
```
