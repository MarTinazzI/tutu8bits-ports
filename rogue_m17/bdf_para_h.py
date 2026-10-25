#!/usr/bin/env python3
"""Converte um BDF de celula fixa (misc-fixed 6x10) num .h com os glifos ASCII 32..126 (spec 035, plano D-03).

Uso: bdf_para_h.py [--latin1] <fonte.bdf> <saida.h>
Saida: m17_fonte[95][ALTURA], uma linha por byte, bit 7 = coluna mais a esquerda (so as LARGURA primeiras colunas).
Com --latin1 (spec 048, plano D-10): m17_fonte_latin1[191][ALTURA], os 95 do ASCII (indice = c - 32) seguidos dos
96 do Latin-1 160..255 (indice = c - 160 + 95) — as letras acentuadas do portugues. Sem a opcao, a saida e a de sempre.
"""
import sys

ASCII = list(range(32, 127))
LATIN1 = ASCII + list(range(160, 256))


def ler(caminho):
    larg = alt = desc = None
    glifos = {}
    with open(caminho, encoding="latin-1") as f:
        linhas = f.read().splitlines()
    i = 0
    while i < len(linhas):
        p = linhas[i].split()
        if p and p[0] == "FONTBOUNDINGBOX":
            larg, alt, desc = int(p[1]), int(p[2]), int(p[4])
        if p and p[0] == "STARTCHAR":
            cod = bbx = None
            j = i + 1
            while not linhas[j].startswith("BITMAP"):
                q = linhas[j].split()
                if q[0] == "ENCODING":
                    cod = int(q[1])
                elif q[0] == "BBX":
                    bbx = tuple(int(x) for x in q[1:5])
                j += 1
            bits = []
            j += 1
            while linhas[j] != "ENDCHAR":
                bits.append(int(linhas[j], 16))
                j += 1
            if cod is not None and (32 <= cod <= 126 or 160 <= cod <= 255):
                glifos[cod] = (bbx, bits)
            i = j
        i += 1
    return larg, alt, desc, glifos


def main():
    args = sys.argv[1:]
    latin1 = bool(args) and args[0] == "--latin1"
    if latin1:
        args = args[1:]
    if len(args) != 2:
        sys.exit("uso: bdf_para_h.py [--latin1] <fonte.bdf> <saida.h>")
    larg, alt, desc, glifos = ler(args[0])
    if (larg, alt) != (6, 10):
        sys.exit(f"esperava celula 6x10, veio {larg}x{alt}")
    codigos = LATIN1 if latin1 else ASCII
    faltam = [c for c in codigos if c not in glifos]
    if faltam:
        sys.exit(f"faltam glifos: {faltam}")
    ascendente = alt + desc  # desc e negativo (-2): linha de base a 8 px do topo
    saida = []
    for c in codigos:
        (w, h, xo, yo), bits = glifos[c]
        largura_bytes = (w + 7) // 8
        celula = [0] * alt
        topo = ascendente - (yo + h)
        for r, v in enumerate(bits):
            y = topo + r
            if not 0 <= y < alt:
                continue
            # v tem largura_bytes*8 bits, MSB = coluna 0 do glifo; desloca para a coluna xo da celula
            linha = v >> (largura_bytes * 8 - 8)  # so o 1o byte (a celula tem 6 colunas)
            linha = (linha >> xo) & 0xFC  # so as 6 colunas da celula (bits 7..2)
            celula[y] |= linha
        saida.append(celula)
    with open(args[1], "w", encoding="utf-8") as f:
        f.write("// Gerado por ports/rogue_m17/bdf_para_h.py a partir do misc-fixed 6x10 (dominio publico). Nao editar.\n")
        f.write("#define M17_FONTE_LARGURA 6\n#define M17_FONTE_ALTURA 10\n")
        if latin1:
            f.write("#define M17_FONTE_LATIN1_GLIFOS 191   /* 32..126 (c - 32) e 160..255 (c - 160 + 95) */\n")
            f.write("static const unsigned char m17_fonte_latin1[191][10] = {\n")
        else:
            f.write("static const unsigned char m17_fonte[95][10] = {\n")
        for c, celula in zip(codigos, saida):
            nome = chr(c).replace("\\", "barra") if c != 160 else "nbsp"
            f.write("  {" + ",".join(f"0x{b:02x}" for b in celula) + f"}},  // {c} {nome}\n")
        f.write("};\n")


if __name__ == "__main__":
    main()
