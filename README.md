# personal-page

## TODO
- [x]  basic site
- [x]  cloudflare pages deployment
- [ ]  Update about and now
- [ ]  Touch ups
- [ ]  github workflow
- [ ]  cloudflare caching
- [ ]  google analytics

## Hugo instructions
1. For adding new content.
```bash
hugo new content [path] [flags]
```
2. For building site.
```bash
hugo
```
3. For serving in local
```bash
hugo server -D # For drafts
hugo server -t <theme>
```
4. After cloning repo, themes submodules need to reinstalled.
```bash
git submodule init
git submodule update
```
