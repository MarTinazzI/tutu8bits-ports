#!/usr/bin/env bash
# Spec 047 (T03; CA-01, RF-01, RF-04, RF-08, RF-12): o GNU FreeDink da receita (ports/receitas/freedink.sh) no
# qemu-arm-static, com a libSDL2 e as SDL2_mixer/image/ttf/gfx do projeto, desenho por software (-S, plano D-08) e os
# dados do freedink-data:
#   1. auditoria de ELF do motor (soft-float, so libs do aparelho ou do cartao);
#   2. um roteiro (M17_ROTEIRO, patch 05) vai do titulo ao jogo do Dink: Start (Ctrl), os dialogos da mae e a casa;
#      capturas em 480x272; fonte 24 (a LiberationSans com 27 px de altura maxima; com 16 seriam 19); a musica MIDI
#      (1003.mid) toca pelo Timidity com o crude.cfg, sem "Unable to play"; o FIM do roteiro fecha com rc 0;
#   3. com um TIMIDITY_CFG que nao existe, o "Unable to play" aparece (a conferencia do item 2 pega a falha);
#   4. UM SIGTERM no jogo fecha com rc 0 (o VOL+ segurado, KB 11zd);
#   5. (T04, patch 03) os botoes fisicos simulados pelo roteiro: o D-pad salta nos menus de cursor do Dink, do Lyna e
#      do Pilgrim's Quest (o Begin escondido), o A clica, o START abre o menu;
#   6. (T05, patch 03) o analogico direito simulado (E2/E3) move o cursor livre e proporcional; a zona morta, nao;
#   7. (T06, patch 04) a roda: R3 -> tecla segurada -> key-N; 8. (patch 06) o save so em $HOME/.dink/<D-Mod>/;
#   9. (patch 03) as teclas de volume nao chegam ao jogo.
# O roteiro conta quadros, mas o jogo anda pelo relogio: o teste confere linhas do log e o fim, nao o conteudo exato
# de cada captura. Conteudo: ports/baixar_conteudo.sh freedink_data freepats glm. Nada e gravado fora de
# .cache/emu/testes/freedink.
set -uo pipefail
D=$(cd "$(dirname "$0")" && pwd)
. "$D/../../src/emu/ambiente.sh"
B="$EMU_CACHE/out/freedink/freedink"
T="$EMU_CACHE/testes/freedink"
F=0
conta() { if [ "$1" -eq 0 ]; then echo "ok    $2"; else echo "FALHA $2"; F=$((F + 1)); fi; }
ulimit -c 0

rm -rf "$T"; mkdir -p "$T/libs" "$T/dados" "$T/pkg"
for l in sdl2_projeto/libSDL2-2.0.so.0 sdl2_mixer/libSDL2_mixer-2.0.so.0 sdl2_image/libSDL2_image-2.0.so.0 \
         sdl2_ttf/libSDL2_ttf-2.0.so.0 sdl2_gfx/libSDL2_gfx-1.0.so.0; do
    cp "$EMU_CACHE/out/$l" "$T/libs/"
done

# --- 1. binario
out=$("$D/../../src/emu/testes/auditar_elf.sh" "$B" "$T/libs"); r=$?
conta $r "auditoria de ELF: freedink"; [ $r -eq 0 ] || echo "$out" | grep FALHA

