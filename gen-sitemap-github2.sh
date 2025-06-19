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
for cmd in curl wget awk grep sed sort uniq; do
  command -v $cmd &>/dev/null || {
    echo "❌ Mancante '$cmd' – installa con 'sudo apt install $cmd' o 'brew install $cmd'"
    exit 1
  }
done

# 1) RACCOLTA DEI REPO DAL PROFILO (HTML PAGINATO)
echo "1) Recupero lista repo da GitHub (via HTML)…"
repos=()
page=1
while true; do
  url="https://github.com/${USER}?tab=repositories&page=${page}"
  echo "   → Pagina $page"
  html=$(curl -s "$url")
  # Estrai solo href="/USER/REPO"
  page_repos=$(printf "%s" "$html" \
    | grep -Eo 'href="/'"$USER"'/[A-Za-z0-9._-]+' \
    | sed -E 's#.*/##' \
    | sort -u)

  [[ -z "$page_repos" ]] && break
  repos+=( $page_repos )
  ((page++))
done
# De-duplica
repos=( $(printf "%s\n" "${repos[@]}" | sort -u) )
echo "→ Trovati ${#repos[@]} repo"

# 2) FILTRA SOLO QUELLI CON GITHUB PAGES ATTIVO
echo "2) Controllo quali hanno Pages attivo…"
pages_repos=()
for repo in "${repos[@]}"; do
  test_url="${BASE_URL}/${repo}/"
  code=$(curl -s -o /dev/null -w "%{http_code}" "$test_url")
  if [[ "$code" == "200" ]]; then
    pages_repos+=( "$repo" )
  else
    echo "   • $repo → HTTP $code (skip)"
  fi
done
echo "→ ${#pages_repos[@]} repo Pages-enabled"

# 3) SPIDERING STATICO DEL SITO COMPLETO
echo "3) Spidering di root + ogni repo Pages…"
rm -f "$SPIDER_LOG"

# spider root
wget --spider --recursive --no-parent --domains="$DOMAIN" \
     --accept html,htm --output-file="$SPIDER_LOG" "$BASE_URL/"

# spider di ciascun repo
for repo in "${pages_repos[@]}"; do
  wget --spider --recursive --no-parent --domains="$DOMAIN" \
       --accept html,htm --append-output="$SPIDER_LOG" \
       "${BASE_URL}/${repo}/"
done

# 4) ESTRAZIONE E NORMALIZZAZIONE URL UNICI
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
  echo "Nessun URL estratto: controlla $SPIDER_LOG"
  exit 1
fi

# 5) GENERA sitemap.xml
echo "5) Generazione $SITEMAP…"
{
  echo '<?xml version="1.0" encoding="UTF-8"?>'
  echo '<urlset xmlns="http://www.sitemaps.org/schemas/sitemap/0.9">'
  # root
  echo "  <url>"
  echo "    <loc>${BASE_URL}/</loc>"
  echo "    <lastmod>${TODAY}</lastmod>"
  echo "    <changefreq>daily</changefreq>"
  echo "    <priority>1.0</priority>"
  echo "  </url>"
  # ogni URL spiderizzato
  for url in "${URLS[@]}"; do
    # se manca estensione finale, assicura lo slash
    if [[ ! "$url" =~ \.[a-zA-Z0-9]+$ ]]; then
      url="${url%/}/"
    fi
    echo "  <url>"
    echo "    <loc>${url}</loc>"
    echo "    <lastmod>${TODAY}</lastmod>"
    echo "    <changefreq>monthly</changefreq>"
    echo "    <priority>0.6</priority>"
    echo "  </url>"
  done
  echo '</urlset>'
} > "$SITEMAP"

echo "Sitemap generata in '$SITEMAP' con ${#URLS[@]} URL"
echo "Log spider in '$SPIDER_LOG'"
echo "Aggiungi in robots.txt: Sitemap: ${BASE_URL}/${SITEMAP}"
