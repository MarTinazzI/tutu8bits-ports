#!/usr/bin/env bash
# Spec 050 (CA-01, CA-03 a CA-06; T02-T05): o Quake nativo (TyrQuake original sobre o SDL2 do
# projeto) no PC.
#   1. auditoria de ELF; sem X11/OpenGL de PC; os patches conferidos no texto;
#   2. o tyr-quake no qemu-arm-static com o LibreQuake lite (o mesmo zip do pacote), heap de 32 MB, janela de 480x272
#      pelo video.cfg (plano D-07): +map start; o roteiro (M17_ROTEIRO) so comeca com o mapa ativo e grava a tela
#      (M17_TELA) -> 480x272, nao uniforme; UM SIGTERM -> rc 0 e o config.cfg gravado;
#      com o config.cfg do produto, cada botao do controle da a acao da tabela (RF-03; "[M17] botao X -> bind"), no
#      menu o D-pad vira seta e o B o ESC, o L3 alterna andar devagar; o analogico direito gira 180 graus/s no 5, 36 no
#      1 e 360 no 10, e o M17_MIRA_INV inverte o olhar (RF-04); a musica do proprio motor (music/trackNN.ogg do
#      LibreQuake) toca e o audio gravado (driver disk do SDL) nao e mudo; sem a pasta music/, o log diz e o jogo segue
#      (RF-07); a pasta do usuario e o M17_USERDIR (saves e config em <pasta>/id1/, como o nucleo gravava; nada no
#      HOME) e o save gravado pelo nucleo libretro (dados/quake/s0_nucleo.sav, T05) carrega no mapa dele (RF-06); ao
#      sair, "[M17] quadros=" (o formato do RetroArch, para o diagnostico) e depois "[M17] saida"; os botoes sem acao nao
#      escrevem "is unbound" (patch 07); a textura fica num formato do renderer, tambem com a tela do aparelho simulada
#      (RGBX8888), e o quadro desenhado bate com o de 8 bits (patch 06, D-14);
#   3. sem os dados: sai sozinho com erro, sem travar, e sem nenhuma linha do roteiro (sem as variaveis nada muda).
# Espera por condicao ("[M17] roteiro: fim"). Nada e gravado fora de .cache/emu/testes/tyrquake_sdl.
set -uo pipefail
D=$(cd "$(dirname "$0")" && pwd)
. "$D/../../src/emu/ambiente.sh"
B="$EMU_CACHE/out/tyrquake_sdl/tyr-quake"
Z="$EMU_CACHE/conteudo/librequake/lite.zip"
P="$EMU_RAIZ/ports/patches"
T="$EMU_CACHE/testes/tyrquake_sdl"
U="$T/saves/librequake"   # o M17_USERDIR: saves/jogos/quake/<jogo> no cartao
SAV="$D/dados/quake/s0_nucleo.sav"
CFG="$EMU_RAIZ/ports/config/tyrquake/config.cfg"
F=0
conta() { if [ "$1" -eq 0 ]; then echo "ok    $2"; else echo "FALHA $2"; F=$((F + 1)); fi; }
ulimit -c 0

rm -rf "$T"; mkdir -p "$T/libs" "$T/dados" "$T/home" "$U/id1" "$T/telas"
cp "$EMU_CACHE/out/sdl2_projeto/libSDL2-2.0.so.0" "$T/libs/"

# --- 1. binario e patches
out=$("$D/../../src/emu/testes/auditar_elf.sh" "$B" "$T/libs"); r=$?
conta $r "auditoria de ELF: tyr-quake"; [ $r -eq 0 ] || echo "$out" | grep FALHA
! "$READELF" -d "$B" | grep -qiE 'NEEDED.*(X11|xcb|wayland|libGL\.so|pulse|asound)'
conta $? "tyr-quake sem X11/OpenGL de PC/PulseAudio/ALSA direto (vídeo, som e entrada pelo SDL2)"
grep -q '^+        mode->resolution.width = vid_render_resolution_width.value;$' "$P/tyrquake_sdl-m17-01-resolucao.patch" \
  && grep -q '^+    M17_Roteiro();$' "$P/tyrquake_sdl-m17-02-testes.patch" \
  && grep -q '^+SW_OBJS += m17_testes.o$' "$P/tyrquake_sdl-m17-02-testes.patch" \
  && grep -q '^+    M17_ControleMove(cmd);$' "$P/tyrquake_sdl-m17-03-controle.patch" \
  && grep -q '^+    {"PAD_A", K_AUX1},' "$P/tyrquake_sdl-m17-03-controle.patch"
