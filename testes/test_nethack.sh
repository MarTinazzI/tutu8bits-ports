#!/usr/bin/env bash
# Spec 036 (T07; CA-01, CA-03, CA-06, CA-08): o NetHack do projeto no PC.
#   1. auditoria do ELF ARM (sem ncurses/X11/OpenGL de PC); o patch de ganchos conferido no texto;
#   2. arnes da traducao botao -> tecla (parte pura do m17nh_entrada.c, gcc do PC): mapa, posicao, direcao, --More--;
#   3. o binario ARM no qemu-arm-static (os dados ARM, nhdat): roteiro com o personagem aleatorio, tela 80x24 com a
#      linha de estado e cores; UM SIGTERM salva (rc 0, [M17] salvo) e reabrir com o mesmo -u continua a mesma partida;
#   4. o build do PC (gcc + SDL2 do sistema; dados do PC), por roteiros: lista de opcoes com paginas, #pray pela
#      lista, "Elbereth" pelo teclado virtual, viagem pelo cursor (getpos), SELECT -> beber -> lista cancelada sem
#      laco, START -> salvar; o nome do -u na linha de estado; nethack.cfg e nethackrc com lixo viram aviso.
# Espera por condicao ("[M17] roteiro: fim" no log), nunca por tempo fixo. Nada e gravado fora de
# .cache/emu/testes/nethack.
set -uo pipefail
D=$(cd "$(dirname "$0")" && pwd)
. "$D/../../src/emu/ambiente.sh"
B="$EMU_CACHE/out/nethack/nethack"
FONTE="$EMU_CACHE/src/nethack"
BPC="$FONTE/build-pc/src/nethack"
P01="$EMU_RAIZ/ports/patches/nethack-m17-01-ganchos.patch"
RC="$EMU_RAIZ/ports/nethack_m17/nethackrc"
T="$EMU_CACHE/testes/nethack"
F=0
conta() { if [ "$1" -eq 0 ]; then echo "ok    $2"; else echo "FALHA $2"; F=$((F + 1)); fi; }
ulimit -c 0

rm -rf "$T"; mkdir -p "$T/libs"
cp "$EMU_CACHE/out/sdl2_projeto/libSDL2-2.0.so.0" "$T/libs/"

# --- 1. binario e patch
out=$("$D/../../src/emu/testes/auditar_elf.sh" "$B" "$T/libs"); r=$?
conta $r "auditoria de ELF: nethack"; [ $r -eq 0 ] || echo "$out" | grep FALHA
"$READELF" -d "$B" > "$T/dinamico.txt"
! grep -qiE 'NEEDED.*(ncurses|tinfo|X11|xcb|wayland|libGL\.so)' "$T/dinamico.txt"
conta $? "nethack sem ncurses/X11/OpenGL de PC (interface m17 sobre o SDL2)"
grep -q '^+    (void) signal(SIGTERM, m17_sigterm);' "$P01" && grep -q '^+    m17nh_contexto_posicao(1);' "$P01" \
  && grep -q '^+    fprintf(stderr, "\[M17\] salvo\\n");' "$P01" && grep -q '^+    fprintf(stderr, "\[M17\] fim\\n");' "$P01" \
  && grep -q '^+    { &m17_procs, 0 CHAINR(0) },' "$P01" && grep -q '!defined(M17)' "$P01"
conta $? "patch: SIGTERM so marca o pedido (salva fora do tratador), getpos marcado, [M17] salvo/fim, interface m17, sem compress"
[ -f "$EMU_CACHE/out/nethack/nhdat" ] && [ -f "$FONTE/build-pc/dat/nhdat" ] && [ -x "$BPC" ]
conta $? "dados (nhdat) ARM e do PC e o binario do PC gerados pela receita"

# --- 2. arnes da traducao
gcc -std=c99 -Wall -Wextra -Werror -DM17NH_TESTE -DM17E_TESTE -I"$EMU_RAIZ/ports/nethack_m17" \
    -I"$EMU_RAIZ/ports/rogue_m17" -o "$T/arnes" "$D/fontes/arnes_m17nh.c" \
    "$EMU_RAIZ/ports/nethack_m17/m17nh_entrada.c" -lm > "$T/arnes_cc.log" 2>&1
r=$?; [ $r -eq 0 ] || cat "$T/arnes_cc.log"
conta $r "arnes da traducao compilado (gcc do PC, -Werror)"
"$T/arnes" > "$T/arnes.log" 2>&1; r=$?
sed 's/^/      /' "$T/arnes.log" | grep -v 'falhas:'
conta $r "arnes da traducao ($(grep -c '^ok' "$T/arnes.log") casos verdes)"