# dados como no pacote: o dink/ do freedink-data, a fonte no pkgdatadir (M17_PKGDATA) e o FreePats
FDD="$EMU_CACHE/conteudo/freedink_data/freedink-data-1.08.20190120.tar.gz"
FP="$EMU_CACHE/conteudo/freepats/freepats_20060219.orig.tar.gz"
tar -xzf "$FDD" -C "$T/dados" --strip-components=1 freedink-data-1.08.20190120/dink 2>/dev/null
# no ext4 do PC o --refdir confere "dink/tiles" exato e o freedink-data traz "Tiles" (no exFAT do aparelho nao importa)
[ -d "$T/dados/dink/Tiles" ] && ln -s Tiles "$T/dados/dink/tiles"
cp "$EMU_CACHE/out/freedink/LiberationSans-Regular.ttf" "$T/pkg/"
tar -xzf "$FP" -O freepats-20060219/upstream/freepats-20060219.tar.bz2 2>/dev/null | tar -xjf - -C "$T" 2>/dev/null
CFG="$T/freepats/crude.cfg"
[ -f "$T/dados/dink/Dink.dat" ] && [ -f "$T/pkg/LiberationSans-Regular.ttf" ] && [ -f "$CFG" ]
conta $? "dados do Dink, fonte e FreePats prontos (baixar_conteudo.sh freedink_data freepats)"

# rodar NOME ROTEIRO [TIMIDITY_CFG] -- roda ate o fim (o FIM do roteiro) ou o tempo; rc em $T/NOME/rc
rodar() {
    local n=$1 rot=$2 cfg=${3:-$CFG} d="$T/$1"
    mkdir -p "$d"
    sed "s|@TELAS@|@$d|g" > "$d/roteiro.txt" <<< "$rot"
    ( cd "$T/dados" && exec env SDL_VIDEODRIVER=dummy SDL_RENDER_DRIVER=software SDL_AUDIODRIVER=dummy \
        M17_JANELA=480x272 M17_PKGDATA="$T/pkg" TIMIDITY_CFG="$cfg" M17_ROTEIRO="$d/roteiro.txt" \
        LD_LIBRARY_PATH="$T/libs" timeout -k 5 600 qemu-arm-static -L "$EMU_ROOTFS" "$B" --refdir . -S -i ) \
        > "$d/log.txt" 2>&1
    echo $? > "$d/rc"
}
largura() { [ "$(od -An -tu4 -j18 -N8 "$1" 2>/dev/null | tr -s ' ')" = " 480 272" ]; }

# --- 2. do titulo ao jogo (o roteiro do spike, rot_fonte: o cursor desce ate o Start e o Ctrl clica)
ROT='60 +Right
60 +Down
82 -Down
98 -Right
135 @TELAS@/00-titulo.bmp
140 +Left_Ctrl
150 -Left_Ctrl
270 @TELAS@/01-dialogo-mae.bmp
800 @TELAS@/02-jogo.bmp
810 FIM'
rodar jogo "$ROT"
L="$T/jogo/log.txt"
grep -q 'FreeDink graphics mode: IOGfxDisplaySW' "$L" && grep -q 'Loading script START' "$L" \
  && grep -q 'Loading script s1-h1-' "$L" && grep -q '\[M17\] roteiro: fim' "$L" && [ "$(cat "$T/jogo/rc")" = 0 ]
conta $? "qemu: titulo -> Start -> a casa do Dink (scripts START e s1-h1-*), desenho por software; FIM -> rc 0 (rc=$(cat "$T/jogo/rc"))"
largura "$T/jogo/00-titulo.bmp" && largura "$T/jogo/01-dialogo-mae.bmp" && largura "$T/jogo/02-jogo.bmp"
conta $? "qemu: as tres capturas em 480x272 (M17_JANELA)"
grep -q 'The family name of the face in the font is: Liberation Sans' "$L" && grep -q 'The font max height is: 27' "$L"
conta $? "qemu: fonte 24 nos dialogos (LiberationSans do pkgdatadir, altura maxima 27; patch 02)"
grep -q 'Playing midi 1003.mid' "$L" && ! grep -q 'Unable to play' "$L"
conta $? "qemu: a musica MIDI toca (1003.mid pelo Timidity com o crude.cfg; sem 'Unable to play')"
! grep -q 'DEBUG.TXT' "$L" && [ ! -e "$T/dados/dink/DEBUG.TXT" ] && [ ! -e "$T/dados/dinksmallwood.ini" ]
conta $? "qemu: o jogo nao grava nada nos dados (sem DEBUG.TXT; -i sem o dinksmallwood.ini)"

