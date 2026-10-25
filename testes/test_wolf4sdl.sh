#!/usr/bin/env bash
# Spec 037 (T05; CA-01, CA-04): o Wolf4SDL do projeto no PC.
#   1. auditoria de ELF dos tres binarios (wolf3d, wolf3d-sw, spear); os patches conferidos no texto;
#   2. o wolf3d-sw no qemu-arm-static com o shareware 1.4 (baixar_conteudo.sh wolf3d; os nomes em minusculas, como
#      o motor procura), video/audio dummy, por roteiro de teclas (M17_ROTEIRO): novo jogo -> Esc -> Save Game ->
#      vaga 0 -> o teclado virtual abre com "E1 F1" -> START (M17_TECLADO_ROTEIRO) -> savegam0.wl1; UM SIGTERM ->
#      rc 0, "[M17] saida" e o config.wl1 gravado no --configdir;
#   3. o wolf3d e o spear sem os dados: saem sozinhos com erro, sem travar.
# Espera por condicao ("[M17] roteiro: fim" no log). Nada e gravado fora de .cache/emu/testes/wolf4sdl.
set -uo pipefail
D=$(cd "$(dirname "$0")" && pwd)
. "$D/../../src/emu/ambiente.sh"
O="$EMU_CACHE/out/wolf4sdl"
ZIP="$EMU_CACHE/conteudo/wolf3d/wolf3d14.zip"
P="$EMU_RAIZ/ports/patches"
T="$EMU_CACHE/testes/wolf4sdl"
F=0
conta() { if [ "$1" -eq 0 ]; then echo "ok    $2"; else echo "FALHA $2"; F=$((F + 1)); fi; }
ulimit -c 0

rm -rf "$T"; mkdir -p "$T/libs" "$T/dados" "$T/cfg"
cp "$EMU_CACHE/out/sdl2_projeto/libSDL2-2.0.so.0" "$EMU_CACHE/out/sdl2_mixer/libSDL2_mixer-2.0.so.0" "$T/libs/"

# --- 1. binarios e patches
for m in wolf3d wolf3d-sw spear; do
    out=$("$D/../../src/emu/testes/auditar_elf.sh" "$O/$m" "$T/libs"); r=$?
    conta $r "auditoria de ELF: $m"; [ $r -eq 0 ] || echo "$out" | grep FALHA
done
! "$READELF" -d "$O/wolf3d" | grep -qiE 'NEEDED.*(X11|xcb|wayland|libGL\.so)'
conta $? "wolf3d sem X11/OpenGL de PC"
grep -q '^+        fprintf (stderr, "\[M17\] saida\\n");' "$P/wolf4sdl-m17-01-sair.patch" \
  && grep -q '^+        static const int fisico\[\] = { 6, 11, 9, 4, 10, 8, 7, 3, 5 };' "$P/wolf4sdl-m17-02-controles.patch" \
  && grep -q '^+    buttonstate\[bt_run\] = !buttonstate\[bt_run\];' "$P/wolf4sdl-m17-02-controles.patch" \
  && grep -q '^+		ok = m17_teclado (renderer, m17_titulo ? m17_titulo : "Texto", b, maxchars);' "$P/wolf4sdl-m17-03-teclado.patch" \
  && grep -q '^+                    snprintf (input, sizeof(input), "E%d F%d", gamestate.episode + 1, gamestate.mapon + 1);' "$P/wolf4sdl-m17-03-teclado.patch" \
  && grep -q '^+            m17_teclado_nome (Scores\[n\].name, MaxHighName + 1);' "$P/wolf4sdl-m17-03-teclado.patch"
conta $? "patches: [M17] saida, botoes do aparelho, sempre correndo, teclado virtual, nome sugerido do save e do placar (042)"
# spec 043 (T04, D-06): patch 04 — X usa, L3 (fisico 1) liga/desliga o andar devagar, sensibilidade do giro
grep -q '^+        static const int fisico\[\] = { 6, 11, 9, 4, 10, 1, 7, 3, 5 };' "$P/wolf4sdl-m17-04-botoes.patch" \
  && grep -q '^+    bt_nobutton, bt_nobutton, bt_use, bt_nobutton, bt_attack, bt_run, bt_prevweapon, bt_nextweapon,' "$P/wolf4sdl-m17-04-botoes.patch" \
  && grep -q '^+            m17_devagar = !m17_devagar;' "$P/wolf4sdl-m17-04-botoes.patch" \
  && grep -q '^+        const char \*e = getenv ("M17_MIRA_SENS");' "$P/wolf4sdl-m17-04-botoes.patch"