# pasta de jogo (NETHACKDIR) como o lancador a monta: dados do alvo, sysconf do produto, save/ e arquivos vazios
jogo() {   # PASTA DADOS
    mkdir -p "$1/save"
    cp "$2/nhdat" "$2/license" "$2/symbols" "$1/"
    cp "$EMU_RAIZ/ports/nethack_m17/sysconf" "$1/"
    : > "$1/record"; : > "$1/logfile"; : > "$1/xlogfile"; : > "$1/perm"
}
# rodar NOME JOGO ROTEIRO [pc] -- args: roda ate o fim do roteiro e manda UM SIGTERM; rc em $T/NOME/rc.
# RODA (arquivo .roda) e RODA_ROT (roteiro da roda, spec 048): sem RODA, o R3 nao faz nada. ESPERA: a linha do log que
# encerra a espera (padrao "roteiro: fim", o do NetHack).
# O 1o \e do roteiro fecha o --More-- da saudacao (a da Valquiria nao cabe numa linha). Variaveis: TEC (roteiro do teclado), NHRC (nethackrc), NHCFG (nethack.cfg)
rodar() {
    local n=$1 g=$2 rot=$3 pc=${4:-}; shift 4
    local d="$T/$n"; mkdir -p "$d"
    printf '%s' "$rot" > "$d/rot.txt"
    printf '%s' "${TEC:-}" > "$d/tec.txt"
    printf '%s' "${RODA_ROT:-}" > "$d/roda.rot"
    local exe=(qemu-arm-static -L "$EMU_ROOTFS" "$B")
    [ -n "$pc" ] && exe=("$BPC")
    ( cd "$g" && exec env SDL_VIDEODRIVER=dummy SDL_RENDER_DRIVER=software SDL_AUDIODRIVER=dummy \
        LD_LIBRARY_PATH="$T/libs" NETHACKDIR="$g" NETHACKOPTIONS="@${NHRC:-$RC}" M17_NETHACK_CFG="${NHCFG:-}" \
        M17_ROTEIRO="$d/rot.txt" M17_TECLADO_ROTEIRO="$d/tec.txt" M17_TELA="$d/tela.bmp" M17_TELA_TXT="$d/tela.txt" \
        M17_RODA="${RODA:-}" M17_RODA_ROTEIRO="${RODA_ROT:+$d/roda.rot}" M17_RODA_TELA="$d/roda.bmp" \
        M17_MSGS=1 timeout -k 5 240 "${exe[@]}" "$@" ) > "$d/log.txt" 2>&1 &
    local p=$! i=0
    while [ $i -lt 2000 ] && ! grep -q "${ESPERA:-roteiro: fim}" "$d/log.txt" 2>/dev/null && kill -0 $p 2>/dev/null; do
        sleep 0.1; i=$((i + 1))
    done
    # sem pausa aqui: o "roteiro: fim" so sai quando o jogo pede a PROXIMA tecla, e a tela ja foi gravada antes
    # (winm17.c: m17v_mostrar() antes de m17nh_ler()); spec 046, D-04
    case "$p" in ''|*[!0-9]*) echo 99 > "$d/rc"; return ;; esac
    kill -0 $p 2>/dev/null && kill -TERM $p 2>/dev/null
    wait $p; echo $? > "$d/rc"
}
msgs() { sed -n 's/^\[M17\] msg: //p' "$T/$1/log.txt"; }
cores() {   # quantas cores diferentes na captura
    python3 -I -c 'import sys; d=open(sys.argv[1],"rb").read(); o=int.from_bytes(d[10:14],"little"); px=d[o:]
print(len({px[i:i+2] for i in range(0,len(px),2)}))' "$1"
}

