#!/usr/bin/env bash
# Spec 040 (T05; CA-01, CA-04): o JFDuke3D do projeto no PC.
#   1. auditoria de ELF; sem OpenGL de PC; os patches conferidos no texto;
#   2. o duke3d no qemu-arm-static com o shareware 1.3d (baixar_conteudo.sh duke3d; um 7z, nomes em minusculas como
#      o motor procura no ext4), o duke3d.cfg do produto, o renderer do SDL (BUILD_USESDLRENDERER=1, como o lancar.sh),
#      rodando dentro da pasta de saves (como o lancar.sh) com os dados por -j: por roteiro de teclas (M17_ROTEIRO),
#      novo jogo -> Esc -> Save Game -> vaga 0 -> o teclado virtual abre com "E1 L1" -> START -> game0.sav com o nome;
#      UM SIGTERM -> rc 0, "[M17] saida", o duke3d.cfg regravado em 320x240 com os botoes do produto;
#   3. sem os dados: sai sozinho com erro, sem travar.
# Espera por condicao ("[M17] roteiro: fim"). Nada e gravado fora de .cache/emu/testes/jfduke3d.
set -uo pipefail
D=$(cd "$(dirname "$0")" && pwd)
. "$D/../../src/emu/ambiente.sh"
B="$EMU_CACHE/out/jfduke3d/duke3d"
Z="$EMU_CACHE/conteudo/duke3d/3dduke13_data.7z"
P="$EMU_RAIZ/ports/patches"
CFG="$EMU_RAIZ/ports/config/duke3d/duke3d.cfg"
T="$EMU_CACHE/testes/jfduke3d"
F=0
conta() { if [ "$1" -eq 0 ]; then echo "ok    $2"; else echo "FALHA $2"; F=$((F + 1)); fi; }
ulimit -c 0

rm -rf "$T"; mkdir -p "$T/libs" "$T/dados" "$T/saves/.jfduke3d"
cp "$EMU_CACHE/out/sdl2_projeto/libSDL2-2.0.so.0" "$T/libs/"

# --- 1. binario e patches
out=$("$D/../../src/emu/testes/auditar_elf.sh" "$B" "$T/libs"); r=$?
conta $r "auditoria de ELF: duke3d"; [ $r -eq 0 ] || echo "$out" | grep FALHA
! "$READELF" -d "$B" | grep -qiE 'NEEDED.*(X11|xcb|wayland|libGL\.so|gtk|vorbis|fluidsynth)'
conta $? "duke3d sem X11/OpenGL de PC/GTK/Vorbis/FluidSynth (renderer classico de software)"
grep -q '^+void m17_sair(void)$' "$P/jfduke3d-m17-01-sair.patch" && grep -q 'm17_sair();' "$P/jfduke3d-m17-01-sair.patch" \
  && grep -q '^+        ok = m17_teclado(m17_renderer(), "Nome do save", b, dalen);' "$P/jfduke3d-m17-02-teclado.patch" \
  && grep -q '^+GAMEOBJS+= $(SRC)/teclado.$o $(SRC)/teclado_sdl.$o' "$P/jfduke3d-m17-02-teclado.patch"
conta $? "patches: SDL_QUIT sai pela rotina do jogo, nome do save pelo teclado virtual, teclado no Makefile"

# --- 2. shareware no qemu
if [ ! -f "$Z" ] || ! echo "3fcdc3cb4c16e44a6a15f9a916ae9d2f131dc6297b324fbd656dd404f2050dec  $Z" | sha256sum --quiet -c 2>/dev/null; then
    conta 1 "shareware em $Z (rode: ports/baixar_conteudo.sh duke3d)"; echo "falhas: $F"; exit 1
