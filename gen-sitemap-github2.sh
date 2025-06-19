#!/usr/bin/env bash
set -euo pipefail

# — CONFIGURAZIONE —
USER="bocaletto-luca"
DOMAIN="${USER}.github.io"
BASE_URL="https://${DOMAIN}"
TODAY=$(date +%F)
SITEMAP="sitemap.xml"
SPIDER_LOG="spider.log"

# — CONTROLLA DIPENDENZE —
for cmd in curl wget awk grep sed sort; do
  command -v $cmd >/dev/null 2>&1 || {
    echo "❌ '$cmd' non trovato. Installa con 'sudo apt install $cmd' o 'brew install $cmd'"
    exit 1
  }
done

# 1) RACCOGLI REPO DAL PROFILO GITHUB (HTML PAGINATO)
echo "1) Recupero lista repo da GitHub…"
repos=()
page=1
while :; do
  html=$(curl -s "https://github.com/${USER}?page=${page}&tab=repositories")
  # Estrai solo i link ai repo vero/funzionante
  names=$(echo "$html" \
    | grep 'itemprop="name codeRepository"' \
    | sed -n 's/.*href="\/'"$USER"'\/\([^"]*\)".*/\1/p')
  [[ -z "$names" ]] && break
  repos+=( $names )
  ((page++))
done
# de-dupe
repos=( $(printf "%s\n" "${repos[@]}" | sort -u) )
echo "→ trovati ${#repos[@]} repo"

# 2) FILTRA SOLO QUELLI CON PAGES ATTIVO
echo "2) Controllo quali repo hanno GitHub Pages attivo…"
pages_repos=()
for repo in "${repos[@]}"; do
  url="${BASE_URL}/${repo}/"
  code=$(curl -s -o /dev/null -w "%{http_code}" "$url")
  if [[ "$code" == "200" ]]; then
    pages_repos+=( "$repo" )
  else
    echo "   – $repo → HTTP $code (skip)"
  fi
done
echo "→ ${#pages_repos[@]} repo con Pages attivo"

# 3) SPIDERING STATICO: root + ogni repo Pages
echo "3) Spidering di tutte le pagine…"
rm -f "$SPIDER_LOG"
# spider root
wget --spider --recursive --no-parent --domains="$DOMAIN" --accept html,htm \
     --output-file="$SPIDER_LOG" "$BASE_URL/"

# spider di ciascun repo
for repo in "${pages_repos[@]}"; do
  wget --spider --recursive --no-parent --domains="$DOMAIN" --accept html,htm \
       --append-output="$SPIDER_LOG" "${BASE_URL}/${repo}/"
done

# 4) ESTRAI E NORMALIZZA GLI URL
echo "4) Estrazione URL unici dal log…"
mapfile -t URLS < <(
  grep '^--' "$SPIDER_LOG" \
    | awk '{print $3}' \
    | grep "^${BASE_URL}" \
    | sed -E 's/[?#].*$//' \
    | sort -u
)
echo "→ ${#URLS[@]} URL trovati"

if (( ${#URLS[@]} == 0 )); then
  echo "⚠️  Nessun URL estratto! Controlla $SPIDER_LOG"
  exit 1
fi

# 5) COSTRUISCI sitemap.xml
echo "5) Generazione $SITEMAP…"
cat > "$SITEMAP" <<EOF
<?xml version="1.0" encoding="UTF-8"?>
<urlset xmlns="http://www.sitemaps.org/schemas/sitemap/0.9">
  <!-- root del GitHub Pages -->
  <url>
    <loc>${BASE_URL}/</loc>
    <lastmod>${TODAY}</lastmod>
    <changefreq>daily</changefreq>
    <priority>1.0</priority>
  </url>
EOF

count=0
for url in "${URLS[@]}"; do
  # se non termina con estensione, aggiungi slash
  if [[ ! "$url" =~ \.[a-zA-Z0-9]+$ ]]; then
    url="${url%/}/"
  fi
  cat >> "$SITEMAP" <<EOF
  <url>
    <loc>${url}</loc>
    <lastmod>${TODAY}</lastmod>
    <changefreq>monthly</changefreq>
    <priority>0.6</priority>
  </url>
EOF
  ((count++))
done

echo "</urlset>" >> "$SITEMAP"
echo "✅ Creato $SITEMAP con $count URL"
echo "ℹ️  Dettagli spider in $SPIDER_LOG"
echo "ℹ️  Aggiungi su robots.txt:  Sitemap: ${BASE_URL}/${SITEMAP}"
