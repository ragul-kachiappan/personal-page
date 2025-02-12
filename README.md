# personal-page

Theme used: [papermod](https://github.com/adityatelange/hugo-PaperMod)

## TODO

- [x]  basic site
- [x]  cloudflare pages deployment
- [x]  Update about and now
- [x]  Touch ups
- [x]  github workflow
- [x]  cloudflare caching
- [ ]  google analytics

## Hugo instructions

### adding theme

```bash
git submodule add <url> themes/<theme name>
```

Then, add `theme = <theme name>' in hugo.toml

### For adding new content.

```bash
hugo new content [path] [flags]
```

Set draft = false after content completion.

### For building site.

```bash
hugo
```

### For serving in local

```bash
hugo server -D # For drafts
hugo server -t <theme>
```

### After cloning repo, themes submodules need to reinstalled.

```bash
git submodule init
git submodule update
```

### Add a cover

In the front matter. Add the below

```yaml
cover:
  image: <path to image in static dir>
  alt: 'alt to image'
  caption: 'caption for the image'
```
