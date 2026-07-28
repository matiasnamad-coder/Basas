import { createServer } from 'http';
import { WebSocketServer } from 'ws';

import { GameServer } from './server/GameServer';

const port = Number(process.env.PORT ?? 2567);

// Servidor HTTP mínimo: responde 200 en '/' para health checks de
// hostings gratuitos (Render, Fly.io, etc. suelen pingear la raíz).
const httpServer = createServer((req, res) => {
  res.writeHead(200, { 'Content-Type': 'text/plain' });
  res.end('Las Basas server OK');
});

const wss = new WebSocketServer({ server: httpServer });
new GameServer(wss);

httpServer.listen(port, () => {
  console.log(`Las Basas server escuchando en :${port}`);
});
