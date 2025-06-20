#!/usr/bin/env bash
set -euo pipefail

USER="bocaletto-luca"
TMPDIR="tmp_repos"
SITEMAP="sitemap.xml"

# 1) Estrai i nomi dei repo da sitemap.xml
#    Prende ogni riga <loc>…/REPO/…</loc> e isola la parte “REPO”
mapfile -t repos < <(
  grep '<loc>' "$SITEMAP" \
    | sed -n 's#.*https\?://[^/]\+/\([^/]\+\)/.*#\1#p' \
    | sort -u
)

if (( ${#repos[@]} == 0 )); then
  echo "❌ Nessun repo trovato in $SITEMAP"
  exit 1
fi

# 2) Prepara la directory di lavoro
rm -rf "$TMPDIR"
mkdir -p "$TMPDIR"

# 3) Per ciascun repo
for r in "${repos[@]}"; do
  echo "→ Clono e controllo $r"
  git clone --depth=1 "https://github.com/${USER}/${r}.git" "$TMPDIR/$r" \
    || { echo "   ❌ Clone fallito per $r"; continue; }

  cd "$TMPDIR/$r"

  # 3.1 Se manca index.html, lo creiamo
  if [[ ! -f index.html ]]; then
    echo "   📄 Creo index.html in $r"

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

    # Lista eventuali altri .html nella radice
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
    git push origin HEAD

  else
    echo "   ℹ️ index.html già presente, skip."
  fi

  cd - >/dev/null
done

echo "✅ Fatto! index.html aggiunti/pushati per ${#repos[@]} repo (se mancanti)."