# --- 3. controle negativo: sem o .cfg do Timidity, a musica nao carrega e o log diz
ROT_CURTO='60 +Right
60 +Down
82 -Down
98 -Right
140 +Left_Ctrl
150 -Left_Ctrl
300 FIM'
rodar semcfg "$ROT_CURTO" "$T/nao_existe.cfg"
grep -q "Unable to play '.*1003.mid'" "$T/semcfg/log.txt" && [ "$(cat "$T/semcfg/rc")" = 0 ]
conta $? "qemu: com um TIMIDITY_CFG que nao existe, 'Unable to play ...1003.mid' e o jogo segue (rc 0)"

# --- 4. UM SIGTERM no jogo (sem FIM no roteiro): rc 0
d="$T/sigterm"; mkdir -p "$d"
printf '60 +Right\n60 +Down\n82 -Down\n98 -Right\n140 +Left_Ctrl\n150 -Left_Ctrl\n' > "$d/roteiro.txt"
( cd "$T/dados" && exec env SDL_VIDEODRIVER=dummy SDL_RENDER_DRIVER=software SDL_AUDIODRIVER=dummy \
    M17_JANELA=480x272 M17_PKGDATA="$T/pkg" TIMIDITY_CFG="$CFG" M17_ROTEIRO="$d/roteiro.txt" \
    LD_LIBRARY_PATH="$T/libs" timeout -k 5 600 qemu-arm-static -L "$EMU_ROOTFS" "$B" --refdir . -S -i ) \
    > "$d/log.txt" 2>&1 &
p=$! i=0
while [ $i -lt 1800 ] && ! grep -q 'Loading script s1-h1-' "$d/log.txt" 2>/dev/null && kill -0 $p 2>/dev/null; do
    sleep 0.1; i=$((i + 1))
done
case "$p" in ''|*[!0-9]*) r=99 ;; *) kill -0 $p 2>/dev/null && kill -TERM $p; wait $p; r=$? ;; esac
grep -q 'Loading script s1-h1-' "$d/log.txt" && [ "$r" -eq 0 ]
conta $? "qemu: UM SIGTERM no jogo fecha com rc 0 (rc=$r)"

# --- 5. controles do aparelho (T04, patch 03; o qemu nao tem joystick: o roteiro simula os botoes fisicos B<n>)
#   Dink: o D-pad (13-16) salta entre Start/Continue/Quit; o A (6 -> botao 1 do Dink) clica o Start; no jogo, o
#   START (5 -> menu) abre o menu do jogo (script escape), depois do dialogo da mae (durante ele, o jogo nao abre o menu)
ROT_B='60 +B15
66 -B15
100 +B15
106 -B15
140 +B16
146 -B16
180 +B13
186 -B13
220 +B14
226 -B14
260 +B6
268 -B6
1080 +B5
1086 -B5
1150 @TELAS@/00-menu.bmp
1160 FIM'
rodar botoes "$ROT_B"
L="$T/botoes/log.txt"
n=$(grep -c '\[M17\] salto para' "$L")
[ "$n" -ge 5 ] && grep -q 'Loading script s1-h1-' "$L" && grep -q 'Loading script escape' "$L" && [ "$(cat "$T/botoes/rc")" = 0 ]
conta $? "qemu (Dink): D-pad salta entre os botoes do titulo ($n saltos), A clica o Start, START abre o menu do jogo"

