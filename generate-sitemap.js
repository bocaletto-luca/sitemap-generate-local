// generate-sitemap.js
const fs = require('fs');
const https = require('https');

const USER = 'bocaletto-luca';
const TODAY = new Date().toISOString().slice(0, 10);

const options = {
  hostname: 'api.github.com',
  path: `/users/${USER}/repos?per_page=100`,
  headers: { 'User-Agent': 'node.js' }
};

https.get(options, res => {
  let body = '';
  res.on('data', chunk => body += chunk);
  res.on('end', () => {
    const repos = JSON.parse(body)
      .filter(r => r.has_pages)
      .map(r => ({ name: r.name, date: r.pushed_at.slice(0,10) }));

    let xml = `<?xml version="1.0" encoding="UTF-8"?>\n<urlset xmlns="http://www.sitemaps.org/schemas/sitemap/0.9">\n`;
    xml += `  <url>\n    <loc>https://${USER}.github.io/</loc>\n    <lastmod>${TODAY}</lastmod>\n    <changefreq>daily</changefreq>\n    <priority>1.0</priority>\n  </url>\n`;
    repos.forEach(r => {
      xml += `  <url>\n    <loc>https://${USER}.github.io/${r.name}/</loc>\n    <lastmod>${r.date}</lastmod>\n    <changefreq>monthly</changefreq>\n    <priority>0.8</priority>\n  </url>\n`;
    });
    xml += `</urlset>\n`;

    fs.writeFileSync('sitemap.xml', xml);
    console.log('✅ sitemap.xml updated');
  });
}).on('error', console.error);
