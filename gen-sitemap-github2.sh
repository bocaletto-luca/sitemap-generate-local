#!/usr/bin/env bash
set -euo pipefail

#### CONFIGURAZIONE ####
USER="bocaletto-luca"
DOMAIN="${USER}.github.io"
BASE_URL="https://${DOMAIN}"
TODAY=$(date +%F)
SITEMAP="sitemap.xml"
SPIDER_LOG="spider.log"

#### CONTROLLA LE DIPENDENZE ####
for cmd in curl jq wget awk grep sed sort; do
  command -v $cmd >/dev/null 2>&1 || {
    echo "❌ Installa '$cmd' (sudo apt install $cmd o brew install $cmd)"
    exit 1
  }
done

######################################
# 1) RACCOLTA DEI REPO (API PAGINATE) #
######################################
echo "1) Recupero lista di tutti i repo GitHub…"
pages_repos=()
page=1

while :; do
  echo "   → pagina $page"
  resp=$(curl -s "https://api.github.com/users/${USER}/repos?per_page=100&page=${page}")
  # Estrai solo i nomi dei repo Pages-enabled
  names=$(jq -r '.[] | select(.has_pages==true) | .name' <<<"$resp")
  [[ -z "$names" ]] && break
  pages_repos+=( $names )
  ((page++))
done

# De-duplica (anche se in realtà l’API non ripete)
pages_repos=( $(printf "%s\n" "${pages_repos[@]}" | sort -u) )
echo "→ trovati ${#pages_repos[@]} repo con GitHub Pages attivo"

if [[ ${#pages_repos[@]} -eq 0 ]]; then
  echo "⚠️  Non ho trovato alcun repo con Pages abilitato!"
  exit 1
fi

####################################
# 2) SPIDERING STATICO DI TUTTI i SITI #
####################################
echo "2) Spidering di root + tutti i repo Pages…"
rm -f "$SPIDER_LOG"

# spiderizza la root
wget --spider --recursive --no-parent --domains="$DOMAIN" \
     --accept html,htm --output-file="$SPIDER_LOG" "$BASE_URL/"

# spiderizza ciascun repo Pages
for repo in "${pages_repos[@]}"; do
  url="${BASE_URL}/${repo}/"
  echo "   • ${url}"
  wget --spider --recursive --no-parent --domains="$DOMAIN" \
       --accept html,htm --append-output="$SPIDER_LOG" "$url"
done

##################################################
# 3) ESTRAZIONE e NORMALIZZAZIONE DEGLI URL UNICI #
##################################################
echo "3) Estrazione URL unici dal log…"
mapfile -t URLS < <(
  grep '^--' "$SPIDER_LOG" \
    | awk '{print $3}' \
    | grep "^${BASE_URL}" \
    | sed -E 's/[?#].*$//' \
    | sort -u
)

echo "→ ${#URLS[@]} URL trovati"

if (( ${#URLS[@]} == 0 )); then
  echo "⚠️  Errore: nessun URL estratto. Controlla $SPIDER_LOG"
  exit 1
fi

###################################
# 4) GENERAZIONE sitemap.xml      #
###################################
echo "4) Generazione $SITEMAP…"
{
  echo '<?xml version="1.0" encoding="UTF-8"?>'
  echo '<urlset xmlns="http://www.sitemaps.org/schemas/sitemap/0.9">'
  # root del tuo sito Pages
  echo "  <url>"
  echo "    <loc>${BASE_URL}/</loc>"
  echo "    <lastmod>${TODAY}</lastmod>"
  echo "    <changefreq>daily</changefreq>"
  echo "    <priority>1.0</priority>"
  echo "  </url>"

  # ogni URL spiderizzato
  for u in "${URLS[@]}"; do
    # se manca estensione file, assicura lo slash finale
    if [[ ! "$u" =~ \.[a-zA-Z0-9]+$ ]]; then
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

echo "✅ Sitemap creata in '$SITEMAP' con ${#URLS[@]} URL"
echo "ℹ️  Log spidering: $SPIDER_LOG"
echo "ℹ️  Ricorda in robots.txt: Sitemap: ${BASE_URL}/${SITEMAP}"
