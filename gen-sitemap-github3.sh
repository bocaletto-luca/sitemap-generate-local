#!/usr/bin/env bash
set -euo pipefail

# — CONFIGURAZIONE —
USER="bocaletto-luca"
DOMAIN="${USER}.github.io"
BASE_URL="https://${DOMAIN}"
TODAY=$(date +%F)
SITEMAP="sitemap.xml"
SPIDER_LOG="spider.log"

# — CONTROLLA LE DIPENDENZE —
for cmd in curl wget grep awk sed sort uniq; do
  command -v "$cmd" >/dev/null 2>&1 || {
    echo "❌ '$cmd' non trovato. Installa con 'sudo apt install $cmd' o 'brew install $cmd'"
    exit 1
  }
done

# 1) RACCOLTA DI TUTTI I REPO (HTML-SCRAPING PAGINATO)
echo "1) Recupero lista di tutti i repo GitHub…"
repos=()
page=1
while :; do
  echo "   → Pagina $page"
  html=$(curl -s "https://github.com/${USER}?tab=repositories&page=${page}")
  names=( $(
    printf "%s" "$html" \
    | grep -oE "href=\"/${USER}/[A-Za-z0-9._-]+\"" \
    | sed -E "s#href=\"/${USER}/([^\"]+)\"#\1#"
  ) )
  (( ${#names[@]} == 0 )) && break
  repos+=( "${names[@]}" )
  ((page++))
  ((page>50)) && break  # sicurezza
done
# de-duplica
repos=( $(printf "%s\n" "${repos[@]}" | sort -u) )
echo "→ trovati ${#repos[@]} repo pubblici"

[[ ${#repos[@]} -eq 0 ]] && { echo "❌ Nessun repo trovato"; exit 1; }

# 2) FILTRO SOLO QUELLI CON PAGES ATTIVO
echo "2) Verifico quali hanno GitHub Pages attivo…"
pages_repos=()
for repo in "${repos[@]}"; do
  url="${BASE_URL}/${repo}/"
  code=$(curl -s -o /dev/null -w "%{http_code}" "$url")
  if [[ "$code" == "200" ]]; then
    pages_repos+=( "$repo" )
    echo "   • $repo (OK)"
  else
    echo "   • $repo (HTTP $code → skip)"
  fi
done
echo "→ ${#pages_repos[@]} repo Pages-enabled"

[[ ${#pages_repos[@]} -eq 0 ]] && { echo "❌ Nessun Pages-enabled"; exit 1; }

# 3) SPIDERING STATICO (solo --spider, zero download)
echo "3) Spidering di root + repo Pages…"
rm -f "$SPIDER_LOG"

# root
wget --spider --recursive --no-parent --domains="$DOMAIN" \
     --accept html,htm -o "$SPIDER_LOG" "${BASE_URL}/"

# ciascun repo
for repo in "${pages_repos[@]}"; do
  echo "   • ${BASE_URL}/${repo}/"
  wget --spider --recursive --no-parent --domains="$DOMAIN" \
       --accept html,htm -a "$SPIDER_LOG" "${BASE_URL}/${repo}/"
done

# 4) ESTRAZIONE URL UNICI
echo "4) Estrazione URL unici dal log…"
mapfile -t URLS < <(
  grep '^--' "$SPIDER_LOG" \
    | awk '{print $3}' \
    | sed 's/[?#].*$//' \
    | sort -u
)
echo "→ ${#URLS[@]} URL trovati"

[[ ${#URLS[@]} -eq 0 ]] && { echo "❌ Nessun URL in $SPIDER_LOG"; exit 1; }

# 5) GENERAZIONE sitemap.xml
echo "5) Generazione $SITEMAP…"
{
  echo '<?xml version="1.0" encoding="UTF-8"?>'
  echo '<urlset xmlns="http://www.sitemaps.org/schemas/sitemap/0.9">'
  # entry root
  echo "  <url>"
  echo "    <loc>${BASE_URL}/</loc>"
  echo "    <lastmod>${TODAY}</lastmod>"
  echo "    <changefreq>daily</changefreq>"
  echo "    <priority>1.0</priority>"
  echo "  </url>"
  # entry per ogni URL trovato
  for u in "${URLS[@]}"; do
    # skip doppio root
    [[ "$u" == "${BASE_URL}/" ]] && continue
    # assicura slash su URL “directory”
    if [[ ! "$u" =~ \.[A-Za-z0-9]+$ ]]; then
      u="${u%/}/"
    fi
    echo "  <url>"
    echo "    <loc>${u}</loc>"
    echo "    <lastmod>${TODAY}</lastmod>"
    echo "    <changefreq>monthly</changefreq>"
    echo "    <priority>0.6</priority>"
    echo "  </url>"
  done
  echo '</urlset>'
} > "$SITEMAP"

echo "✅ sitemap.xml generata con ${#URLS[@]} pagine"
echo "ℹ️  vedi dettagli spider in $SPIDER_LOG"
echo "ℹ️  aggiungi in robots.txt:  Sitemap: ${BASE_URL}/${SITEMAP}"