fi
( cd "$T/dados" && 7z x -y "$Z" > /dev/null && for f in *; do mv "$f" "$(echo "$f" | tr 'A-Z' 'a-z')"; done )
[ -f "$T/dados/duke3d.grp" ]; conta $? "shareware extraido (7z; nomes em minusculas)"
if ! command -v qemu-arm-static > /dev/null; then conta 1 "qemu-arm-static"; echo "falhas: $F"; exit 1; fi
cp "$CFG" "$T/saves/.jfduke3d/duke3d.cfg"
printf '%s' '|||||{ESC}||{ESC}||{ENTER}||{ENTER}||{ENTER}|||||{ESC}||{DOWN}{ENTER}||{ENTER}||{ENTER}|||' > "$T/rot.txt"
printf 'S' > "$T/tec.txt"
( cd "$T/saves" && exec env HOME="$T/saves" BUILD_USESDLRENDERER=1 SDL_VIDEODRIVER=dummy SDL_RENDER_DRIVER=software \
    SDL_AUDIODRIVER=dummy LD_LIBRARY_PATH="$T/libs" M17_ROTEIRO="$T/rot.txt" M17_TECLADO_ROTEIRO="$T/tec.txt" \
    M17_TECLADO_TELA="$T/teclado.bmp" M17_TELA="$T/tela.bmp" \
    timeout -k 5 400 qemu-arm-static -L "$EMU_ROOTFS" "$B" -j"$T/dados" ) > "$T/log.txt" 2>&1 &
p=$!; i=0
while [ $i -lt 3500 ] && ! grep -q 'roteiro: fim' "$T/log.txt" 2>/dev/null && kill -0 $p 2>/dev/null; do sleep 0.1; i=$((i + 1)); done
sleep 3
case "$p" in ''|*[!0-9]*) conta 1 "PID valido"; echo "falhas: $F"; exit 1 ;; esac
kill -0 $p 2>/dev/null && kill -TERM $p 2>/dev/null
wait $p; r=$?
S=$(find "$T/saves" -name game0.sav | head -n 1)
grep -q 'Will use SDL renderer' "$T/log.txt" && grep -q '\[M17\] teclado: aberto \[E1 L1\]' "$T/log.txt" \
  && grep -q '\[M17\] teclado: ok \[E1 L1\]' "$T/log.txt" && [ -n "$S" ] && grep -aq 'E1 L1' "$S" \
  && [ "$(od -An -tu4 -j18 -N8 "$T/teclado.bmp" | tr -s ' ')" = " 480 272" ]
conta $? "qemu: renderer do SDL; Save Game -> teclado com o nome sugerido (E1 L1) -> START -> game0.sav com o nome"
C2="$T/saves/.jfduke3d/duke3d.cfg"
[ $r -eq 0 ] && grep -q '\[M17\] saida' "$T/log.txt" && grep -q '^ScreenWidth = 320$' "$C2" && grep -q '^ScreenHeight = 240$' "$C2" \
  && grep -q '^JoystickButton0 = "Jump"$' "$C2" && grep -q '^JoystickButton1 = "Crouch"$' "$C2" && grep -q '^JoystickButton2 = "Open"$' "$C2" \
  && grep -q '^JoystickButton7 = "AutoRun"$' "$C2" && grep -q '^JoystickDigitalAxes4_1 = ""$' "$C2" \
  && grep -q '^JoystickDigitalAxes5_1 = "Fire"$' "$C2" && grep -q '^RunMode = 1$' "$C2"
conta $? "qemu: um SIGTERM fecha com rc 0, [M17] saida e o duke3d.cfg regravado com as chaves do produto (043: A pula, B agacha, X abre, L3 AutoRun) (rc=$r)"

# --- 3. sem os dados: erro, sem travar
mkdir -p "$T/vazio"
( cd "$T/vazio" && exec env HOME="$T/vazio" SDL_VIDEODRIVER=dummy SDL_RENDER_DRIVER=software SDL_AUDIODRIVER=dummy \
    LD_LIBRARY_PATH="$T/libs" timeout -k 5 120 qemu-arm-static -L "$EMU_ROOTFS" "$B" -j"$T/vazio" ) > "$T/vazio.log" 2>&1
r=$?
[ $r -ne 0 ] && [ $r -ne 124 ] && [ $r -ne 137 ]
conta $? "sem os dados: sai sozinho com erro (rc=$r), sem travar"

echo "falhas: $F"
[ "$F" -eq 0 ]
