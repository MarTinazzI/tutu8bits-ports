#!/usr/bin/env python3
# Licença: GPL-2.0 (o que este script altera e o parallel-n64) (spec 053)
"""Patch M17 de memoria no parallel_n64 (spec 015, T07a): encolhe tres buffers estaticos enormes
que o aparelho de 256 MB nao comporta e que NAO servem ao nosso uso (plugins GLES2 leves, sem 64DD,
sem angrylion multithread). Com isto o BSS cai de ~206 MB para caber em 256 MB.

  1. save_memory_data.disk[0x0435B0C0]  (~67 MB)  -> disco do 64DD; nenhum jogo-alvo usa 64DD.
  2. PARALLEL_MAX_WORKERS 64u            (~35 MB)  -> state[WORKERS] do angrylion; o aparelho tem 2
                                                     nucleos e nem selecionamos o angrylion.
  3. glide2gl tex1/tex2[2048*2048]       (~32 MB)  -> buffer de textura superdimensionado (pacotes
                                                     HD); no N64 nativo 1024*1024 (8 MB) sobra.

Uso: n64mem_m17.py RAIZ_DO_FONTE   (idempotente). Falha se algum alvo nao for achado.
"""
import re
import sys
import os

raiz = sys.argv[1]

def troca(rel, padrao, novo, rotulo):
    p = os.path.join(raiz, rel)
    s = open(p).read()
    novo_s, n = re.subn(padrao, novo, s, count=1)
    if n != 1:
        # o alvo ja foi trocado numa aplicacao anterior? (idempotente)
        if "M17_N64MEM" in s:
            print("n64mem_m17: ja aplicado (%s)" % rotulo); return
        sys.exit("n64mem_m17: alvo nao encontrado (%s) em %s" % (rotulo, rel))
    open(p, "w").write(novo_s)
    print("n64mem_m17: %s (%s)" % (rel, rotulo))

# 1. disco do 64DD: 0x0435B0C0 -> 0x100 (mantido pequeno e valido; .srm fica minusculo)
troca("libretro/libretro_memory.h",
      r"uint8_t disk\[0x0435B0C0\];",
      "uint8_t disk[0x100]; /* M17_N64MEM: 64DD nao usado (spec 015) */",
      "disk-64dd")

# 1b. format_disk() zera o disco com o tamanho ANTIGO (0x0435B0C0) -> estouraria o buffer encolhido
# e crasha no retro_load_game (sessao 2 da spec 015). Casar o memset com o novo tamanho.
troca("libretro/libretro.c",
      r"memset\(disk, 0, 0x0435B0C0\);",
      "memset(disk, 0, 0x100); /* M17_N64MEM: disco do 64DD encolhido (spec 015) */",
      "format-disk")

# 2. workers do angrylion: 64u -> 2u (2 nucleos; angrylion nem e selecionado)
troca("mupen64plus-video-angrylion/parallel_al.h",
      r"#define PARALLEL_MAX_WORKERS 64u",
      "#define PARALLEL_MAX_WORKERS 2u /* M17_N64MEM: 2 nucleos (spec 015) */",
      "workers")

# 3. buffer de textura do glide2gl: 2048*2048 -> 1024*1024 (N64 nativo, sem pacotes HD)
troca("glide2gl/src/Glide64/TexCache.c",
      r"uint32_t tex1\[2048\*2048\];\s*//[^\n]*\n\s*uint32_t tex2\[2048\*2048\];",
      "uint32_t tex1[1024*1024]; /* M17_N64MEM: nativo (spec 015) */\n"
      "uint32_t tex2[1024*1024];",
      "tex1-tex2")

print("n64mem_m17: ok")
