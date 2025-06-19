# sitemap auto generator github
#### Author: Bocaletto Luca
A small toolkit for regenerating `sitemap.xml` for your GitHub Pages portfolio. This repo provides three interchangeable methods—pick the one that fits your workflow best:

1. **Local Bash script** (`gen-sitemap.sh`)  
2. **Local Node.js script** (`generate-sitemap.js`)  
3. **GitHub Actions workflow** (`.github/workflows/generate-sitemap.yml`)

---

## 1) Local Bash Script

**Prerequisites**  
- `bash` (Linux/macOS)  
- `curl`  
- `jq` (JSON processor)

**Setup & Usage**  
1. Copy `gen-sitemap.sh` into your repo root.  
2. Make it executable:  
   ```bash
   chmod +x gen-sitemap.sh
   ```
3. Run to build/overwrite `sitemap.xml`:  
   ```bash
   ./gen-sitemap.sh
   ```
4. Commit & push the updated sitemap:  
   ```bash
   git add sitemap.xml
   git commit -m "chore: update sitemap"
   git push
   ```

---

## 2) Local Node.js Script

**Prerequisites**  
- [Node.js](https://nodejs.org/) v12+

**Setup & Usage**  
1. Copy `generate-sitemap.js` into your repo root.  
2. Install no dependencies—Node’s built-in `https` module is all you need.  
3. Run to regenerate `sitemap.xml`:  
   ```bash
   node generate-sitemap.js
   ```
4. Commit & push:  
   ```bash
   git add sitemap.xml
   git commit -m "chore: update sitemap"
   git push
   ```

---

## 3) GitHub Actions Workflow

**Prerequisites**  
- Your repo published via GitHub Pages  
- (Optional) a `robots.txt` in your root

**Setup**  
1. Copy `.github/workflows/generate-sitemap.yml` into your repo.  
2. Ensure your default branch is `main` (or adjust the workflow).  
3. Commit & push the workflow file.

**Triggering**  
- On every push to `main`, or  
- Manually via **Actions → Generate sitemap → Run workflow**

The job will:
1. Checkout your code  
2. Install `jq`  
3. Query GitHub API for all Pages-enabled repos  
4. Build a fresh `sitemap.xml`  
5. Commit & push the result back to `main`

---

## License

GPL v3 © bocaletto-luca  

---
