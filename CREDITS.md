# Créditos e licença

Este repositório **não é um fork**. Ele reúne documentação, diagnóstico e
scripts originais usados para reproduzir um port nativo de *Super Mario World*
em PT-BR. O código do framework e do port **não** está incluído aqui.

## Projeto original

| Projeto | Autor | Repositório |
|---|---|---|
| SuperMarioWorldRecomp | Matthew Stanley (`mstan`) | https://github.com/mstan/SuperMarioWorldRecomp |
| snesrecomp | Matthew Stanley (`mstan`) | https://github.com/mstan/snesrecomp |

**Licença do upstream:** PolyForm Noncommercial 1.0.0. É *source-available*,
não open source no sentido da OSI: o uso permitido é apenas não-comercial e a
licença e o aviso de copyright devem ser preservados em qualquer
redistribuição.

As modificações feitas neste projeto sobre o framework são publicadas
separadamente, como fork, para preservar a linhagem e a licença:

- Fork: https://github.com/marciliofilho/SuperMarioWorldRecomp
- Branch: `ptbr`
- Notas: `PTBR.md` no fork
- Build para Windows x64: release [`v0.15.5-ptbr`](https://github.com/marciliofilho/SuperMarioWorldRecomp/releases/tag/v0.15.5-ptbr) — apenas executável e assets, sem ROM nem patch

## Tradução

- **Killer Skull v1.2** — tradução PT-BR aplicada por patch IPS sobre a ROM
  americana. O patch não é distribuído neste repositório.

## Jogos e marcas

*Super Mario World* © Nintendo. Nenhum arquivo de jogo — ROM original,
ROM traduzida, patch, código gerado ou binário — é distribuído aqui.

## O que é original neste repositório

- `README.md` — instruções de build e uso
- `docs/DIAGNOSTICO.md` — diagnóstico técnico do pipeline
- `tools/apply_ips.ps1` — aplicação do patch de tradução
- `tools/build.ps1` — pipeline reprodutível de build

## O que não está incluído

- ROM (`*.sfc`, `*.smc`), saves (`*.srm`) e patches (`*.ips`, `*.bps`, `*.ups`)
- Código do `SuperMarioWorldRecomp` / `snesrecomp`
- `src/gen/`, `build/`, executáveis e bibliotecas

## Licença deste repositório

MIT — ver [`LICENSE`](LICENSE). Cobre **apenas** os arquivos originais listados
acima. Não se estende ao framework upstream (PolyForm Noncommercial 1.0.0) nem
à tradução de terceiros.
