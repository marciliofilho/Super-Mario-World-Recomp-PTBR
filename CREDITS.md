# Créditos e licença

Este repositório **é um fork** de
[SuperMarioWorldRecomp](https://github.com/mstan/SuperMarioWorldRecomp), de
Matthew Stanley (`mstan`). Todo o crédito do framework e do port original é
dele. As modificações aqui presentes são o port em **PT-BR** de
*Super Mario World*.

## Projeto original

| Projeto | Autor | Repositório |
|---|---|---|
| SuperMarioWorldRecomp | Matthew Stanley (`mstan`) | https://github.com/mstan/SuperMarioWorldRecomp |
| snesrecomp | Matthew Stanley (`mstan`) | https://github.com/mstan/snesrecomp |

**Licença do upstream:** PolyForm Noncommercial 1.0.0. É *source-available*,
não open source no sentido da OSI: o uso permitido é apenas não-comercial e a
licença e o aviso de copyright devem ser preservados em qualquer
redistribuição. Este fork mantém a mesma licença — ver [`LICENSE`](LICENSE).

## Modificações deste fork

- Branch principal do port: `ptbr`
- Notas do port: [`PTBR.md`](PTBR.md)
- Build para Windows x64: release
  [`v0.15.6-ptbr`](https://github.com/marciliofilho/Super-Mario-World-Recomp-PTBR/releases/tag/v0.15.6-ptbr)
  — base upstream 0.15.6, apenas executável e assets, sem ROM nem patch

## Tradução

- **Killer Skull v1.2** — tradução PT-BR aplicada por patch IPS sobre a ROM
  americana. O patch não é distribuído neste repositório.

## Jogos e marcas

*Super Mario World* © Nintendo. Nenhum arquivo de jogo — ROM original,
ROM traduzida, patch, código gerado ou binário — é distribuído aqui.

## Arquivos originais deste fork

Estes arquivos não existem no upstream e foram criados para o port PT-BR:

- `README.md` — instruções de build e uso da versão PT-BR
- `PTBR.md` — notas do port
- `CREDITS.md` — este arquivo
- `docs/DIAGNOSTICO.md` — diagnóstico técnico do pipeline
- `tools/apply_ips.ps1` — aplicação do patch de tradução
- `tools/build.ps1` — pipeline reprodutível de build

## O que não está incluído

- ROM (`*.sfc`, `*.smc`), saves (`*.srm`) e patches (`*.ips`, `*.bps`, `*.ups`)
- `src/gen/`, `build/`, executáveis e bibliotecas

## Licença deste repositório

PolyForm Noncommercial 1.0.0, herdada do upstream — ver [`LICENSE`](LICENSE).
Cobre o código do port, as modificações PT-BR e os arquivos originais listados
acima. Não se estende à tradução de terceiros (Killer Skull v1.2).