# --- 3. qemu (o binario do aparelho)
if ! command -v qemu-arm-static > /dev/null; then conta 1 "qemu-arm-static"; echo "falhas: $F"; exit 1; fi
# personagem FIXO em todos os casos (spec 046, D-03): com o sorteado, o texto da saudacao e do deus muda de tamanho
# (um Monge pede --More--) e o roteiro, que e fixo, desviava (B-57: 6 de 30 rodadas falhavam sozinhas)
VALQ='OPTIONS=role:Valkyrie,race:human,gender:female,align:neutral'
cp "$RC" "$T/rc_valq"; echo "$VALQ" >> "$T/rc_valq"
G="$T/jogo_arm"; jogo "$G" "$EMU_CACHE/out/nethack"
# \e fecha o --More-- da saudacao se houver (e nada faz se nao houver); {A} aqui cairia na escada de subir, onde todo
# personagem comeca, e sairia da masmorra. O \e do fim fecha um --More-- no MEIO de um turno (o cao lutando, p. ex.):
# sem ele o SIGTERM fechava o --More--, o turno terminava (monstros andam, T+1) e o save nao era a ultima tela (B-57)
NHRC="$T/rc_valq" rodar q1 "$G" '\e{dir}{dir}\e' "" -u Tutu
[ "$(cat "$T/q1/rc")" = 0 ] && grep -q '\[M17\] salvo' "$T/q1/log.txt" && grep -q '\[M17\] fim' "$T/q1/log.txt" \
    && [ -f "$G/save/$(id -u)Tutu" ] && ! ls "$G" | grep -q 'lock\.0'
conta $? "qemu: roteiro + UM SIGTERM salva (rc 0, [M17] salvo/fim, save em save/, sem arquivos de nivel soltos)"
sed -n 24p "$T/q1/tela.txt" | grep -q '^Dlvl:1 ' && sed -n 23p "$T/q1/tela.txt" | grep -q '^Tutu the ' \
    && [ "$(cores "$T/q1/tela.bmp")" -ge 3 ]
conta $? "qemu: tela 80x24 com as 2 linhas de estado (nome do -u) e cores ($(cores "$T/q1/tela.bmp") cores)"
cp "$T/q1/tela.txt" "$T/q1_tela.txt"
NHRC="$T/rc_valq" rodar q2 "$G" '' "" -u Tutu
[ "$(cat "$T/q2/rc")" = 0 ] && msgs q2 | grep -q 'welcome back to NetHack' \
    && diff <(sed -n 2,24p "$T/q1_tela.txt") <(sed -n 2,24p "$T/q2/tela.txt") > /dev/null
conta $? "qemu: reabrir com o mesmo -u continua a partida (mesmo mapa e estado)"

# spec 048: a roda de opcoes no binario do aparelho (R3 -> roda -> ":" = olhar aqui, na escada onde todo personagem
# comeca)
cat > "$T/teste.roda" <<'RODA'
[Ações]
Aqui   | Olhar o que há aqui             | :
Rezar  | Rezar aos deuses                | #pray
Chutar | Chutar numa direção             | ^D
Função | Uma função que o NetHack não tem | @mapa
RODA
RODA="$T/teste.roda" RODA_ROT='p0 A' NHRC="$T/rc_valq" rodar q3 "$G" '\e{R3}' "" -u Roda
# (a escada tambem aparece na saudacao: conta so a mensagem depois da escolha; a captura e do tamanho da saida, que no
# dummy e a tela cheia de 1024x768)
LC_ALL=C sed -n '/\[M17\] roda: escolheu Aqui (:)/,$p' "$T/q3/log.txt" | grep -q '\[M17\] msg: There is a staircase up here' \
    && [ -s "$T/q3/roda.bmp" ] && [ "$(cat "$T/q3/rc")" = 0 ]
conta $? "qemu: R3 -> roda (captura gravada) -> Aqui (:) -> o jogo olha a escada; SIGTERM salva"

