# tutu8bits-ports

> **English summary.** Build scripts and patches that compile emulators and native ports for the
> [tutu8bits](https://github.com/MarTinazzI/tutu8bits) frontend on the **M17** handheld: RetroArch and libretro cores,
> PPSSPP, GameTank, and native ports (Crispy Doom, Wolf4SDL, JFDuke3D, TyrQuake, NXEngine-evo, OpenTyrian, GNU FreeDink,
> Rogue, NetHack). Every component is downloaded from its own project at a pinned version, patched and built locally.
> **No binaries, ROMs, BIOS files or commercial games are distributed.** The documentation below is in Portuguese.

Receitas, versões fixadas e patches que compilam os emuladores e os ports nativos do
[**tutu8bits**](https://github.com/MarTinazzI/tutu8bits) para o console portátil **M17**. Cada componente é baixado do
projeto dele, na versão fixada em [`versoes.txt`](versoes.txt), corrigido pelos patches de [`patches/`](patches/) e
compilado no seu PC. **Nenhum binário, ROM, BIOS ou jogo é distribuído aqui.**

**O que roda e como joga:** [`COMPATIBILIDADE.md`](COMPATIBILIDADE.md) (21 sistemas e os jogos nativos, com notas e
consumo de CPU, e os controles de cada tipo de jogo). O aparelho (hardware, botões, atalhos) está no
[`docs/APARELHO.md`](https://github.com/MarTinazzI/tutu8bits/blob/main/docs/APARELHO.md) do tutu8bits.

## Usar

Este repositório mora **dentro** do tutu8bits, em `<tutu8bits>/ports/`. O jeito mais simples é deixar o tutu8bits trazer:

```sh
git clone https://github.com/MarTinazzI/tutu8bits.git
cd tutu8bits
./ports.sh        # clona este repositório em ports/ (na versão que combina) e abre o menu
```

O menu do `build.sh`:

```text
    1) todos (cabecalhos, conteudo livre e tudo abaixo)

  Bibliotecas
    2) sdl2_projeto   ...
  RetroArch e nucleos
    7) retroarch      ...
  Ports e programas
   37) nethack        ...
```

Escolha `1` (tudo), números (`3 5 8`) ou faixas (`3-7`). Sem perguntar: `ports/build.sh todos` ou
`ports/build.sh nethack crispy_doom`. No fim, o `build.sh` põe o que compilou no `cartao/` do tutu8bits; depois,
`./levar.sh` copia para o cartão. Os pré-requisitos (ferramentas do PC e os arquivos do seu aparelho) estão no README do
tutu8bits.

| Arquivo / pasta | O que é |
| :--- | :--- |
| `build.sh` | O build interativo. |
| `COMPATIBILIDADE.md` | O que roda no aparelho, como roda e os controles por tipo de jogo. |
| `versoes.txt`, `receitas/`, `patches/` | O catálogo: origem e versão fixada de cada componente, como compilar e o que muda nele. |
| `nethack_m17/`, `rogue_m17/` | As interfaces do projeto que vivem dentro desses dois jogos. |
| `config/`, `conteudo/` | Configurações iniciais dos jogos e a lista do conteúdo livre (Freedoom, Blasphemer, LibreQuake, os dados do Dink, FreePats, os shareware do Wolfenstein 3D e do Duke Nukem 3D), baixado na hora e conferido por sha256. |
| `completar_cartao.sh` | Põe os binários e os textos de licença no `cartao/` do tutu8bits. |
| `montar.sh`, `fontes.sh`, `licencas.tsv`, `conferir_licencas.sh` | Para quem for distribuir um build: o zip, o fonte correspondente de cada componente e a conferência de licenças. |
| `testes/` | Os testes (rodam pelo `testes/todos.sh` do tutu8bits). |

## Licenças

- Os scripts deste repositório são **MIT** ([`LICENSE`](LICENSE)).
- **Cada patch segue a licença do programa onde entra** (GPL, NGPL, BSD, Zlib e, nos trechos do motor Build do
  JFDuke3D, a licença não comercial do Build). A tabela está em [`patches/LEIA-ME.md`](patches/LEIA-ME.md), e cada
  patch diz a sua na primeira linha. As interfaces `nethack_m17/` (NGPL) e `rogue_m17/` (BSD-3) seguem a do jogo.
- Os programas compilados têm as licenças dos projetos deles (GPL, LGPL, MPL, Zlib, BSD, não comercial e outras);
  o `completar_cartao.sh` põe os textos em `cartao/tutu8bits/LICENCAS/`.

**Quem distribuir um build** (os binários, um zip, um cartão pronto) precisa cumprir essas licenças: oferecer o fonte
correspondente (o `fontes.sh` gera um arquivo por componente, na versão exata, com os patches à parte), levar os textos
de licença junto, **não vender** (snes9x, picodrive, mame2003-plus, fbneo, o angrylion do parallel-n64, o motor Build e o
OPL do MAME são de licença não comercial) e, pela licença do FBNeo, **não pedir doações**.
