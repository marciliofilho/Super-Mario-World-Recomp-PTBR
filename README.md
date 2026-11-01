# Projeto: port nativo de Super Mario World (SNES) em PT-BR

Port estático do *Super Mario World* (USA) para Windows, via
[SuperMarioWorldRecomp](https://github.com/mstan/SuperMarioWorldRecomp) /
[snesrecomp](https://github.com/mstan/snesrecomp), usando a **ROM traduzida
para PT-BR (Killer Skull v1.2)** como entrada do recompilador.

> **Uso pessoal.** A ROM, o código C gerado (`src/gen/`) e os executáveis
> derivam de obra comercial. Nada disso deve ser redistribuído.
> Ver `docs/DIAGNOSTICO.md` §9.

## Créditos e licença

Este repositório **não é um fork**. Contém apenas documentação e scripts
originais; o framework e o port pertencem a Matthew Stanley (`mstan`) e estão
sob **PolyForm Noncommercial 1.0.0**. As modificações de código vivem em um
[fork separado](https://github.com/marciliofilho/SuperMarioWorldRecomp), branch
`ptbr`.

- Detalhes completos: [`CREDITS.md`](CREDITS.md)
- Licença deste repositório (apenas os arquivos originais): [`LICENSE`](LICENSE)

## Estrutura

```
rom/
  smw-usa-stock.sfc   ROM original (CRC32 B19ED489) — NÃO versionar
  smw-ptbr.ips        patch IPS da tradução
  smw-ptbr.sfc        ROM traduzida gerada (CRC32 82B20638) — NÃO versionar

tools/
  apply_ips.ps1       aplicador de IPS ciente do header de copiadora
  build.ps1           pipeline completo: ROM -> regen -> build

docs/
  DIAGNOSTICO.md      tudo que foi verificado e por quê

SuperMarioWorldRecomp/  clone do port + submódulos
```

## Como a ROM traduzida é gerada

O patch IPS foi criado contra uma ROM **com header de copiadora de 512 bytes**.
Aplicá-lo na `.sfc` limpa desloca tudo em `0x200` e corrompe a imagem.

```powershell
.\tools\apply_ips.ps1 -Ips .\rom\smw-ptbr.ips `
                      -Rom .\rom\smw-usa-stock.sfc `
                      -Out .\rom\smw-ptbr.sfc
```

Saída esperada: `1.048.576` bytes, CRC32 `82B20638`, header LoROM em `0x7FC0`.

## Build

Ver `docs/DIAGNOSTICO.md` §7 para o plano e §8 para os riscos conhecidos.

```powershell
.\tools\build.ps1
```


## Executar

```powershell
cd 'C:\smw-ptbr\SuperMarioWorldRecomp\build\Release'
.\SuperMarioWorldSNESRecomp.exe smw.sfc
```

O executável procura `smw.sfc` ao lado de si. `tools/build.ps1` copia a ROM
traduzida automaticamente para `build/Release/smw.sfc`.

### Configuração sugerida (`config.ini`)

* `WindowScale = 2` (escala 2x).
* `EnableAudio = 1` (áudio ligado).
* `DisableFrameDelay = 1` (evita o pacing de ~50 fps do Windows).
* `NewRenderer = 1` (renderizador HLE).

## Controles

* **Teclado** (jogador 1, layout ergonômico):
  * Ação: `A` = A (pulo com giro), `S` = B (pulo/correr),
    `D` = X (capa), `W` = Y (correr/pegar), `Q` = L, `R` = R.
  * D-pad: setas. `Enter` = Start, `Shift direito` = Select.
* **Controle** (gamepad): funciona automaticamente se estiver conectado.
* Se o teclado não responder no jogo, edite `config.ini` e garanta
  `KeyboardPlayers = 1` (a build já vem com esse valor).
* O *launcher* (janela de configuração inicial) é navegável por mouse.
  Se ele abrir atrás do console, clique na janela "Super Mario World
  (Recompiled)".


### Solução de problemas

* **Teclado não responde**: confirme `KeyboardPlayers = 1` e `SkipLauncher = 1`
  em `config.ini`, e clique na janela do jogo para dar foco. O console que
  abre junto (o `.exe` é de console) pode roubar o foco — feche-o se
  atrapalhar.
* **Apenas o controle funciona**: isso é o padrão quando um gamepad está
  conectado. Com `KeyboardPlayers = 1` o teclado passa a ser lido em paralelo.
* **Janela não aparece / foco perdido**: execute a partir de
  `C:\smw-ptbr\...\build\Release` e clique na janela
  "Super Mario World (Recompiled)".

## Observações técnicas

* A ROM traduzida reponta tabelas de ponteiros para os bancos expandidos
  `$10`–`$1F`; o recompilador não tem `cfg` para esses bancos, então ~246
  funções rodam no interpretador (LLE) em vez de AOT. Comportamento
  correto, desempenho acima de 60 fps no título e ~50 fps com áudio.
* Mods (widescreen, MSU-1, co-op) desativados (a ROM não bate com os
  pacotes staged). Para reativá-los seria preciso regenerar os pacotes para
  a ROM traduzida.
* O build precisa ser feito a partir de um caminho ASCII. O
  `tools/build.ps1` cria a junction `C:\smw-ptbr` automaticamente.