conta $? "043: patch 04 (X usa, L3 liga/desliga o andar devagar, M17_MIRA_SENS no giro)"

# --- 2. shareware no qemu
if [ ! -f "$ZIP" ] || ! echo "23efc1839b9bd91de43fbd036e55aca94271293dd46d176dafd40378b2f94108  $ZIP" | sha256sum --quiet -c 2>/dev/null; then
    conta 1 "shareware em $ZIP (rode: ports/baixar_conteudo.sh wolf3d)"; echo "falhas: $F"; exit 1
fi
python3 -I -c 'import sys, zipfile, os
z = zipfile.ZipFile(sys.argv[1])
for n in z.namelist():
    if not n.endswith("/"):
        open(os.path.join(sys.argv[2], os.path.basename(n).lower()), "wb").write(z.read(n))' "$ZIP" "$T/dados"
conta $? "shareware extraido (nomes em minusculas: o motor procura vswap.wl1)"
if ! command -v qemu-arm-static > /dev/null; then conta 1 "qemu-arm-static"; echo "falhas: $F"; exit 1; fi
# a sequencia de teclas: tela de entrada, titulo, menu (o cursor comeca em "Read This!": 5 x cima = New Game),
# episodio, dificuldade, jogo; Esc, Save Game (4 x baixo a partir de New Game), vaga 0
printf '%s' '||{ENTER}|||{ENTER}||{ENTER}||{UP}{UP}{UP}{UP}{UP}{ENTER}||{ENTER}||{ENTER}|||||{ESC}||{DOWN}{DOWN}{DOWN}{DOWN}{ENTER}||{ENTER}||||' > "$T/rot.txt"
printf 'S' > "$T/tec.txt"
( cd "$T/dados" && exec env SDL_VIDEODRIVER=dummy SDL_RENDER_DRIVER=software SDL_AUDIODRIVER=dummy \
    LD_LIBRARY_PATH="$T/libs" M17_ROTEIRO="$T/rot.txt" M17_TECLADO_ROTEIRO="$T/tec.txt" M17_TECLADO_TELA="$T/teclado.bmp" \
    M17_TELA="$T/tela.bmp" timeout -k 5 300 qemu-arm-static -L "$EMU_ROOTFS" "$O/wolf3d-sw" --configdir "$T/cfg" \
    --res 320 240 ) > "$T/log.txt" 2>&1 &
p=$!; i=0
while [ $i -lt 2500 ] && ! grep -q 'roteiro: fim' "$T/log.txt" 2>/dev/null && kill -0 $p 2>/dev/null; do sleep 0.1; i=$((i + 1)); done
sleep 2
case "$p" in ''|*[!0-9]*) conta 1 "PID valido"; echo "falhas: $F"; exit 1 ;; esac
kill -0 $p 2>/dev/null && kill -TERM $p 2>/dev/null
wait $p; r=$?
grep -q '\[M17\] teclado: aberto \[E1 F1\]' "$T/log.txt" && grep -q '\[M17\] teclado: ok \[E1 F1\]' "$T/log.txt" \
  && [ -s "$T/cfg/savegam0.wl1" ] && [ "$(head -c 5 "$T/cfg/savegam0.wl1")" = "E1 F1" ] \
  && [ "$(od -An -tu4 -j18 -N8 "$T/teclado.bmp" | tr -s ' ')" = " 480 272" ]
conta $? "qemu: Save Game -> teclado virtual com o nome sugerido (E1 F1) -> START -> savegam0.wl1 com o nome"
[ $r -eq 0 ] && grep -q '\[M17\] saida' "$T/log.txt" && [ -s "$T/cfg/config.wl1" ]
conta $? "qemu: um SIGTERM fecha com rc 0, [M17] saida e o config.wl1 gravado (rc=$r)"

# --- 3. sem os dados: erro, sem travar
for m in wolf3d spear; do
    mkdir -p "$T/vazio_$m"
    ( cd "$T/vazio_$m" && exec env SDL_VIDEODRIVER=dummy SDL_RENDER_DRIVER=software SDL_AUDIODRIVER=dummy \
        LD_LIBRARY_PATH="$T/libs" timeout -k 5 120 qemu-arm-static -L "$EMU_ROOTFS" "$O/$m" --configdir "$T/vazio_$m" ) \
        > "$T/vazio_$m.log" 2>&1
    r=$?
    [ $r -ne 0 ] && [ $r -ne 124 ] && [ $r -ne 137 ]   # a mensagem vai para uma caixa do SDL, nao para o log
    conta $? "$m sem os dados: sai sozinho com erro (rc=$r), sem travar"
done

echo "falhas: $F"
[ "$F" -eq 0 ]