# --- 4. PC: listas, teclado, cursor, menus (Valquiria fixa: inventario conhecido, sem pocao)
GP="$T/jogo_pc"; jogo "$GP" "$FONTE/build-pc/dat"
NHRC="$T/rc_valq" rodar p1 "$GP" '\eO{dir}{A}' pc -u Opcoes
head -1 "$T/p1/tela.txt" | grep -q '^Set what options?' && tail -1 "$T/p1/tela.txt" | grep -q 'pagina 2/[2-9]'
conta $? "PC: a lista de opcoes (O) tem varias paginas e a direita passa para a 2a"
NHRC="$T/rc_valq" rodar p2 "$GP" '\e#{A}{A}\e' pc -u Prece
msgs p2 | grep -q 'Are you sure you want to pray' && msgs p2 | grep -q 'You begin praying to '
conta $? "PC: # abre a lista dos comandos estendidos com pray primeiro; A confirma e a prece acontece"
NHRC="$T/rc_valq" TEC='>>>>AXv<<<A^A>>>Av>>>A^<<<Av>>>>>A^<<AS' rodar p3 "$GP" '\eE{A}' pc -u Gravar
grep -q '\[M17\] teclado: ok \[Elbereth\]' "$T/p3/log.txt" && msgs p3 | grep -q 'You write in the dust with your fingertip'
conta $? "PC: E -> a lista do 'com o que escrever' abre sozinha -> teclado virtual -> Elbereth gravado"
NHRC="$T/rc_valq" rodar p4 "$GP" '\e{SELECT}{A}{B}' pc -u Beber
msgs p4 | grep -q "You don't have anything to drink"
conta $? "PC: SELECT -> Beber; sem pocao o jogo responde e nada fica preso"
NHRC="$T/rc_valq" rodar p5 "$GP" '\e_{baixo}{baixo}{A}' pc -u Viagem
msgs p5 | grep -q 'Where do you want to travel to' && [ "$(cat "$T/p5/rc")" = 0 ] && grep -q '\[M17\] salvo' "$T/p5/log.txt"
conta $? "PC: _ -> cursor no mapa (getpos) -> A escolhe e viaja; SIGTERM salva"
NHRC="$T/rc_valq" rodar p6 "$GP" '\e{START}{baixo}{baixo}{A}{A}' pc -u Salvar
msgs p6 | grep -q 'Really save' && grep -q '\[M17\] salvo' "$T/p6/log.txt" && [ "$(cat "$T/p6/rc")" = 0 ]
conta $? "PC: START -> Salvar e sair -> A -> salvo (rc 0)"
NHRC="$T/rc_valq" rodar p8 "$GP" '\e<y' pc -u Fim
msgs p8 | grep -q 'Do you want your possessions identified' && [ "$(cat "$T/p8/rc")" = 0 ] \
    && grep -q '\[M17\] fim' "$T/p8/log.txt"
conta $? "PC: SIGTERM nas perguntas do fim de jogo fecha limpo (rc 0, [M17] fim; nao trava)"
# spec 048: a roda no PC — #comando, sem roda, funcao que o NetHack nao tem, cancelar
RODA="$T/teste.roda" RODA_ROT='p1 A' NHRC="$T/rc_valq" rodar p9 "$GP" '\e{R3}{A}' pc -u RodaPrece
LC_ALL=C grep -q '\[M17\] roda: escolheu Rezar (#pray)' "$T/p9/log.txt" && msgs p9 | grep -q 'Are you sure you want to pray' \
    && msgs p9 | grep -q 'You begin praying to '
conta $? "PC: roda -> Rezar (#pray) vai direto ao comando estendido (sem a lista); A confirma e a prece acontece"
NHRC="$T/rc_valq" rodar p10 "$GP" '\e{R3}' pc -u SemRoda
grep -q '\[M17\] roda: sem roda' "$T/p10/log.txt" && ! grep -q 'roda: aberta' "$T/p10/log.txt" && [ "$(cat "$T/p10/rc")" = 0 ]
conta $? "PC: sem M17_RODA o R3 nao abre nada (log diz) e o jogo segue"
RODA="$T/teste.roda" RODA_ROT='p3 A' NHRC="$T/rc_valq" rodar p11 "$GP" '\e{R3}' pc -u RodaFuncao
grep -q '\[M17\] roda: acao "@mapa" o NetHack nao executa' "$T/p11/log.txt" && [ "$(cat "$T/p11/rc")" = 0 ]
conta $? "PC: acao @funcao que o NetHack nao tem: log e nada acontece"
RODA="$T/teste.roda" RODA_ROT='p0 B' NHRC="$T/rc_valq" rodar p12 "$GP" '\e{R3}' pc -u RodaCancela
# so as mensagens DEPOIS de cancelar: o mapa e sorteado e, com um objeto na escada da chegada, o proprio jogo ja diz
# "There is a staircase up here" na abertura (visto na suite do 6488f73)
grep -q '\[M17\] roda: cancelada' "$T/p12/log.txt" \
    && ! sed -n '/\[M17\] roda: cancelada/,$p' "$T/p12/log.txt" | grep -q 'msg: There is a staircase up here' \
    && [ "$(cat "$T/p12/rc")" = 0 ]
