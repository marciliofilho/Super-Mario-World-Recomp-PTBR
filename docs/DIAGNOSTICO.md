# Diagnóstico — Port nativo de Super Mario World (SNES) em PT-BR

Documento de referência do projeto. Registra o que foi verificado, o que foi
decidido e por quê.

Data: 2026-10-30

---

## 1. Objetivo

Rodar **Super Mario World** como executável nativo no Windows, sem emulador
externo, com a **tradução PT-BR do Killer Skull v1.2** aplicada.

---

## 2. Estado inicial do ambiente

| Item | Antes | Agora |
|---|---|---|
| Git | ausente | 2.56.0.4 |
| Python | só stub da Microsoft Store | 3.12.10 (real) |
| Visual Studio / MSVC | ausente | VS 2022 Build Tools 17.14.44 |
| CMake | ausente | 3.31.6-msvc6 (via VS) |
| Rust | ausente | 1.99.1 (perfil minimal) |
| Node / Java / Ghidra | ausente | não necessário para este caminho |

Notas de instalação:

- O `winget` do Python cria o stub da Microsoft Store como `python` no PATH.
  Em Git Bash o stub "vence" — por isso `regen.sh` precisa de
  `PYTHON=/c/Users/.../Python312/python.exe`.
- O primeiro `rustup` instalou um toolchain corrompido (`missing manifest`).
  A reinstalação com `--profile minimal` resolveu (menos componentes para
  renomear; o erro era `os error 2/3` em rename de arquivos).


---

## 3. Matéria-prima

### 3.1 ROM original

```
D:\Games\Super Mario World (USA)\Super Mario World (USA).sfc
524.288 bytes (512 KB)  |  CRC32 B19ED489  |  LoROM (0x20)
RomSize 0x09  |  Chips 0x02 (ROM+RAM+battery)  |  checksum 0x5F25 + 0xA0DA = 0xFFFF
```

É o **SMW (USA) v1.0 stock**, exatamente o que o patch espera.

### 3.2 Patch de tradução

O `.rar` em `Downloads` **não contém ROM** — contém:

- `Super Mario World (K.S.)(Br) v1.2.ips` — 602.058 bytes, 1.585 registros
- `Leia-me.txt`

Autor: Killer Skull. Revisão: Wolfwood. Assembler: Denim.
Cobre textos, gráficos, acentuação e hacks de asm (`MARIO START!`, `TIME UP!`,
`GAME OVER`, `BONUS GAME`, `COURSE CLEAR`).

### 3.3 ARMADILHA: o patch tem header de copiadora

O IPS escreve até o offset `0x100200` e o header LoROM resultante fica em
`0x81C0` — não em `0x7FC0`. Isso prova que o patch foi gerado contra uma ROM
**com 512 bytes de header de copiadora (.smc)**.

Aplicar o IPS direto na `.sfc` limpa desloca tudo em `0x200` e produz uma
imagem inválida (o "header" cai no meio do código).

Procedimento correto (implementado em `tools/apply_ips.ps1`):

1. prefixar 512 bytes na ROM stock
2. aplicar o IPS (offsets relativos ao arquivo com header)
3. remover os 512 bytes do resultado

Resultado validado:

```
rom\smw-ptbr.sfc
1.048.576 bytes (1 MB exato)  |  CRC32 82B20638  |  LoROM (0x20)
RomSize 0x0A  |  Chips 0x02  |  checksum 0x8393 + 0x7C6C = 0xFFFF
Título "SUPER MARIOWORLD" preservado
```

---

## 4. O que a tradução realmente muda

Diff ROM traduzida × ROM stock, por banco LoROM de 32 KB:

| Banco | Offset | Bytes alterados | % |
|---|---|---|---|
| `$00:8000` | `0x000000` | 535 | 1,6% |
| `$01:8000` | `0x008000` | 9 | 0,0% |
| `$02:8000` | `0x010000` | 6 | 0,0% |
| `$03:8000` | `0x018000` | 1.517 | 4,6% |
| `$04:8000` | `0x020000` | 148 | 0,5% |
| `$05:8000` | `0x028000` | 1.682 | 5,1% |
| `$06:8000` | `0x030000` | 481 | 1,5% |
| `$07:8000` | `0x038000` | 0 | 0,0% |
| `$08:8000` | `0x040000` | 31.928 | 97,4% |
| `$09:8000` | `0x048000` | 31.726 | 96,8% |
| `$0A:8000` | `0x050000` | 31.831 | 97,1% |
| `$0B:8000` | `0x058000` | 30.388 | 92,7% |
| `$0C:8000` | `0x060000` | 0 | 0,0% |
| `$0D:8000` | `0x068000` | 156 | 0,5% |
| `$0E:8000` | `0x070000` | 694 | 2,1% |
| `$0F:8000` | `0x078000` | 2.148 | 6,6% |

**Leitura:**

- `$08`–`$0B` (~125.873 bytes) é o **Lunar Magic re-salvando dados de fase**.
  Conteúdo equivalente, bytes diferentes. Irrelevante para a tradução.
- Fora desses bancos, **só 7.376 bytes mudaram** — texto, fontes, tiles e
  alguns imediatos de asm.
- `$10`–`$1F` (região nova, 0x80000–0xFFFFF): ~101 KB não-vazios, área de
  expansão do Lunar Magic.

Conclusão: **o patch não é um ROM hack de jogo, é uma tradução.** Não há
mudança estrutural de layout que impeça recompilar.

---

## 5. Decisão de arquitetura

### Por que recompilar a ROM traduzida (e não usar o release pronto)

O `snesrecomp` compila o código 65816 **da ROM fornecida** e, em runtime, lê
gráficos/texto/níveis **direto da imagem da ROM**. Logo, compilar a partir da
ROM traduzida faz a tradução entrar "de graça", sem escrever nenhum mod.

Alternativa descartada: release pronto (gerado da ROM stock) + mod de
localização em runtime. Funcionaria, mas exigiria reimplementar a tradução
inteira como tabela de patches — trabalho muito maior e mais frágil.

### Modelo híbrido (o que "sem emulador" significa aqui)

```
código 65816 do SMW  ->  C nativo (recompilado)
PPU, APU/SPC700, DMA/HDMA, mappers  ->  emulados (core LakeSnes)
```

O executável **não precisa de emulador externo**, mas o hardware do SNES
continua emulado internamente. É o mesmo modelo do N64Recomp e do zelda3:
recompila-se a CPU, emula-se o silício. A PPU do SNES não tem fluxo de
instruções, então não é recompilável.

---

## 6. Pontos de integração identificados no código

### 6.1 Portão de identidade da ROM

`SuperMarioWorldRecomp/src/main.c`:

```c
static const uint32_t kSmwUsaCrc32 = 0xB19ED489u;
```

Precisa virar `0x82B20638u` (CRC32 da ROM traduzida). O launcher pula um
header SMC de 512 bytes antes de hashear, então a comparação é sobre o
conteúdo limpo.

### 6.2 Hash do catálogo de mods

`main.c` inicializa o runtime de mods com um SHA-256 da ROM base:

```c
snes_mod_runtime_initialize_c(SNES_MOD_CATALOG_ROOT, "super-mario-world-us",
    "0838e531fe22c077528febe14cb3ff7c492f1f5fa8de354192bdff7137c27f5b");
```

Os mods (widescreen adaptativo, MSU-1, co-op) assumem a ROM stock de 512 KB.
Para o primeiro port: **desabilitar mods** (`SNESRECOMP_ENABLE_MODS=OFF`) em
vez de tentar reconciliar o hash.

### 6.3 Pipeline de geração

`tools/regen.sh` **não valida a ROM**. Ele apenas lê `smw.sfc` da raiz do
repositório:

```bash
ROM="smw.sfc"
python snesrecomp/tools/v2_emit.py --rom "$GEN_ROM" ...
```

Ou seja: basta colocar a ROM traduzida como `smw.sfc` e rodar
`bash tools/regen.sh --stock`.

### 6.4 Backend de análise

O backend Python foi **aposentado**. O analisador nativo em Rust é o único
caminho; `--analysis-backend python` responde:

```
v2_emit.py: error: the Python analyzer was retired; the native analyzer is
the only one (drop --analysis-backend python)
```