# D-Mods de teste (so .cache; baixar_conteudo.sh dmods_teste): o .dmod e um tar.bz2 com a pasta do D-Mod
DM="$EMU_CACHE/conteudo/dmods_teste"
tar -xjf "$DM/lyna.dmod" -C "$T/dados" 2>/dev/null && tar -xjf "$DM/pilgrims_quest-2_06.dmod" -C "$T/dados" 2>/dev/null
conta $? "D-Mods de teste extraidos (Lyna's Story, Pilgrim's Quest; baixar_conteudo.sh dmods_teste)"
rodar_dmod() {   # NOME DMOD ROTEIRO
    local n=$1 g=$2 rot=$3 d="$T/$1"
    mkdir -p "$d"
    sed "s|@TELAS@|@$d|g" > "$d/roteiro.txt" <<< "$rot"
    ( cd "$T/dados" && exec env SDL_VIDEODRIVER=dummy SDL_RENDER_DRIVER=software SDL_AUDIODRIVER=dummy \
        M17_JANELA=480x272 M17_PKGDATA="$T/pkg" TIMIDITY_CFG="$CFG" M17_ROTEIRO="$d/roteiro.txt" \
        LD_LIBRARY_PATH="$T/libs" timeout -k 5 600 qemu-arm-static -L "$EMU_ROOTFS" "$B" --refdir . -S -i --game "$g" ) \
        > "$d/log.txt" 2>&1
    echo $? > "$d/rc"
}
#   Lyna: o titulo (script do D-Mod) com o salto e o A no Start
rodar_dmod lyna lyna '60 @TELAS@/00-titulo.bmp
90 +B15
96 -B15
130 +B15
136 -B15
170 +B14
176 -B14
290 +B6
298 -B6
500 @TELAS@/01-depois.bmp
510 FIM'
L="$T/lyna/log.txt"
grep -q '\[M17\] salto para 76,400' "$L" && grep -q '\[M17\] salto para 314,400' "$L" && grep -q 'Loading script nomagic' "$L" \
  && [ "$(cat "$T/lyna/rc")" = 0 ]
conta $? "qemu (Lyna's Story): o salto acha os botoes do titulo do D-Mod e o A abre o jogo"
#   Pilgrim's Quest: o salto acha o "Begin" escondido atras da tela (76,434); o A o clica (o guia); o START sai do guia
#   para a tela de escolha da versao, onde o salto alterna entre os dois botoes (R-rated 178,394 e M-rated 76,434)
rodar_dmod pq pq '60 @TELAS@/00-titulo.bmp
130 +B15
136 -B15
170 +B6
178 -B6
450 +B5
456 -B5
520 @TELAS@/01-escolha.bmp
540 +B15
546 -B15
580 +B14
586 -B14
620 +B15
626 -B15
650 FIM'
L="$T/pq/log.txt"
grep -q '\[M17\] salto para 76,434' "$L" && grep -q 'Loading script mohican' "$L" && grep -q 'Loading script R-rated' "$L" \
  && [ "$(grep -c '\[M17\] salto para 178,394' "$L")" -ge 2 ] && [ "$(cat "$T/pq/rc")" = 0 ]
conta $? "qemu (Pilgrim's Quest): o salto acha o Begin escondido, o A o clica, e a tela de escolha alterna entre os botoes"

# --- 6. o analogico direito move o cursor livre (T05, patch 03), no titulo do Dink: o eixo simulado (E2/E3) na borda
#   por 30 quadros anda mais do que a meio curso nos mesmos 30; para a esquerda volta; na zona morta (25 %) nao anda
rodar cursor '60 E2=32767
90 E2=0
120 E2=-32767
150 E2=0
180 E2=20000
210 E2=0
240 E2=5000
270 E2=0
280 E3=32767
290 E3=0
320 FIM'
L="$T/cursor/log.txt"
grep '\[M17\] cursor em' "$L" | sed 's/.*cursor em //' > "$T/cursor/pos.txt"
python3 -I - "$T/cursor/pos.txt" <<'PY'
import sys
p = [tuple(map(int, l.split(","))) for l in open(sys.argv[1]) if l.strip()]
# 4 paradas: borda (direita), borda (esquerda), meio curso (direita), vertical (baixo; o cursor comeca em 0,0); a
# zona morta nao gera parada
ok = len(p) == 4
if ok:
    (x1, y1), (x2, y2), (x3, y3), (x4, y4) = p
    volta, meio = x1 - x2, x3 - x2
    ok = volta >= 60 and 0 < meio < volta and y1 == y2 == y3 and y4 > y3 and x4 == x3
