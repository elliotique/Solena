'use strict';

const fs = require('node:fs');
const http = require('node:http');
const path = require('node:path');

const root = path.resolve(__dirname);
const port = Number(process.env.PORT || 8000);
const contentTypes = {
  '.css': 'text/css; charset=utf-8',
  '.html': 'text/html; charset=utf-8',
  '.js': 'text/javascript; charset=utf-8',
  '.json': 'application/json; charset=utf-8',
  '.png': 'image/png',
  '.svg': 'image/svg+xml'
};

const server = http.createServer((req, res) => {
  if (req.method !== 'GET' && req.method !== 'HEAD') {
    res.writeHead(405, { Allow: 'GET, HEAD' });
    res.end('Method not allowed');
    return;
  }

  let pathname;
  try {
    pathname = decodeURIComponent(new URL(req.url, 'http://localhost').pathname);
  } catch {
    res.writeHead(400);
    res.end('Bad request');
    return;
  }
  if (pathname === '/') pathname = '/index.html';

  const file = path.resolve(root, `.${pathname}`);
  if (file !== root && !file.startsWith(`${root}${path.sep}`)) {
    res.writeHead(403);
    res.end('Forbidden');
    return;
  }

  fs.stat(file, (error, stats) => {
    if (error || !stats.isFile()) {
      res.writeHead(404);
      res.end('Not found');
      return;
    }

    res.writeHead(200, {
      'Cache-Control': 'no-store',
      'Content-Length': stats.size,
      'Content-Type': contentTypes[path.extname(file).toLowerCase()] || 'application/octet-stream',
      'X-Content-Type-Options': 'nosniff'
    });
    if (req.method === 'HEAD') {
      res.end();
      return;
    }

    const stream = fs.createReadStream(file);
    stream.on('error', () => res.destroy());
    stream.pipe(res);
  });
});

server.on('error', error => {
  if (error.code === 'EADDRINUSE') {
    console.error(`Port ${port} is already in use. Stop the other server or set PORT.`);
    process.exitCode = 1;
    return;
  }
  throw error;
});

server.listen(port, '127.0.0.1', () => {
  console.log(`Solena is available at http://127.0.0.1:${port}/`);
  console.log('Keep this terminal open while playing. Press Ctrl+C to stop the server.');
});