Portanto Rust (via rustup) é dependência obrigatória, não opcional. A geração
funcionou com o perfil `minimal` (`rustc 1.99.1`).

### 6.5 Descobertas da execução real do pipeline

| Item | Detalhe |
|---|---|
| Identidade da ROM na geração | `recomp/disassembly-layout.json` declara `rom_sha256`. É o **único** portão: `materialize()`/`ingest()` leem os bytes de instrução da ROM fornecida, não do disassembly original. Basta trocar o hash. |
| Analisador | `SNESRECOMP_ANALYSIS_BACKEND=python` é rejeitado. Rust obrigatório. |
| `regen.sh` em Git Bash | `python` resolve para o stub da Microsoft Store; passar `PYTHON=/c/.../Python312/python.exe`. E `~/.cargo/bin` precisa estar no PATH. |
| Helper do Falcon | `SMW_BUNDLE_FALCON_CACHE_HELPER=ON` (padrão) faz o **configure** falhar exigindo `PIL` + `PyInstaller`. Desligar: `-DSMW_BUNDLE_FALCON_CACHE_HELPER=OFF`. |
| SDL3 | não há pacote instalado; o CMake compila SDL3 do source (`third_party`), então o build inicial é mais longo. |
| Caminho com acento | **O build falha** se o caminho do projeto tiver caractere não-ASCII. O MSVC grava o caminho do PCH na página de código ANSI e compila como UTF-8: `warning C4828` + `error MSB8084: Cannot transcode invalid UTF-8 JSON text` + `MSB6006 CL.exe exit 2`. Solução: compilar por uma junction ASCII (`C:\smw-ptbr`). |

### 6.6 Resultado da geração com a ROM traduzida

```
analysis: 8068 roots -> 8267 exact variants, 11327 edges
analysis: 3099 AOT-eligible, 5168 LLE-only
v2_emit: 8068 roots, 3099 exact AOT variants, 5168 LLE variants
v2_emit: 17 bank(s) emitted, 0 reused in 14.82s
=== Done (stock) ===
```

97 arquivos em `src/gen/`. **O analisador aceita a ROM de 1 MB sem
ajustes** — o risco maior do plano (§8) está eliminado.

---

## 7. Plano de execução

1. ~~Validar ROM stock~~ ✅
2. ~~Aplicar IPS e validar ROM traduzida~~ ✅
3. ~~Script de aplicação reproduzível~~ ✅ `tools/apply_ips.ps1`
4. Instalar toolchain (Git ✅, Python ✅, VS 2022 Build Tools ⏳)
5. `git clone --recurse-submodules` ✅ / em andamento
6. Copiar `rom/smw-ptbr.sfc` para `SuperMarioWorldRecomp/smw.sfc`
7. Trocar `kSmwUsaCrc32` para `0x82B20638u`
8. `bash tools/regen.sh --stock`
9. `cmake -S . -B build && cmake --build build --config Release`
10. Rodar e validar: boot → título → fase 1 → textos PT-BR

---

## 8. Riscos conhecidos

| Risco | Probabilidade | Mitigação |
|---|---|---|
| Analisador rejeitar ROM de 1 MB | média | `v2_emit.py` só precisa dos bancos configurados; testar e ajustar |
| Fronteiras de função deslocadas por edições de asm | baixa | só 7.376 bytes mudaram fora das fases; edições parecem ser imediatos de mesmo tamanho |
| Tripwires M/X disparando em código alterado | baixa | o runner cai no tier interpretador em vez de quebrar |
| Lunar Magic mudou encoding de fase | baixa | conteúdo é o mesmo; se der problema, usar a ROM stock + mod |
| Launcher exigir caminho específico | baixa | passar ROM por argumento / `rom.cfg` |

---

## 9. Nota legal

A ROM e o código gerado derivam de obra comercial. Uso **pessoal**, a partir
de dump próprio. Não redistribuir `rom/`, `src/gen/` nem os executáveis
gerados.

---

## 10. Resultado da execucao (build nativo concluido)

* Data: 30/10/2026.
* Executavel: `SuperMarioWorldRecomp/build/Release/SuperMarioWorldSNESRecomp.exe`
  (`ptbr-1.2`, 16.051.712 bytes) + `smw.sfc` ao lado.