print(p)
sys.exit(0 if ok else 1)
PY
conta $? "qemu: o analogico direito move o cursor (borda > meio curso, volta, vertical; zona morta parada): $(tr '\n' ' ' < "$T/cursor/pos.txt")"

# --- 7. a roda (T06, patch 04): no jogo do Dink, o R3 (B2) abre a roda; o roteiro da roda (M17_RODA_ROTEIRO, 048)
#   escolhe "P"; a tecla fica segurada e o motor roda o script KEY-80.c do Dink (o unico key-* dele: um som) uma vez.
#   E o mesmo caminho do "Curar" (H, key-72) do Pilgrim's Quest. Sem M17_RODA, o R3 so loga. Com a roda aberta, UM
#   SIGTERM fecha o jogo com rc 0.
printf 'rapido = nao\n[Teste]\nSom | Testar o som (tecla P) | P\nNada | Uma tecla sem script | Z\n' > "$T/teste.roda"
ROT_RODA='60 +B15
66 -B15
100 +B15
106 -B15
140 +B16
146 -B16
180 +B13
186 -B13
220 +B14
226 -B14
260 +B6
268 -B6
1080 B2
1300 FIM'
rodar_roda() {   # NOME RODA ROTEIRO_DA_RODA [sem FIM: espera a roda abrir e manda UM SIGTERM]
    local n=$1 rd=$2 rr=$3 sig=${4:-} d="$T/$1"
    mkdir -p "$d"
    if [ -n "$sig" ]; then printf '%s\n' "$ROT_RODA" | grep -v FIM | sed "s|@TELAS@|@$d|g" > "$d/roteiro.txt"
    else printf '%s\n' "$ROT_RODA" | sed "s|@TELAS@|@$d|g" > "$d/roteiro.txt"; fi
    printf '%s' "$rr" > "$d/roda.rot"
    ( cd "$T/dados" && exec env SDL_VIDEODRIVER=dummy SDL_RENDER_DRIVER=software SDL_AUDIODRIVER=dummy \
        M17_JANELA=480x272 M17_PKGDATA="$T/pkg" TIMIDITY_CFG="$CFG" M17_ROTEIRO="$d/roteiro.txt" \
        M17_RODA="$rd" M17_RODA_ROTEIRO="${rr:+$d/roda.rot}" M17_RODA_TELA="$d/roda.bmp" \
        LD_LIBRARY_PATH="$T/libs" timeout -k 5 600 qemu-arm-static -L "$EMU_ROOTFS" "$B" --refdir . -S -i ) \
        > "$d/log.txt" 2>&1 &
    local p=$! i=0
    if [ -n "$sig" ]; then
        while [ $i -lt 1800 ] && ! grep -q 'roda: roteiro fim' "$d/log.txt" 2>/dev/null && kill -0 $p 2>/dev/null; do
            sleep 0.1; i=$((i + 1))
        done
        case "$p" in ''|*[!0-9]*) echo 99 > "$d/rc"; return ;; esac
        kill -0 $p 2>/dev/null && kill -TERM $p
    fi
    wait $p; echo $? > "$d/rc"
}
rodar_roda roda "$T/teste.roda" 'p0 A'
L="$T/roda/log.txt"
grep -q '\[M17\] roda: aberta' "$L" && grep -q '\[M17\] roda: escolheu Som (P)' "$L" && grep -q '\[M17\] roda: tecla P segurada' "$L" \
  && [ "$(grep -ci 'Loading script key-80' "$L")" -eq 1 ] && [ "$(cat "$T/roda/rc")" = 0 ] && largura "$T/roda/roda.bmp"
