#!/usr/bin/env python3
"""Gera a linha do gamecontrollerdb.txt (mapeamento SDL de game controller) do i2c-keys do M17
para o GameTank (spec 012, plano D-01/D-05).

Uso: gerar_gamecontrollerdb.py --controle ports/config/gametank_controle.json [--saida ARQ]
     gerar_gamecontrollerdb.py --guid GUID --nome NOME --layout layout.json
                               [--keymap ports/config/keymap.json] [--saida ARQ]

--controle le um JSON {"guid", "nome", "layout"} (chaves com "_" na frente sao comentarios): e o
dado medido no aparelho e versionado no repositorio.

O GameTank Emulator le a entrada do jogo pela API SDL_GameController; o i2c-keys do aparelho chega
como joystick comum (KB §11i) e o SDL so o entrega ao jogo com um mapeamento por GUID. Este script
monta esse mapeamento:

- O **keymap.json** diz quais controles existem e, por POSICAO (rotulo Xbox), a que elemento SDL do
  controller cada um corresponde: o botao de baixo (A) -> "a" (sul), o da direita (B) -> "b" (leste),
  o da esquerda (X) -> "x" (oeste), o de cima (Y) -> "y" (norte); UP/DOWN/LEFT/RIGHT -> dpad;
  START -> start; SELECT -> back. VOL+/VOL- nao tem elemento de controller (sao do m17atalhos).
- O **layout.json** diz, para cada controle, QUAL elemento fisico do joystick ele e (medido pela
  captura do spike 012): botao "bN", hat "hN.M", ou eixo "aN"/"+aN"/"-aN"/"aN~".

Saida: uma linha "GUID,NOME,elemento_sdl:fisico,...,platform:Linux," (formato do SDL2).
"""
import argparse
import json
import os
import re
import sys

RAIZ_REPO = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))  # ports/x.py -> raiz do tutu8bits (spec 053)

# acao do keymap -> elemento do SDL_GameController (por posicao/rotulo; spec 012, D-01)
ACAO_SDL = {
    "A": "a", "B": "b", "X": "x", "Y": "y",
    "UP": "dpup", "DOWN": "dpdown", "LEFT": "dpleft", "RIGHT": "dpright",
    "START": "start", "SELECT": "back",
    "L1": "leftshoulder", "R1": "rightshoulder",
    "L2": "lefttrigger", "R2": "righttrigger",
    "L3": "leftstick", "R3": "rightstick",
    # analogicos (spec 023): eixos do i2c-keys no key_mode 6; nao sao teclas, entao nao estao no keymap
    "LX": "leftx", "LY": "lefty", "RX": "rightx", "RY": "righty",
}
EIXOS = {"LX", "LY", "RX", "RY"}
# ordem de saida (estavel, legivel)
ORDEM = ["A", "B", "X", "Y", "UP", "DOWN", "LEFT", "RIGHT", "START", "SELECT",
         "L1", "R1", "L2", "R2", "L3", "R3", "LX", "LY", "RX", "RY"]
FISICO = re.compile(r"^(b\d+|h\d+\.\d+|[+-]?a\d+~?)$")
GUID_RE = re.compile(r"^[0-9a-fA-F]{32}$")


def gerar(guid, nome, layout, keymap=None):
    if not GUID_RE.match(guid):
        sys.exit(f"GUID invalido (esperado 32 digitos hex): {guid}")
    if "," in nome:
        sys.exit("o nome nao pode ter virgula")
    partes = [guid, nome]
    usados = 0
    for acao in ORDEM:
        if acao not in layout:
            continue
        if acao not in ACAO_SDL:
            sys.exit(f"controle sem elemento de game controller: {acao}")
        if keymap is not None and acao not in keymap and acao not in EIXOS:
            sys.exit(f"controle {acao} nao existe no keymap")
        fisico = str(layout[acao])
        if not FISICO.match(fisico):
            sys.exit(f"elemento fisico invalido para {acao}: {fisico} (use bN, hN.M ou [+-]aN[~])")
        partes.append(f"{ACAO_SDL[acao]}:{fisico}")
        usados += 1
    for acao in layout:
        if acao not in ACAO_SDL:
            sys.exit(f"controle desconhecido no layout: {acao}")
    if usados == 0:
        sys.exit("o layout nao mapeou nenhum controle")
    partes.append("platform:Linux")
    return ",".join(partes) + ",\n"


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("--controle", help='JSON {"guid", "nome", "layout"} medido no aparelho')
    ap.add_argument("--guid")
    ap.add_argument("--nome", default="i2c-keys")
    ap.add_argument("--layout", help="JSON {controle: elemento_fisico}")
    ap.add_argument("--keymap", default=os.path.join(RAIZ_REPO, "ports", "config", "keymap.json"))
    ap.add_argument("--saida", default="-")
    a = ap.parse_args()
    if a.controle:
        with open(a.controle) as f:
            c = json.load(f)
        guid, nome, layout = c.get("guid", ""), c.get("nome", a.nome), c.get("layout", {})
    elif a.guid and a.layout:
        guid, nome = a.guid, a.nome
        with open(a.layout) as f:
            layout = json.load(f)
    else:
        sys.exit("use --controle ARQ ou --guid GUID --layout ARQ")
    keymap = None
    if a.keymap and os.path.exists(a.keymap):
        with open(a.keymap) as f:
            keymap = json.load(f)
    txt = gerar(guid, nome, layout, keymap)
    if a.saida == "-":
        sys.stdout.write(txt)
    else:
        with open(a.saida, "w") as f:
            f.write(txt)


if __name__ == "__main__":
    main()
