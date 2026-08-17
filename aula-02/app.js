const express = require('express');
const app = express();

const PORT = process.env.PORT || 3000;
const DB_HOST = process.env.DB_HOST || 'localhost';
const DB_PORT = process.env.DB_PORT || 5432;
const DB_NAME = process.env.DB_NAME || 'technova';
const REDIS_HOST = process.env.REDIS_HOST || 'localhost';
const REDIS_PORT = process.env.REDIS_PORT || 6379;

app.use(express.json());

app.get('/', (req, res) => {
  res.json({
    servico: 'TechNova API - Aula 02 TF',
    aluno: 'José Henrique Teixeira Luiz',
    ra: '3225002',
    status: 'online',
    banco: `${DB_HOST}:${DB_PORT}/${DB_NAME}`,
    cache: `${REDIS_HOST}:${REDIS_PORT}`,
    timestamp: new Date().toISOString()
  });
});

app.get('/health', (req, res) => {
  res.json({
    status: 'healthy',
    uptime: process.uptime(),
    servicos: {
      api: 'online',
      banco: `${DB_HOST}:${DB_PORT}`,
      cache: `${REDIS_HOST}:${REDIS_PORT}`
    }
  });
});

app.listen(PORT, () => {
  console.log(`TechNova API rodando na porta ${PORT}`);
  console.log(`Banco: ${DB_HOST}:${DB_PORT}/${DB_NAME}`);
  console.log(`Cache: ${REDIS_HOST}:${REDIS_PORT}`);
});