conta $? "qemu: R3 no jogo -> a roda (480x272) -> 'Som' (P) -> a tecla segurada roda o KEY-80.c do Dink uma vez"
rodar_roda semroda "" ''
grep -q '\[M17\] roda: sem roda' "$T/semroda/log.txt" && grep -q '\[M17\] roda: R3 sem roda' "$T/semroda/log.txt" \
  && ! grep -q 'roda: aberta' "$T/semroda/log.txt" && [ "$(cat "$T/semroda/rc")" = 0 ]
conta $? "qemu: sem M17_RODA o R3 so loga e o jogo segue"
rodar_roda rodasig "$T/teste.roda" 'p1' sigterm
grep -q '\[M17\] roda: fechada pelo SDL_QUIT' "$T/rodasig/log.txt" && [ "$(cat "$T/rodasig/rc")" = 0 ]
conta $? "qemu: UM SIGTERM com a roda aberta fecha a roda e o jogo (rc 0; rc=$(cat "$T/rodasig/rc"))"

# --- 8. o save vai para $HOME/.dink/<D-Mod>/, nunca para a pasta do jogo (patch 06; sessao 1 no aparelho: o motor
#   gravava primeiro na pasta do jogo, e o save do Dink caiu em tutu8bits/jogos/dink/dink/). Um D-Mod minimo de teste
#   (so o START.c; o resto vem do Dink) chama save_game(1) e kill_game(). Com o binario sem o patch, o save caia em
#   dados/salvar/ e o nome do D-Mod saia vazio (conferido a mao na T13)
mkdir -p "$T/dados/salvar/story" "$T/home_salvar"
printf 'Teste de save\n' > "$T/dados/salvar/dmod.diz"
printf 'void main( void )\n{\n  save_game(1);\n  kill_game();\n}\n' > "$T/dados/salvar/story/START.c"
( cd "$T/dados" && exec env SDL_VIDEODRIVER=dummy SDL_RENDER_DRIVER=software SDL_AUDIODRIVER=dummy \
    M17_JANELA=480x272 M17_PKGDATA="$T/pkg" HOME="$T/home_salvar" \
    LD_LIBRARY_PATH="$T/libs" timeout -k 5 300 qemu-arm-static -L "$EMU_ROOTFS" "$B" --refdir . -S -i --game salvar ) \
    > "$T/salvar.log" 2>&1
r=$?
[ "$r" = 0 ] && grep -q '^INFO: dmodname = salvar$' "$T/salvar.log" && [ -s "$T/home_salvar/.dink/salvar/save1.dat" ] \
  && [ -z "$(find "$T/dados" -name 'save*.dat')" ]
conta $? "qemu: save_game grava em \$HOME/.dink/salvar/save1.dat, nada na pasta do jogo nem na do D-Mod (rc=$r)"

# --- 9. as teclas de volume nao chegam ao jogo (patch 03; sessao 2: o motor procura um key-N para toda tecla apertada,
#   e o VOL- do aparelho chegava como SDL_SCANCODE_VOLUMEDOWN, 129: "Script key-129 not found" a cada toque). No jogo
#   do Dink, VolumeDown e VolumeUp nao podem carregar key-129/key-128; o P (KEY-80.c) continua carregando
rodar volume "$(printf '%s\n' "$ROT_RODA" | sed '/B2$/d; /FIM$/d')
1080 +VolumeDown
1090 -VolumeDown
1120 +VolumeUp
1130 -VolumeUp
1160 +P
1170 -P
1300 FIM"
L="$T/volume/log.txt"
grep -q '\[M17\] tecla +VolumeDown' "$L" && grep -q '\[M17\] tecla +P' "$L" && ! grep -qi 'key-129\|key-128' "$L" \
  && grep -qi 'Loading script key-80' "$L" && [ "$(cat "$T/volume/rc")" = 0 ]
conta $? "qemu: VOL- e VOL+ (teclado) nao chegam ao jogo (sem key-129/key-128); o P ainda roda o KEY-80.c"

echo "falhas: $F"
[ "$F" -eq 0 ]
