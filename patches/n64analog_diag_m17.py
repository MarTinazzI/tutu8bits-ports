#!/usr/bin/env python3
# Licença: GPL-2.0 (o que este script altera e o parallel-n64) (spec 053)
"""Patch DIAGNOSTICO (spec 015, descartavel): loga os eixos crus do analogico no parallel_n64 para
descobrir se o RetroArch entrega o eixo ao core. ~1x/s no Control 0, via stderr (vai para o log do
jogo). Remover quando o analogico estiver resolvido. Uso: n64analog_diag_m17.py RAIZ_DO_FONTE.
(Precisa ser aplicado DENTRO da receita: o build.sh faz git checkout -f e reverte edicoes manuais.)
"""
import re, sys, os
raiz = sys.argv[1]
p = os.path.join(raiz, "mupen64plus-core/src/plugin/emulate_game_controller_via_libretro.c")
s = open(p).read()
if "M17_ANALOG" in s:
    print("n64analog_diag: ja aplicado"); sys.exit(0)
alvo = "   analog_scale(analogX, analogY, 80, &sx, &sy);\n   Keys->X_AXIS = sx;\n   Keys->Y_AXIS = sy;\n"
if alvo not in s:
    sys.exit("n64analog_diag: alvo nao encontrado (inputGetKeys_reuse)")
diag = alvo + (
    "   if (Control == 0) {\n"
    "      static int m17_diag_n = 0;\n"
    "      if ((m17_diag_n++ % 60) == 0) {\n"
    "         int16_t rx = input_cb(0, RETRO_DEVICE_ANALOG, RETRO_DEVICE_INDEX_ANALOG_RIGHT, RETRO_DEVICE_ID_ANALOG_X);\n"
    "         int16_t ry = input_cb(0, RETRO_DEVICE_ANALOG, RETRO_DEVICE_INDEX_ANALOG_RIGHT, RETRO_DEVICE_ID_ANALOG_Y);\n"
    "         fprintf(stderr, \"[M17_ANALOG] Lx=%d Ly=%d Rx=%d Ry=%d -> sx=%d sy=%d (dz=%d sens=%d)\\n\",\n"
    "                 (int)analogX, (int)analogY, (int)rx, (int)ry, (int)sx, (int)sy,\n"
    "                 astick_deadzone, astick_sensitivity);\n"
    "      }\n"
    "   }\n")
open(p, "w").write(s.replace(alvo, diag, 1))
print("n64analog_diag: aplicado em " + os.path.basename(p))
