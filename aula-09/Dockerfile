# Multi-stage: o estagio de build carrega devDependencies e ferramentas;
# a imagem final leva so o runtime e o codigo. Menos superficie, menos peso.

# ---------- estagio 1: dependencias de producao ----------
FROM node:20-alpine AS deps
WORKDIR /app
COPY package*.json ./
# npm ci respeita o lockfile; --omit=dev descarta jest, eslint e supertest
RUN npm ci --omit=dev && npm cache clean --force

# ---------- estagio 2: imagem final ----------
FROM node:20-alpine AS runtime
WORKDIR /app

# tini como PID 1: encaminha SIGTERM e colhe processos zumbis
RUN apk add --no-cache tini

ENV NODE_ENV=production \
    PORT=3000

# so o necessario, e ja com o dono correto
COPY --from=deps --chown=node:node /app/node_modules ./node_modules
COPY --chown=node:node server.js ./
COPY --chown=node:node package.json ./

# nunca rodar como root
USER node

EXPOSE 3000

HEALTHCHECK --interval=30s --timeout=3s --start-period=5s --retries=3 \
  CMD node -e "require('http').get('http://127.0.0.1:3000/health',r=>process.exit(r.statusCode===200?0:1)).on('error',()=>process.exit(1))"

ENTRYPOINT ["/sbin/tini", "--"]
CMD ["node", "server.js"]