conta $? "patches: resolucao interna na janela (01); roteiro (02); controle no IN_Move e teclas PAD_* (03)"

# --- 2. LibreQuake no qemu
if [ ! -f "$Z" ]; then conta 1 "LibreQuake em $Z (rode: ports/baixar_conteudo.sh librequake)"; echo "falhas: $F"; exit 1; fi
python3 -I -c '
import os, sys, zipfile
z = zipfile.ZipFile(sys.argv[1])
for n in z.namelist():
    if n.endswith("/") or "/" not in n: continue
    d = os.path.join(sys.argv[2], n.split("/", 1)[1]); os.makedirs(os.path.dirname(d), exist_ok=True)
    open(d, "wb").write(z.read(n))' "$Z" "$T/dados"
[ -f "$T/dados/id1/pak0.pak" ]; conta $? "LibreQuake lite extraido (id1/pak0.pak)"
if ! command -v qemu-arm-static > /dev/null; then conta 1 "qemu-arm-static"; echo "falhas: $F"; exit 1; fi
printf 'vid_fullscreen "0"\nvid_bpp "32"\nvid_width "480"\nvid_height "272"\nvid_render_resolution_scale "1"\n' \
    > "$U/id1/video.cfg"
cp "$CFG" "$U/id1/config.cfg"
# rodar NOME ROTEIRO [VAR=valor...]: uma partida do start com o roteiro; espera o "roteiro: fim" e manda UM SIGTERM.
# Log em $T/NOME.log; rc em RC.
rodar() {
    _rd_n=$1; _rd_r=$2; shift 2
    printf '%s' "$_rd_r" > "$T/$_rd_n.rot"
    ( cd "$T/home" && exec env HOME="$T/home" SDL_VIDEODRIVER=dummy SDL_RENDER_DRIVER=software SDL_AUDIODRIVER=dummy \
        LD_LIBRARY_PATH="$T/libs" M17_USERDIR="$U" M17_ROTEIRO="$T/$_rd_n.rot" M17_TELA="$T/telas" "$@" \
        timeout -k 5 400 qemu-arm-static -L "$EMU_ROOTFS" "$B" -basedir "${BASE:-$T/dados}" -mem 32 +map start ) > "$T/$_rd_n.log" 2>&1 &
    _rd_p=$!; _rd_i=0
    while [ $_rd_i -lt 3500 ] && ! grep -q 'roteiro: fim' "$T/$_rd_n.log" 2>/dev/null && kill -0 $_rd_p 2>/dev/null; do
        sleep 0.1; _rd_i=$((_rd_i + 1))
    done
    case "$_rd_p" in ''|*[!0-9]*) RC=999; return ;; esac
    kill -0 $_rd_p 2>/dev/null && kill -TERM $_rd_p 2>/dev/null
    wait $_rd_p; RC=$?
}
# graus/s da linha N de "[M17] mira:" (1 = a primeira) no log
taxa() { sed -n 's/^\[M17\] mira: .*(\([0-9.]*\) graus\/s)$/\1/p' "$T/$1.log" | sed -n "$2p"; }
sinal() { sed -n "s/^\[M17\] mira: yaw=\([-0-9.]*\) pitch=\([-0-9.]*\) .*/\1 \2/p" "$T/$1.log" | sed -n "$2p"; }
perto() { awk -v a="$1" -v b="$2" 'BEGIN { exit !(a != "" && a >= b * 0.98 && a <= b * 1.02) }'; }
MIRA='{EIXO 2 32767}|{EIXO 2 0}{EIXO 3 -32767}|{EIXO 3 0}|'

rodar mapa "{TELA mapa}{A}{B}{X}{Y}{L1}{R1}{L2}{R2}{L3}{R3}{SELECT}{DUP}{DDOWN}{DLEFT}{DRIGHT}{L3}{START}{DDOWN}{B}$MIRA"
grep -q '\[M17\] roteiro: mapa ativo' "$T/mapa.log" && [ -f "$T/telas/mapa.bmp" ] \
  && python3 -I -c '
