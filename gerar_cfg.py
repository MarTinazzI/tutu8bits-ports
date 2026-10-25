#!/usr/bin/env python3
"""Gera o retroarch.cfg do M17 (spec 009, plano D-07/D-10).

Uso: gerar_cfg.py [--keymap ports/config/keymap.json] [--raiz /sdcard/m17emu] [--saida ARQ]

- Opcoes fixas: ports/config/retroarch_base.cfg (@RAIZ@ -> --raiz).
- Botoes do jogo pelo layout do keymap.json, POR POSICAO no RetroPad: o botao de baixo
  (rotulo A) e o B do RetroPad, o da direita (B) e o A, o da esquerda (X) e o Y, o de
  cima (Y) e o X - o jogo de SNES pede "B" e o jogador aperta o de baixo.
- Atalhos: o ALT (VOL-, input_enable_hotkey), o MENU (VOL+, input_menu_toggle) e, com o ALT
  segurado, A = salvar estado e B = carregar estado (mantenedor, 2026-10-05), R1/L1 = proximo/
  anterior slot e Y = captura de tela (spec 026, D-08); todos os outros
  atalhos de teclado do RetroArch ficam "nul" (os padroes "l", "r", "f"... coincidem com botoes
  do aparelho). Volume, brilho, sleep e saida sao do m17atalhos.
"""
import argparse
import json
import os
import sys

RAIZ_REPO = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))  # ports/x.py -> raiz do tutu8bits (spec 053)

# keycode Linux -> nome de tecla do RetroArch (input/input_keymaps.c, v1.22.2), para os
# keycodes que o aparelho emite (KB 7.1). BTN_* (L3/R3 = 314/315) nao sao teclas de teclado.
NOME_TECLA = {
    19: "r", 21: "y", 28: "enter", 30: "a", 38: "l", 44: "z", 45: "x", 46: "c", 48: "b",
    54: "rshift", 103: "up", 105: "left", 106: "right", 108: "down",
    114: "volumedown", 115: "volumeup",
}

# botao do RetroPad (input_player1_<x>) <- acao logica do keymap.json
RETROPAD = [
    ("b", "A"), ("a", "B"), ("y", "X"), ("x", "Y"),
    ("l", "L1"), ("r", "R1"), ("l2", "L2"), ("r2", "R2"), ("l3", "L3"), ("r3", "R3"),
    ("select", "SELECT"), ("start", "START"),
    ("up", "UP"), ("down", "DOWN"), ("left", "LEFT"), ("right", "RIGHT"),
]

# Atalhos do RetroArch 1.22.2 (DECLARE_META_BIND em configuration.c)
ATALHOS = (
    "enable_hotkey menu_toggle exit_emulator close_content reset toggle_fast_forward "
    "hold_fast_forward toggle_slowmotion hold_slowmotion rewind pause_toggle frame_advance "
    "audio_mute volume_up volume_down load_state save_state state_slot_increase "
    "state_slot_decrease play_replay record_replay halt_replay save_replay_checkpoint "
    "prev_replay_checkpoint next_replay_checkpoint replay_slot_increase replay_slot_decrease "
    "disk_eject_toggle disk_next disk_prev shader_toggle shader_hold shader_next shader_prev "
    "cheat_toggle cheat_index_plus cheat_index_minus screenshot recording_toggle "
    "streaming_toggle turbo_fire_toggle grab_mouse_toggle game_focus_toggle toggle_fullscreen "
    "desktop_menu_toggle toggle_vrr_runloop runahead_toggle preempt_toggle fps_toggle "
    "toggle_statistics ai_service netplay_ping_toggle netplay_host_toggle netplay_game_watch "
    "netplay_player_chat netplay_fade_chat_toggle overlay_next osk_toggle"
).split()


def nome(keymap, acao):
    code = keymap.get(acao)
    if code is None:
        sys.exit(f"keymap sem a acao {acao}")
    return NOME_TECLA.get(int(code), "nul")


def gerar(keymap, raiz):
    base = open(os.path.join(RAIZ_REPO, "ports", "config", "retroarch_base.cfg")).read()
    linhas = [base.replace("@RAIZ@", raiz).rstrip("\n"), "",
              "# --- Botoes (gerados de ports/config/keymap.json por ports/gerar_cfg.py) ---"]
    for rp, acao in RETROPAD:
        linhas.append(f'input_player1_{rp} = "{nome(keymap, acao)}"')
    linhas.append('input_player1_turbo = "nul"')
    # Analogico (spec 015 / B-13): o i2c-keys declara eixos 0,1,2,5 (0-255, centro 128) e no
    # key_mode 6 eles viram valores reais. Sem estes bindings o RetroArch nao entrega o eixo ao core
    # (os cores de N64 liam 0). Stick ESQUERDO = eixos 0/1 (a confirmar pela captura do spike 015).
    linhas.append("# --- Analogico esquerdo (eixos do i2c-keys; spec 015/B-13) ---")
    linhas.append('input_player1_l_x_plus_axis = "+0"')
    linhas.append('input_player1_l_x_minus_axis = "-0"')
    linhas.append('input_player1_l_y_plus_axis = "+1"')
    linhas.append('input_player1_l_y_minus_axis = "-1"')
    # Stick direito = eixos 2/5 (captura do spike 015). O parallel_n64 mapeia o analogico DIREITO do
    # RetroPad nos C-buttons do N64; estes bindings fazem o stick direito fisico chegar la.
    linhas.append("# --- Analogico direito -> C-buttons do N64 (eixos 2/5; spec 015) ---")
    linhas.append('input_player1_r_x_plus_axis = "+2"')
    linhas.append('input_player1_r_x_minus_axis = "-2"')
    linhas.append('input_player1_r_y_plus_axis = "+5"')
    linhas.append('input_player1_r_y_minus_axis = "-5"')
    linhas.append("# --- Atalhos: ALT, MENU e (com ALT) A salva / B carrega o estado, R1/L1 slot, Y captura; o resto desligado ---")
    for a in ATALHOS:
        valor = "nul"
        if a == "enable_hotkey":
            valor = nome(keymap, "VOL-")
        elif a == "menu_toggle":
            valor = nome(keymap, "VOL+")
        elif a == "save_state":
            valor = nome(keymap, "A")
        elif a == "load_state":
            valor = nome(keymap, "B")
        elif a == "state_slot_increase":      # spec 026, D-08
            valor = nome(keymap, "R1")
        elif a == "state_slot_decrease":
            valor = nome(keymap, "L1")
        elif a == "screenshot":
            valor = nome(keymap, "Y")
        linhas.append(f'input_{a} = "{valor}"')
    return "\n".join(linhas) + "\n"


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("--keymap", default=os.path.join(RAIZ_REPO, "ports", "config", "keymap.json"))
    ap.add_argument("--raiz", default="/sdcard/m17emu")
    ap.add_argument("--saida", default="-")
    a = ap.parse_args()
    keymap = json.load(open(a.keymap))
    cfg = gerar(keymap, a.raiz.rstrip("/"))
    if a.saida == "-":
        sys.stdout.write(cfg)
    else:
        with open(a.saida, "w") as f:
            f.write(cfg)


if __name__ == "__main__":
    main()
