#!/usr/bin/env node
/**
 * AI Review — analise estatica do diff de um Pull Request.
 *
 * O nome "AI review" vem do enunciado da aula. Na pratica a analise e
 * DETERMINISTICA (pattern matching), como o proprio laboratorio orienta:
 * "Em producao, a secao analyzeWithAI chamaria Bedrock/OpenAI. Para o lab,
 * usamos analise baseada em regras."
 *
 * Isso e uma escolha, nao uma limitacao: regra fixa da o mesmo veredito para
 * o mesmo diff, o que e requisito para um quality gate que bloqueia merge.
 *
 * Saida: JSON no stdout + codigo de saida 1 se houver achado CRITICAL.
 */
'use strict';

const { execSync } = require('node:child_process');

// ---------------------------------------------------------------- regras
// 12 padroes (o bonus pede mais de 8).
const REGRAS = [
  { id: 'secret-hardcoded', severidade: 'CRITICAL',
    titulo: 'Credencial escrita no codigo',
    // \w* dos dois lados pega nomes compostos: senhaDoBanco, dbPassword, apiKeyProd
    regex: /\w*(password|senha|secret|api[_-]?key|token)\w*\s*[:=]\s*['"][^'"]{4,}['"]/gi,
    dica: 'Mova para variavel de ambiente ou GitHub Secrets.' },

  { id: 'aws-access-key', severidade: 'CRITICAL',
    titulo: 'Access Key da AWS exposta',
    regex: /\b(AKIA|ASIA)[A-Z0-9]{16}\b/g,
    dica: 'Rotacione a chave imediatamente: uma vez no historico do Git, ela vazou.' },

  { id: 'private-key', severidade: 'CRITICAL',
    titulo: 'Chave privada commitada',
    regex: /-----BEGIN (RSA |EC |OPENSSH |PGP )?PRIVATE KEY-----/g,
    dica: 'Remova do historico e gere um novo par de chaves.' },

  { id: 'eval', severidade: 'CRITICAL',
    titulo: 'Uso de eval()',
    regex: /\beval\s*\(/g,
    dica: 'eval executa texto como codigo. Use JSON.parse ou um mapa de funcoes.' },

  { id: 'sql-injection', severidade: 'CRITICAL',
    titulo: 'SQL montado por concatenacao',
    regex: /(query|execute)\s*\(\s*[`'"].*(\+|\$\{)/g,
    dica: 'Use query parametrizada: db.query("... WHERE id = $1", [id]).' },

  { id: 'command-injection', severidade: 'CRITICAL',
    titulo: 'Comando de shell com interpolacao',
    regex: /\b(exec|execSync|spawn)\s*\(\s*[`'"].*\$\{/g,
    dica: 'Passe os argumentos como array, sem montar a string do comando.' },

  { id: 'console-log', severidade: 'WARNING',
    titulo: 'console.log deixado no codigo',
    regex: /console\.(log|debug|info)\s*\(/g,
    dica: 'Use um logger com nivel configuravel.' },

  { id: 'catch-vazio', severidade: 'WARNING',
    titulo: 'catch vazio engolindo o erro',
    regex: /catch\s*\(\s*\w*\s*\)\s*\{\s*\}/g,
    dica: 'Registre o erro ou relance. Erro silencioso vira bug invisivel.' },

  { id: 'bind-publico', severidade: 'WARNING',
    titulo: 'Servico escutando em 0.0.0.0',
    regex: /0\.0\.0\.0|INADDR_ANY/g,
    dica: 'Confirme se a exposicao publica e intencional.' },

  { id: 'http-sem-tls', severidade: 'WARNING',
    titulo: 'URL em http:// (sem TLS)',
    regex: /["'`]http:\/\/(?!localhost|127\.0\.0\.1)[^"'`\s]+/g,
    dica: 'Use https:// para qualquer destino externo.' },

  { id: 'todo', severidade: 'INFO',
    titulo: 'Marcador pendente (TODO/FIXME/HACK)',
    regex: /\b(TODO|FIXME|HACK|XXX)\b/g,
    dica: 'Abra uma issue em vez de deixar o lembrete no codigo.' },

  { id: 'docker-latest', severidade: 'INFO',
    titulo: 'Imagem base com tag latest',
    regex: /^\+?FROM\s+\S+:latest/gim,
    dica: 'Fixe a versao da imagem base: latest torna o build nao reproduzivel.' },
];

// ------------------------------------------------------------- utilidades
function obterDiff() {
  const base = process.env.BASE_SHA;
  const head = process.env.HEAD_SHA || 'HEAD';
  if (!base) {
    // fallback local: compara com o commit anterior
    return execSync('git diff HEAD~1 HEAD --unified=0', { encoding: 'utf8' });
  }
  return execSync(`git diff ${base} ${head} --unified=0`, { encoding: 'utf8' });
}

/** Extrai apenas as LINHAS ADICIONADAS, por arquivo. */
function linhasAdicionadas(diff) {
  const porArquivo = new Map();
  let arquivoAtual = null;
  let linhaNoArquivo = 0;

  for (const linha of diff.split('\n')) {
    const cabecalho = linha.match(/^\+\+\+ b\/(.+)$/);
    if (cabecalho) {
      arquivoAtual = cabecalho[1];
      if (!porArquivo.has(arquivoAtual)) porArquivo.set(arquivoAtual, []);
      continue;
    }
    const hunk = linha.match(/^@@ -\d+(?:,\d+)? \+(\d+)/);
    if (hunk) { linhaNoArquivo = parseInt(hunk[1], 10); continue; }
    if (arquivoAtual && linha.startsWith('+') && !linha.startsWith('+++')) {
      porArquivo.get(arquivoAtual).push({ n: linhaNoArquivo, texto: linha.slice(1) });
      linhaNoArquivo++;
    }
  }
  return porArquivo;
}

function analisar(porArquivo) {
  const achados = [];
  for (const [arquivo, linhas] of porArquivo) {
    // o proprio analisador contem os padroes: nao se auto-acusa
    if (arquivo.endsWith('ai-review.js')) continue;
    for (const { n, texto } of linhas) {
      for (const regra of REGRAS) {
        regra.regex.lastIndex = 0;
        if (regra.regex.test(texto)) {
          achados.push({
            arquivo, linha: n, id: regra.id,
            severidade: regra.severidade, titulo: regra.titulo,
            dica: regra.dica, trecho: texto.trim().slice(0, 90),
          });
        }
      }
    }
  }
  return achados;
}

function montarComentario(achados, arquivosAnalisados) {
  const porSev = (s) => achados.filter((a) => a.severidade === s);
  const crit = porSev('CRITICAL'), warn = porSev('WARNING'), info = porSev('INFO');
  const icone = { CRITICAL: '🔴', WARNING: '🟡', INFO: '🔵' };

  const l = ['<!-- ai-review-bot -->', '## Code Review automatizado', ''];

  if (achados.length === 0) {
    l.push('✅ **Nenhum problema encontrado.**', '',
      `Analisados ${arquivosAnalisados} arquivo(s) contra ${REGRAS.length} padroes.`);
    return l.join('\n');
  }

  l.push(`| Severidade | Quantidade |`, `|---|---:|`,
    `| 🔴 CRITICAL | ${crit.length} |`,
    `| 🟡 WARNING | ${warn.length} |`,
    `| 🔵 INFO | ${info.length} |`, '');

  l.push('| | Arquivo:linha | Problema | O que fazer |', '|---|---|---|---|');
  for (const a of [...crit, ...warn, ...info]) {
    l.push(`| ${icone[a.severidade]} | \`${a.arquivo}:${a.linha}\` | ${a.titulo} | ${a.dica} |`);
  }
  l.push('');

  if (crit.length > 0) {
    l.push(`> ### 🚫 Quality gate: PR bloqueado`,
      `> ${crit.length} achado(s) **CRITICAL**. O merge so libera depois de corrigidos.`);
  } else {
    l.push(`> ### ✅ Quality gate: liberado`,
      `> Nenhum CRITICAL. Os itens acima sao recomendacoes e **nao bloqueiam** o merge.`);
  }

  l.push('', `<sub>Analise deterministica (pattern matching) sobre ${REGRAS.length} padroes — so linhas adicionadas.</sub>`);
  return l.join('\n');
}

// ------------------------------------------------------------------ main
function main() {
  const diff = obterDiff();
  const porArquivo = linhasAdicionadas(diff);
  const achados = analisar(porArquivo);
  const comentario = montarComentario(achados, porArquivo.size);

  require('node:fs').writeFileSync('ai-review-comment.md', comentario);

  const criticos = achados.filter((a) => a.severidade === 'CRITICAL').length;
  console.log(comentario);
  console.log(`\n---\nTotal: ${achados.length} achado(s), ${criticos} CRITICAL.`);

  // Quality gate: CRITICAL derruba o workflow e bloqueia o PR.
  process.exit(criticos > 0 ? 1 : 0);
}

if (require.main === module) main();
module.exports = { REGRAS, linhasAdicionadas, analisar, montarComentario };