* Validacao: `--benchmark 600` -> 299,8 fps; modo janela a 2x com audio ->
  ~50-54 fps estaveis; captura de tela da tela de selecao de jogador mostra
  `MARIO A/B/C .. VAZIO` e `APAGAR JOGO` (PT-BR confirmado). GameMode em
  frame 599 = `0x07` (titulo).

### 10.1 Ajustes para a ROM traduzida

* `src/main.c`: `kSmwUsaCrc32 = 0x82B20638u`; identidade do catalogo de mods
  = SHA-256 da ROM traduzida (mods desativados, nao-fatal).
* `recomp/disassembly-layout.json`: `rom_sha256` = `f0bb...dfa`.
* `tools/apply_renderer_hooks.py`: `LLE_COVERED_PCS = {0x029B0C, 0x029B12}`
  (sites dentro de `ProcessExtendedSprites`, rebaixado para LLE). Os outros 21
  sites permanecem obrigatorios.
* `src/mods/coop/coop_hooks.def`: 8 sites interiores redeclarados como
  `COOP_HOOK_INSIDE(pc, owner)`. Os 5 originais sao `0x00C569`, `0x00F2CD`,
  `0x02BAAF`, `0x05D83E`, `0x05D8B7`; o upstream 0.15.5 acrescentou
  `0x00A21B`, `0x00A28A` e `0x01F78A`, que tambem precisam ficar internos.
* `tools/apply_overrides.py`: detecta funcoes donas LLE-only e pula seus
  block patches com mensagem explicita. 4 patches do Falcon ficam inativos.

### 10.2 Causa-raiz da perda de AOT (246 funcoes)

A traducao repontou tabelas de ponteiros (ex.: `0x0084F1..0x008598`, 56
ponteiros de 3 bytes) e varios `JSL` para copias relocadas nos bancos
expandidos. Os bancos alvo nao tem `cfg`, logo o analisador rebaixa as
funcoes afetadas para LLE (correto funcionalmente, mais lento). AOT cai de
3.432 -> 3.099 variantes. Declarar os bancos `$06`/`$0E`/`$10`-`$1F` como
codigo nao recupera AOT (experimento `exp_banks.sh`).

### 10.3 Performance observada

* Headless `--benchmark 600`: 299,8 fps.
* Headless com audio `--benchmark-audio 600`: 513,7 fps.
* Janela a 2x com audio: ~50-54 fps (pacing de audio no Windows).

### 10.4 Limitacoes conhecidas

* Mods (widescreen, MSU-1, co-op) desativados.
* Helper de cache do Falcon desligado.
* 4 block patches do Falcon inativos.
* 2 sites do renderer cobertos apenas pelo interpretador.
* ROM, C gerado e binario nao devem ser redistribuidos (uso pessoal).

---

## 11. Sincronizacao com o upstream 0.15.5

* Data: 01/11/2026.
* Merge `74ab3e8` do upstream (`46b6d4f` + `f1c7b5b` + `6a5923e`) no branch
  `ptbr`; submodulo `snesrecomp` de `cc095ad4` para `90196539` (37 commits).
* Tag de seguranca: `pre-sync-20261101-1356`.
* Release: `v0.15.5-ptbr.2` (zip 6,81 MB).
* Validacao: build completo, boot headless com a ROM traduzida e
  `--benchmark 300` -> ~504 fps (exit 0).

### 11.1 Correcoes no `tools/build.ps1`

Dois problemas de ambiente apareceram nesta sincronizacao:

* **CMake nao encontrado.** O glob fixo exigia um nivel extra de pasta
  (`2022\*\*\Common7\...`), que nao existe no VS Build Tools atual. A
  descoberta agora usa `vswhere` (fonte oficial), com fallback para
  `Program Files`, `Program Files (x86)` e `PATH`.
* **`regen.sh` falhava com `cd: too many arguments`.** O caminho com acento
  era passado ao bash por variavel de ambiente; o Windows converte para a code
  page ANSI e o bash recebe bytes invalidos. O regen agora roda pela junction
  ASCII (`C:\smw-ptbr`), a mesma usada pelo MSVC.
