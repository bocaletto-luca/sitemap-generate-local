#!/usr/bin/env bash
# gen-sitemap.sh

USER="bocaletto-luca"
TODAY=$(date +%F)
SITEMAP="sitemap.xml"

# header
cat > $SITEMAP <<EOF
<?xml version="1.0" encoding="UTF-8"?>
<urlset xmlns="http://www.sitemaps.org/schemas/sitemap/0.9">
  <url>
    <loc>https://${USER}.github.io/</loc>
    <lastmod>${TODAY}</lastmod>
    <changefreq>daily</changefreq>
    <priority>1.0</priority>
  </url>
EOF

# fetch all repos with Pages enabled
curl -s "https://api.github.com/users/${USER}/repos?per_page=100" \
  | jq -r '.[] | select(.has_pages==true) |
      "  <url>\n    <loc>https://${USER}.github.io/\(.name)/</loc>\n    <lastmod>\(.pushed_at[0:10])</lastmod>\n    <changefreq>monthly</changefreq>\n    <priority>0.8</priority>\n  </url>"' \
  >> $SITEMAP

# footer
echo "</urlset>" >> $SITEMAP

echo "✅ Sitemap aggiornata: $SITEMAP"
