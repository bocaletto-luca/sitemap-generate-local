#!/usr/bin/env bash
set -euo pipefail

USER="bocaletto-luca"
DOMAIN="${USER}.github.io"
BASE="https://${DOMAIN}"
SITEMAP="sitemap.xml"
TMPDIR="tmp_repos"

# 0) Controllo dipendenze
for cmd in git grep sed sort uniq; do
  command -v $cmd >/dev/null 2>&1 || {
    echo "❌ Serve '$cmd' – installalo con 'sudo apt install $cmd' o 'brew install $cmd'"
    exit 1
  }
done

# 1) Estrai SOLO i nomi dei repo da sitemap.xml
#    Matchiamo <loc>https://DOMAIN/REPO/ o /REPO/index.html</loc>
mapfile -t repos < <(
  grep -E "<loc>${BASE}/[A-Za-z0-9._-]+(/|/index.html)" "$SITEMAP" \
    | sed -E "s#.*${BASE}/([^/]+)(/.*)?</loc>#\1#" \
    | sort -u
)

if (( ${#repos[@]} == 0 )); then
  echo "❌ Non ho trovato repository validi in '$SITEMAP'"
  exit 1
fi

# 2) Prepara dir di lavoro
rm -rf "$TMPDIR"
mkdir -p "$TMPDIR"

# 3) Clona e crea index.html dove serve
for r in "${repos[@]}"; do
  echo "→ Clono e controllo '$r'…"
  git clone --depth=1 "https://github.com/${USER}/${r}.git" "$TMPDIR/$r" \
    >/dev/null 2>&1 || {
      echo "   ❌ Clone fallito per '$r', skip."
      continue
    }

  cd "$TMPDIR/$r"

  if [[ ! -f index.html ]]; then
    echo "   📄 Creo index.html in '$r'"

    cat > index.html <<HTML
<!DOCTYPE html>
<html lang="en">
<head>
  <meta charset="UTF-8">
  <title>${r}</title>
</head>
<body>
  <h1>Repository: ${r}</h1>
  <ul>
HTML

    # Lista i file .html presenti (esclude index.html)
    for f in *.html; do
      [[ "$f" == "index.html" ]] && continue
      echo "    <li><a href=\"${f}\">${f}</a></li>" >> index.html
    done

    cat >> index.html <<HTML
  </ul>
</body>
</html>
HTML

    git add index.html
    git commit -m "chore: auto-generate index.html"
    git push origin HEAD >/dev/null 2>&1 \
      && echo "   ✅ index.html creato e pushato" \
      || echo "   ⚠️  push fallito, controlla permessi"
  else
    echo "   ℹ️  index.html già presente, skip."
  fi

  cd - >/dev/null
done

echo "✅ Fatto! index.html elaborati per ${#repos[@]} repo."