import sys
from PIL import Image
i = Image.open(sys.argv[1])
assert i.size == (480, 272), i.size
assert len(i.convert("RGB").getcolors(1 << 20)) > 32, "tela quase uniforme"' "$T/telas/mapa.bmp"
conta $? "qemu: +map start com 32 MB; roteiro so com o mapa ativo; tela gravada em 480x272, nao uniforme"
[ $RC -eq 0 ] && [ -s "$U/id1/config.cfg" ] && grep -q '^bind "PAD_A" "+jump"' "$U/id1/config.cfg" && [ -z "$(ls -A "$T/home")" ]
conta $? "qemu: um SIGTERM fecha com rc 0 e regrava o config.cfg no M17_USERDIR/id1 com os binds do produto, nada no HOME (rc=$RC)"
_q=$(grep -n '^\[M17\] quadros=' "$T/mapa.log" | cut -d: -f1); _s=$(grep -n '^\[M17\] saida$' "$T/mapa.log" | cut -d: -f1)
_d=$(sed -n 's/^\[M17\] quadros=[0-9]* desenhados=\([0-9]*\) .*/\1/p' "$T/mapa.log")
[ -n "$_q" ] && [ -n "$_s" ] && [ "$_q" -lt "$_s" ] && [ "${_d:-0}" -gt 0 ] \
  && grep -q '^\[M17\] quadros=[0-9]* desenhados=[0-9]* segundos=[0-9.]* fps_medio=[0-9.]* fps_desenhado=[0-9.]*$' "$T/mapa.log"
conta $? "qemu: ao sair, [M17] quadros= no formato do RetroArch ($_d desenhados) e depois [M17] saida"
esperado='A -> +jump
B -> +movedown
X -> (nada)
Y -> (nada)
L1 -> impulse 12
R1 -> impulse 10
L2 -> (nada)
R2 -> +attack
L3 -> m17_devagar
R3 -> (nada)
SELECT -> +showscores
CIMA -> +forward
BAIXO -> +back
ESQ -> +left
DIR -> +right
L3 -> m17_devagar
START -> ESCAPE
BAIXO -> DOWNARROW
B -> ESCAPE'
[ "$(sed -n 's/^\[M17\] botao //p' "$T/mapa.log")" = "$esperado" ]
conta $? "qemu: cada botao da a acao da tabela (043/RF-03); START abre o menu; no menu o D-pad e seta e o B volta" \
    || sed -n 's/^\[M17\] botao //p' "$T/mapa.log"
grep -q '^\[M17\] devagar: ligado (cl_forwardspeed 200)$' "$T/mapa.log" \
  && grep -q '^\[M17\] devagar: desligado (cl_forwardspeed 400)$' "$T/mapa.log"
conta $? "qemu: o L3 liga e desliga o andar devagar"
! grep -q 'is unbound' "$T/mapa.log"
conta $? "qemu: X, Y, L2 e R3 (sem acao) nao escrevem 'is unbound' na tela (patch 07, D-15)"
perto "$(taxa mapa 1)" 180 && perto "$(taxa mapa 2)" 180
conta $? "qemu: mira 5 = 180 graus/s no maximo (o sensitivity 3 do nucleo a 60 quadros) ($(taxa mapa 1), $(taxa mapa 2))"
set -- $(sinal mapa 1); _y1=$1; set -- $(sinal mapa 2); _p2=$2
rodar mira "$MIRA" M17_MIRA_SENS=1; _t1=$(taxa mira 1)
rodar mira10 "$MIRA" M17_MIRA_SENS=10 M17_MIRA_INV=1; _t10=$(taxa mira10 1)
set -- $(sinal mira10 2); _pi=$2
perto "$_t1" 36 && perto "$_t10" 360
conta $? "qemu: M17_MIRA_SENS 1 = 36 e 10 = 360 graus/s ($_t1, $_t10)"
awk -v y="$_y1" -v p="$_p2" -v q="$_pi" 'BEGIN { exit !(y > 0 && p < 0 && q > 0) }'
conta $? "qemu: direita gira; para cima olha para cima (pitch $_p2); com M17_MIRA_INV=1, para baixo (pitch $_pi)"

# textura (plano D-14, patch 06): no aparelho a tela diz RGBX8888, que o renderer nao aceita (o SDL convertia o quadro
# inteiro a cada quadro). Com a tela do PC e com a do aparelho simulada (M17_FORMATO_TELA), a textura fica num formato
# do renderer e o quadro desenhado bate com o de 8 bits pela paleta (canais na ordem certa)
rodar cor1 "{TELAR cor1}"
rodar cor2 "{TELAR cor2}" M17_FORMATO_TELA=RGBX8888
grep -q '^\[M17\] textura: SDL_PIXELFORMAT_RGB888 (renderer software; a tela diz SDL_PIXELFORMAT_RGB888)$' "$T/cor1.log" \
  && grep -q '^\[M17\] textura: SDL_PIXELFORMAT_RGB888 (renderer software; a tela diz SDL_PIXELFORMAT_RGBX8888)$' "$T/cor2.log" \
  && python3 -I -c '
