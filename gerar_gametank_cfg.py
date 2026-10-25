#!/usr/bin/env python3
"""Gera o input_cfg.toml do GameTank Emulator a partir do keymap.json (spec 010, plano D-05).

Uso: gerar_gametank_cfg.py [--keymap ports/config/keymap.json] [--saida ARQ]

O emulador le esse arquivo de $XDG_DATA_HOME/GameTank/Emulator/ (SDL_GetPrefPath). Os botoes
do aparelho chegam ao SDL2 (backend evdev) como teclas: KEY_A -> SDLK_a, KEY_UP -> SDLK_UP...
Controle do GameTank (jogador 1): direcoes, A, B, C e START. Mapa: A <- botao A (embaixo),
B <- botao B (direita), C <- botao X (esquerda), START <- START. SELECT, ALT e MENU ficam livres
(saida, volume e sleep sao do m17atalhos).
"""
import argparse
import json
import os
import sys

RAIZ = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))  # ports/x.py -> raiz do tutu8bits (spec 053)
ESC = 1 << 30   # SDLK_SCANCODE_MASK

# keycode Linux -> SDL_Keycode (SDL 2.28, tabela evdev -> scancode -> keycode)
SDLK = {
    30: ord("a"), 48: ord("b"), 45: ord("x"), 21: ord("y"), 38: ord("l"), 44: ord("z"),
    19: ord("r"), 46: ord("c"), 28: 13,                      # KEY_ENTER -> SDLK_RETURN
    54: 229 | ESC,                                            # KEY_RIGHTSHIFT -> SDLK_RSHIFT
    103: 82 | ESC, 108: 81 | ESC, 105: 80 | ESC, 106: 79 | ESC,   # setas
}
# botao do GameTank (ButtonId) <- acao do keymap.json
BOTOES = [(0, "UP"), (1, "DOWN"), (2, "LEFT"), (3, "RIGHT"), (4, "A"), (5, "B"), (6, "X"), (7, "START")]


def gerar(keymap):
    linhas = []
    for gt, acao in BOTOES:
        code = int(keymap[acao])
        if code not in SDLK:
            sys.exit(f"keycode {code} ({acao}) sem tecla SDL conhecida")
        linhas.append(f"    {{ gtButton = {gt}, key = {SDLK[code]}, type = 0 }}")
    return "input_bindings = [\n" + ",\n".join(linhas) + "\n]\nversion = 2\n"


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("--keymap", default=os.path.join(RAIZ, "ports", "config", "keymap.json"))
    ap.add_argument("--saida", default="-")
    a = ap.parse_args()
    txt = gerar(json.load(open(a.keymap)))
    if a.saida == "-":
        sys.stdout.write(txt)
    else:
        with open(a.saida, "w") as f:
            f.write(txt)


if __name__ == "__main__":
    main()
