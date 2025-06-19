#!/usr/bin/env bash
set -euo pipefail

#### CONFIGURA QUI ####
USER="bocaletto-luca"
BASE_URL="https://${USER}.github.io"
TODAY=$(date +%F)
SITEMAP="sitemap.xml"

#### CONTROLLA DIPENDENZE ####
for cmd in curl jq; do
  command -v $cmd >/dev/null 2>&1 || {
    echo "❌ '$cmd' non trovato. Installa con 'sudo apt install $cmd' o 'brew install $cmd'"
    exit 1
  }
done

#### FUNZIONI DI SUPPORTO ####
# Fetch JSON, esce se HTTP≠200
fetch_json() {
  local url=$1
  local resp=$(curl -sSL -w "\n%{http_code}" "$url")
  local code=${resp##*$'\n'}
  local body=${resp%$'\n'*}
  if [[ "$code" != "200" ]]; then
    echo "❌ Errore $code durante il fetch di $url" >&2
    exit 1
  fi
  printf "%s" "$body"
}

#### 1) RACCOGLI REPO CON Pages abilitato (API paginata) ####
echo "1) Recupero repo GitHub con Pages abilitato…"
repos=()
page=1
while :; do
  echo "   → pagina $page"
  url="https://api.github.com/users/${USER}/repos?per_page=100&page=${page}"
  json=$(fetch_json "$url")
  # estrai solo quelli has_pages==true
  names=( $(jq -r '.[] | select(.has_pages==true) | .name' <<<"$json") )
  (( ${#names[@]} == 0 )) && break
  repos+=( "${names[@]}" )
  ((page++))
done
# de‐duplica (giusto in caso)
repos=( $(printf "%s\n" "${repos[@]}" | sort -u) )
echo "→ trovati ${#repos[@]} repo Pages-enabled"
(( ${#repos[@]} == 0 )) && { echo "❌ Nessun repo con Pages"; exit 1; }

#### 2) INIZIO sitemap.xml ####
cat > "$SITEMAP" <<EOF
<?xml version="1.0" encoding="UTF-8"?>
<urlset xmlns="http://www.sitemaps.org/schemas/sitemap/0.9">
  <!-- root -->
  <url>
    <loc>${BASE_URL}/</loc>
    <lastmod>${TODAY}</lastmod>
    <changefreq>daily</changefreq>
    <priority>1.0</priority>
  </url>
EOF

#### 3) PER OGNI REPO, PRIMA RICAVA BRANCH DI DEFAULT POI TREE ####
for repo in "${repos[@]}"; do
  echo "2) Elaboro ${repo}…"
  # 2.1 default branch
  repo_api="https://api.github.com/repos/${USER}/${repo}"
  default_branch=$(fetch_json "$repo_api" | jq -r '.default_branch')
  # 2.2 tree ricorsivo
  tree_api="${repo_api}/git/trees/${default_branch}?recursive=1"
  tree_json=$(fetch_json "$tree_api")

  # 2.3 estrae tutti i blob .html/.htm
  paths=( $(
    jq -r '.tree[] |
           select(.type=="blob") |
           select(.path|test("\\.(html?|htm)$")) |
           .path' <<<"$tree_json"
  ) )

  for p in "${paths[@]}"; do
    url="${BASE_URL}/${repo}/${p}"
    cat >> "$SITEMAP" <<EOF
  <url>
    <loc>${url}</loc>
    <lastmod>${TODAY}</lastmod>
    <changefreq>monthly</changefreq>
    <priority>0.6</priority>
  </url>
EOF
  done
done

#### 4) CHIUDI E INFO ####
echo "</urlset>" >> "$SITEMAP"
echo "✅ Generata sitemap in '$SITEMAP' con root + ${#repos[@]} repo."
echo "   Apri $SITEMAP per verificare le URL."