import sys
from PIL import Image
for n in sys.argv[2:]:
    a = Image.open(sys.argv[1] + "/" + n + "_8.bmp").convert("RGB"); b = Image.open(sys.argv[1] + "/" + n + ".bmp").convert("RGB")
    assert a.size == b.size == (480, 272), (n, a.size, b.size)
    pa, pb = a.load(), b.load(); soma = 0; npx = 0
    for y in range(0, 272, 2):
        for x in range(0, 480, 2):
            soma += sum(abs(pa[x, y][c] - pb[x, y][c]) for c in range(3)); npx += 1
    m = soma / (3.0 * npx)
    print(n, "diferenca media", round(m, 2))
    assert m < 4, (n, m)' "$T/telas" cor1 cor2
conta $? "qemu: textura num formato do renderer (RGB888) com a tela do PC e com a do aparelho (RGBX8888); o quadro desenhado bate com o de 8 bits"

# musica (plano D-06: a do proprio motor, snd_music.c): com o LibreQuake, a faixa do start toca; o som gravado em
# arquivo pelo driver disk do SDL tem volume (RMS de cada um dos 3 ultimos segundos, ja com o mapa ativo; os primeiros
# sao a abertura, em silencio)
rodar som '|||{R2}|||' SDL_AUDIODRIVER=disk SDL_DISKAUDIOFILE="$T/som.raw"
_mus=$(sed -n 's/^\[M17\] musica: //p' "$T/som.log" | head -n 1)
_rms=$(python3 -I -c '
import array, math, sys
a = array.array("h"); a.frombytes(open(sys.argv[1], "rb").read())
s = 48000 * 2
n = len(a) // s
print(min(int(math.sqrt(sum(x * x for x in a[i * s:(i + 1) * s]) / s)) for i in range(n - 3, n)) if n >= 4 else 0)' "$T/som.raw" 2>/dev/null)
[ $RC -eq 0 ] && [ "$_mus" = track02.ogg ] && [ "${_rms:-0}" -gt 500 ]
conta $? "qemu: musica do motor (musica: $_mus) e som gravado nao mudo (RMS minimo nos 3 ultimos segundos: ${_rms:-?})"
mkdir -p "$T/dados_sem/id1"; ln -sf "$T/dados/id1/pak0.pak" "$T/dados/id1/pak1.pak" "$T/dados_sem/id1/"
BASE="$T/dados_sem" rodar semmus '{TELA semmus}'
[ $RC -eq 0 ] && grep -q '^\[M17\] musica: sem music/track02$' "$T/semmus.log" && [ -f "$T/telas/semmus.bmp" ]
conta $? "qemu: sem a pasta music/, o log diz \"sem music/track02\" e o jogo segue (rc=$RC)"

# o save do nucleo libretro (T05: gravado pelo tyrquake_libretro no qemu, em <savefile_directory>/id1/s0.sav, a mesma
# pasta do M17_USERDIR) carrega no nativo
cp "$SAV" "$U/id1/s0.sav"
rodar save '{CMD load s0}||{TELA carregado}{CMD save s1}|'
[ $RC -eq 0 ] && grep -q "^Loading game from $U/id1/s0.sav" "$T/save.log" && ! grep -qi 'savegame is version\|couldn.t load map' "$T/save.log" \
  && [ -f "$T/telas/carregado.bmp" ] && [ -s "$U/id1/s1.sav" ] && sed -n 2p "$U/id1/s1.sav" | grep -q '^Tainted.Tech.Threshold' 
conta $? "qemu: o save do nucleo (s0) carrega do M17_USERDIR/id1 e o jogo segue (s1 gravado no mesmo mapa)"

# --- 3. sem os dados: erro, sem travar; sem as variaveis, nada do roteiro
mkdir -p "$T/vazio"
( cd "$T/vazio" && exec env HOME="$T/vazio" SDL_VIDEODRIVER=dummy SDL_RENDER_DRIVER=software SDL_AUDIODRIVER=dummy \
    LD_LIBRARY_PATH="$T/libs" timeout -k 5 120 qemu-arm-static -L "$EMU_ROOTFS" "$B" -basedir "$T/vazio" -mem 32 ) \
    > "$T/vazio.log" 2>&1
r=$?
[ $r -ne 0 ] && [ $r -ne 124 ] && [ $r -ne 137 ] && ! grep -q '\[M17\] roteiro' "$T/vazio.log"
conta $? "sem os dados: sai sozinho com erro (rc=$r), sem travar e sem linhas do roteiro"

echo "falhas: $F"
[ "$F" -eq 0 ]
