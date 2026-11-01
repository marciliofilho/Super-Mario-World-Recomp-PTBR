# Branch `ptbr` — Super Mario World com tradução PT-BR

Este branch parte de `mstan/SuperMarioWorldRecomp` (commit `6d54aac`) e contém
apenas as modificações necessárias para rodar o port com a ROM traduzida para
o português do Brasil (Killer Skull v1.2), sem os mods opcionais.

## Mudanças

| Arquivo | O que faz |
|---|---|
| `src/main.c` | Identidade da ROM traduzida (CRC32 `82B20638`, SHA-256 `f0bb0f40…46dfa`); teclado sempre ativo para o jogador 1 mesmo com controle conectado; máscara de assentos corrigida para incluir jogadores de teclado |
| `src/mods/coop/coop_hooks.def` | 5 hooks internos convertidos para `COOP_HOOK_INSIDE`, refletindo o layout real das funções |
| `tools/apply_renderer_hooks.py` | Waivers explícitos para dois PCs cobertos por código interpretado (LLE) |
| `tools/apply_overrides.py` | Pula patches do bloco Falcon cujo dono é LLE-only, com mensagem explícita |

Todos os waivers são intencionais e documentados; não há afrouxamento de
verificações globais.

## O que não está incluído

- ROM original ou traduzida, patch IPS, saves
- `src/gen/` (código C gerado, ~59 MB)
- `build/`, executáveis e bibliotecas

## Como reproduzir

O pipeline completo (aplicação do patch, geração e build) está documentado no
repositório principal:

- https://github.com/marciliofilho/Super-Mario-World-Recomp-PTBR

Resumo: aplique o patch IPS na ROM USA, declare o SHA-256 resultante em
`recomp/disassembly-layout.json`, rode a geração e compile em um caminho ASCII
(o MSVC falha com acentos no caminho).

## Licença

O upstream é distribuído sob **PolyForm Noncommercial 1.0.0**. Este branch
mantém a mesma licença. Uso apenas não-comercial. Conteúdo derivado de ROM não
é licenciado para redistribuição.