conta $? "PC: B fecha a roda sem acao"
# o VOL+ segurado (SIGTERM) com a roda aberta: o NetHack so marca o pedido (sem SDL_QUIT); a roda o consulta e fecha
RODA="$T/teste.roda" RODA_ROT='p1' ESPERA='roda: roteiro fim' NHRC="$T/rc_valq" rodar p13 "$GP" '\e{R3}' pc -u RodaSai
grep -q '\[M17\] roda: fechada pelo pedido do jogo (SIGTERM)' "$T/p13/log.txt" && grep -q '\[M17\] salvo' "$T/p13/log.txt" \
    && [ "$(cat "$T/p13/rc")" = 0 ]
conta $? "PC: SIGTERM com a roda aberta: a roda fecha, o jogo salva e sai (rc 0)"
# pergunta de objeto com UM item so (a Valquiria comeca sempre com uma racao so; o inventario do Mago e sorteado): o
# NetHack chama o message_menu; o generico so escrevia a linha, a pergunta voltava e o jogo nao saia do laco, nem com
# o SIGTERM (sessao 1 da 048: o VOL+ virou SIGKILL, sem salvar). O do port mostra a lista de 1 item: A escolhe;
# SIGTERM salva
NHRC="$T/rc_valq" rodar p14 "$GP" '\ee' pc -u UmItem
NHRC="$T/rc_valq" rodar p15 "$GP" '\ee{A}' pc -u UmItemA
grep -q '\[M17\] salvo' "$T/p14/log.txt" && [ "$(cat "$T/p14/rc")" = 0 ] && msgs p14 | grep -q 'What do you want to eat? \[d or' \
    && msgs p15 | grep -qE 'all of it down|finally finished|food really hits|is delicious|bland'
conta $? "PC: um item so na pergunta: A escolhe a racao e come, e o SIGTERM nela salva (rc 0, sem laco)"

# energia cortada (SIGKILL, sem salvar): os arquivos de nivel ficam; o recover do NetHack (o mesmo que o lancar.sh roda)
# refaz o save e a partida continua
GK="$T/jogo_kill"; jogo "$GK" "$FONTE/build-pc/dat"
( cd "$GK" && exec env SDL_VIDEODRIVER=dummy SDL_RENDER_DRIVER=software SDL_AUDIODRIVER=dummy NETHACKDIR="$GK" \
    NETHACKOPTIONS="@$T/rc_valq" M17_MSGS=1 M17_TELA_TXT="$T/kill_tela.txt" timeout -k 5 120 "$BPC" -u Queda ) > "$T/kill.log" 2>&1 &
_kp=$!; _ki=0
# espera o nivel no disco E o jogo na tela (Dlvl:1): ai os arquivos de nivel estao completos (era um sleep 1; D-04)
while [ $_ki -lt 1200 ] && ! { ls "$GK" | grep -q 'lock\.0' && grep -q '^Dlvl:1 ' "$T/kill_tela.txt" 2>/dev/null; }; do
    sleep 0.1; _ki=$((_ki + 1))
done
_kq=$(pgrep -P "$_kp" -x nethack); case "$_kq" in ''|*[!0-9]*) _kq="" ;; esac
[ -n "$_kq" ] && kill -KILL "$_kq"; wait $_kp 2>/dev/null
_kl=$(ls "$GK" | sed -n 's/\.0$//p' | head -n 1)
( cd "$GK" && "$FONTE/build-pc/util/recover" -d "$GK" "$_kl" ) > "$T/recover.log" 2>&1; _kr=$?
rodar p9 "$GK" '\e' pc -u Queda
[ -n "$_kl" ] && [ $_kr -eq 0 ] && ! ls "$GK" | grep -q 'lock\.0' && msgs p9 | grep -q 'welcome back to NetHack'
conta $? "PC: partida morta sem salvar (SIGKILL) -> recover refaz o save -> reabrir continua ($_kl)"
printf 'acorde_ms=abc\nzona_morta=999999\n' > "$T/lixo.cfg"
printf '%s\nOPTIONS=opcao_que_nao_existe\n' "$VALQ" > "$T/rc_lixo"   # o papel ANTES do erro: depois dele, era ignorado
NHCFG="$T/lixo.cfg" NHRC="$T/rc_lixo" rodar p7 "$GP" '{A}{A}' pc -u Lixo
grep -q '\[M17\] nethack.cfg: acorde_ms invalida, usando o padrao 60' "$T/p7/log.txt" \
    && grep -q "Unknown option 'opcao_que_nao_existe'" "$T/p7/log.txt" && msgs p7 | grep -q 'welcome to NetHack'
conta $? "PC: nethack.cfg e nethackrc com lixo viram aviso no log e o jogo abre com o padrao"

echo "falhas: $F"
[ "$F" -eq 0 ]
