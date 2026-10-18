// ARQUIVO DE DEMONSTRACAO — nao e usado pela aplicacao.
// Existe so para o AI review ter o que encontrar e o quality gate bloquear.
'use strict';

// CRITICAL: credencial escrita no codigo
const senhaDoBanco = 'Pr0ducao2026!';
const apiKey = "sk-ABCDEF1234567890";

// CRITICAL: access key da AWS exposta
const chaveAws = 'AKIAIOSFODNN7EXAMPLE';

function buscarUsuario(db, id) {
  // CRITICAL: SQL montado por concatenacao
  return db.query(`SELECT * FROM usuarios WHERE id = ${id}`);
}

function rodarComando(execSync, caminho) {
  // CRITICAL: comando de shell com interpolacao
  return execSync(`rm -rf ${caminho}`);
}

function interpretar(entradaDoUsuario) {
  // CRITICAL: eval executa texto como codigo
  return eval(entradaDoUsuario);
}

function salvar(dados) {
  try {
    console.log(dados);          // WARNING: log de debug esquecido
  } catch (e) {}                 // WARNING: catch vazio engolindo o erro
}

// WARNING: URL externa sem TLS
const ENDPOINT = "http://api.exemplo.com/v1/pedidos";

// TODO: remover este arquivo depois da avaliacao
module.exports = { buscarUsuario, rodarComando, interpretar, salvar, ENDPOINT };
