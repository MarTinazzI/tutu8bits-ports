#!/usr/bin/env python3
# Licença: GPL-2.0 (o que este script altera e o parallel-n64) (spec 053)
"""Patch M17 no glsm do libretro-common (spec 010, N64): cache de uniforms menor.

O glsm guarda um cache "program_uniforms[1024][1024]" (~80 MB de memoria estatica) para nao
repetir glUniform* iguais. Num aparelho de 256 MB isso nao cabe junto com o nucleo e a ROM
(parallel_n64 nem carrega: 298 MB de BSS; mupen64plus_next: 147 MB). O patch:
  - reduz a tabela para 512 programas x 64 posicoes (~2,6 MB);
  - indice fora da faixa usa uma entrada descartavel com 0xFF (os "!=" dao verdadeiro e a
    chamada ao GLES e sempre feita: comportamento correto, so sem cache). O original nem
    conferia limite.
Uso: glsm_m17.py ARQUIVO_glsm.c|glsm.cpp   (idempotente)
"""
import re
import sys

p = sys.argv[1]
s = open(p).read()
if "M17_GLSM_PROGS" in s:
    print("glsm_m17: ja aplicado em " + p)
    sys.exit(0)

decl = re.compile(r"static struct gl_program_uniforms program_uniforms\[MAX_UNIFORMS\]\[MAX_UNIFORMS\];")
if not decl.search(s):
    sys.exit("glsm_m17: declaracao de program_uniforms nao encontrada em " + p)
s = decl.sub(
    "/* M17 (spec 010): tabela menor; indice fora da faixa usa uma entrada descartavel */\n"
    "#define M17_GLSM_PROGS 512\n"
    "#define M17_GLSM_LOCS 64\n"
    "static struct gl_program_uniforms program_uniforms[M17_GLSM_PROGS][M17_GLSM_LOCS];\n"
    "static struct gl_program_uniforms m17_glsm_descarte;\n"
    "static struct gl_program_uniforms *m17_glsm_uni(GLuint prog, GLint loc)\n"
    "{\n"
    "   if (prog < M17_GLSM_PROGS && loc >= 0 && loc < M17_GLSM_LOCS)\n"
    "      return &program_uniforms[prog][loc];\n"
    "   memset(&m17_glsm_descarte, 0xff, sizeof(m17_glsm_descarte));\n"
    "   return &m17_glsm_descarte;\n"
    "}",
    s, count=1)

n_uso = len(re.findall(r"program_uniforms\[gl_state\.program\]\[location\]", s))
s = s.replace("program_uniforms[gl_state.program][location]", "(*m17_glsm_uni(gl_state.program, location))")

laco = re.compile(r"for \(i = 0; i < MAX_UNIFORMS; \+\+i\)\s*\n\s*memset\(&program_uniforms\[temp\]\[i\], 0, sizeof\(struct gl_program_uniforms\)\);")
if not laco.search(s):
    sys.exit("glsm_m17: laco de limpeza (program_uniforms[temp][i]) nao encontrado em " + p)
s = laco.sub(
    "if (temp < M17_GLSM_PROGS)\n"
    "      for (i = 0; i < M17_GLSM_LOCS; ++i)\n"
    "         memset(&program_uniforms[temp][i], 0, sizeof(struct gl_program_uniforms));",
    s, count=1)

resto = re.findall(r"program_uniforms\[", s)
# sobram so a declaracao, o acesso dentro de m17_glsm_uni e o memset do laco
if len(resto) != 3:
    sys.exit("glsm_m17: %d usos de program_uniforms[ nao tratados em %s" % (len(resto) - 3, p))
open(p, "w").write(s)
print("glsm_m17: %s (%d acessos trocados)" % (p, n_uso))
