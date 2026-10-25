#!/usr/bin/env bash
# Spec 031 (T05, CA-01): o Crispy Doom do projeto no PC.
#   1. auditoria de ELF (sem rede, X11, OpenGL de PC nem libpng) e o patch 01 aplicado;
#   2. o motor no qemu-arm-static com o freedoom1.wad e com o freedoom2.wad (video dummy, renderer por
#      software, audio dummy; XDG_DATA_HOME isolado, com a configuracao inicial do produto semeada) ate
#      carregar uma fase, esperando por condicao; UM SIGTERM (o do m17atalhos) -> rc 0, e a configuracao
#      regravada com as chaves do produto iguais (patch crispy_doom-m17-01: sem ele, rc 143 e nada gravado);
#   3. sem o IWAD: o motor sai sozinho com erro, sem travar.
# Spec 033: os mesmos passos para o crispy-heretic com o Blasphemer (livre, BSD; baixar_conteudo.sh blasphemer) e,
# para o crispy-strife, auditoria e "sem IWAD" (o strife1.wad e comercial: fica fora do repositorio e do .cache; o
# jogo foi visto a mao no qemu e vai a sessao no aparelho). Conferencias de texto dos patches e do show_endoom 0.
# O Freedoom fica fora do repositorio: ports/baixar_conteudo.sh freedoom (sem ele, FALHA, como as ROMs
# do test_lote2). Spec 038: o crispy-hexen com a demo de 4 fases (baixar_conteudo.sh hexen; so testes, nunca no pacote).
# Nada e gravado fora de .cache/emu/testes/crispy_doom.
set -uo pipefail
D=$(cd "$(dirname "$0")" && pwd)
. "$D/../../src/emu/ambiente.sh"
O="$EMU_CACHE/out/crispy_doom"; B="$O/crispy-doom"
ZIP="$EMU_CACHE/conteudo/freedoom/freedoom-0.13.0.zip"
CFG="$EMU_RAIZ/ports/config/crispy"
T="$EMU_CACHE/testes/crispy_doom"
F=0
conta() { if [ "$1" -eq 0 ]; then echo "ok    $2"; else echo "FALHA $2"; F=$((F + 1)); fi; }
ulimit -c 0

rm -rf "$T"; mkdir -p "$T/libs"
cp "$EMU_CACHE/out/sdl2_projeto/libSDL2-2.0.so.0" "$EMU_CACHE/out/sdl2_mixer/libSDL2_mixer-2.0.so.0" "$T/libs/"
conta $? "libs do projeto copiadas (sdl2_projeto, sdl2_mixer)"
for m in crispy-doom crispy-heretic crispy-strife crispy-hexen; do
    out=$("$D/../../src/emu/testes/auditar_elf.sh" "$O/$m" "$T/libs"); r=$?
    conta $r "auditoria de ELF: $m"; [ $r -eq 0 ] || echo "$out" | grep FALHA
    _n=$("$READELF" -d "$O/$m" | grep -ciE 'NEEDED.*(X11|xcb|wayland|libGL\.so|SDL2_net|png|samplerate|fluidsynth)')
    [ "$_n" -eq 0 ]; conta $? "$m: sem rede, X11, OpenGL de PC, libpng, libsamplerate, FluidSynth ($_n)"
done
P01="$EMU_RAIZ/ports/patches/crispy_doom-m17-01-sair.patch"
grep -q '^+#if !defined(M17)$' "$P01" && [ "$(grep -c '^+        I_Quit();$' "$P01")" = 3 ]
conta $? "patch 01: tratadores de sinal do SDL mantidos e o fechar sai direto (Doom, Heretic e Strife)"
P03="$EMU_RAIZ/ports/patches/crispy_doom-m17-03-nome-save.patch"
grep -q '^+        M_snprintf(savegamestrings\[choice\], SAVESTRINGSIZE, "STRIFE %d", choice + 1);$' "$P03" \
  && grep -q '^+                key = KEY_ESCAPE;$' "$P03"
conta $? "033: patch 03: no Strife, slot vazio ja vem com nome (STRIFE <n>) e o B cancela o nome"
# spec 043 (D-02): o esquema comum dos jogos de tiro nas configuracoes do produto (indices do KB 11k; L3 1 e R3 2 H)
_e43=0
for _f in default.cfg heretic.cfg hexen.cfg strife.cfg; do
    grep -q '^joyb_use  *9$' "$CFG/$_f" && grep -q '^joyb_speed  *1$' "$CFG/$_f" && grep -q '^joyb_fire  *10$' "$CFG/$_f" || _e43=1
done
grep -q '^joyb_jump  *6$' "$CFG/default.cfg" && grep -q '^joyb_jump  *-1$' "$CFG/heretic.cfg" \
  && grep -q '^joyb_jump  *6$' "$CFG/hexen.cfg" && grep -q '^joyb_jump  *6$' "$CFG/strife.cfg" || _e43=1
for _f in crispy-doom.cfg crispy-heretic.cfg crispy-hexen.cfg crispy-strife.cfg; do
    grep -q '^joyb_toggle_automap  *12$' "$CFG/$_f" && grep -q '^joystick_look_axis  *3$' "$CFG/$_f" || _e43=1
done
for _f in crispy-heretic.cfg crispy-hexen.cfg crispy-strife.cfg; do grep -q '^joyb_useartifact  *4$' "$CFG/$_f" || _e43=1; done
for _f in crispy-heretic.cfg crispy-hexen.cfg; do grep -q '^joyb_flycenter  *2$' "$CFG/$_f" || _e43=1; done
grep -q '^crispy_freelook  *1$' "$CFG/crispy-doom.cfg" && grep -q '^crispy_jump  *1$' "$CFG/crispy-doom.cfg" || _e43=1
[ "$_e43" = 0 ]
conta $? "043: esquema comum (X usa, A pula, L3 devagar, SELECT mapa, Y item, R3 voo, olhar no analogico direito; Doom com pulo e freelook)"
# spec 043 (T03, D-02/D-12): patch 06 — L3 liga/desliga nos 4 jogos; menu so com a borda e botao preso ate soltar
P06="$EMU_RAIZ/ports/patches/crispy_doom-m17-06-botoes.patch"
[ "$(grep -c '^+            m17_devagar = !m17_devagar;$' "$P06")" = 4 ] && [ "$(grep -c '^+#define JOY_BUTTON_PRESSED(x) M17_JoyMenu((x), ' "$P06")" = 4 ] \
  && grep -q '^+    m17_preso &= estado;$' "$P06" && grep -q '^+        ev.data1 = M17_FiltrarBotoes(ev.data1);   // spec 043 (D-12)$' "$P06"
conta $? "043: patch 06 (L3 liga/desliga nos 4 jogos; menu so com o aperto novo; botao do menu preso ate soltar)"
grep -q '^show_endoom  *0$' "$CFG/crispy-strife.cfg"
conta $? "033: crispy-strife.cfg com show_endoom 0 (a tela de texto de saida esperava uma tecla no I_Quit)"
P02="$EMU_RAIZ/ports/patches/crispy_doom-m17-02-controles.patch"
grep -q '^+            ev.data2 = M17_EixoDpad(14, 15);$' "$P02" && grep -q '^+static boolean M17_BotaoLivre(int b)$' "$P02" \
  && [ "$(grep -c '^+    speed = true;$' "$P02")" = 3 ] \
  && [ "$(grep -c '^+#define JOYB_MENU_OK 6$' "$P02")" = 3 ] && [ "$(grep -c '^+#define JOYB_MENU_VOLTAR 11$' "$P02")" = 3 ]
conta $? "patch 02: D-pad (so os botoes sem acao) junto com os analogicos, sempre correndo nos 3 jogos, menu com A/B"

if [ ! -f "$ZIP" ] || ! echo "3f9b264f3e3ce503b4fb7f6bdcb1f419d93c7b546f4df3e874dd878db9688f59  $ZIP" | sha256sum --quiet -c 2>/dev/null; then
    conta 1 "Freedoom em $ZIP (rode: ports/baixar_conteudo.sh freedoom)"
    echo "falhas: $F"; exit 1
fi
python3 -I -c 'import sys, zipfile
z = zipfile.ZipFile(sys.argv[1])
for n in ("freedoom1.wad", "freedoom2.wad"):
    open(sys.argv[2] + "/" + n, "wb").write(z.read("freedoom-0.13.0/" + n))' "$ZIP" "$T"
conta $? "freedoom1.wad e freedoom2.wad extraidos"

# rodar ARQ_LOG XDG [args...] (em 2o plano; PID em _rp); o motor e o $B (o Doom, ou o que o chamador puser)
rodar() {
    _rl=$1; _rx=$2; shift 2
    ( cd "$T" && exec env SDL_VIDEODRIVER=dummy SDL_RENDER_DRIVER=software SDL_AUDIODRIVER=dummy \
        XDG_DATA_HOME="$_rx" LD_LIBRARY_PATH="$T/libs" \
        timeout -k 10 300 qemu-arm-static -L "$EMU_ROOTFS" "$B" "$@" ) > "$_rl" 2>&1 &
    _rp=$!
}
# config_igual DIR ARQS...: as chaves do produto voltam iguais nos .cfg regravados (imprime as diferentes)
config_igual() {
    _cd=$1; shift; _d=0
    for f in "$@"; do
        while read -r k v; do
            g=$(awk -v k="$k" '$1 == k { $1 = ""; sub(/^ +/, ""); print }' "$_cd/$f")
            [ "$g" = "$v" ] || { echo "      $f $k: [$v] -> [$g]"; _d=$((_d + 1)); }
        done < "$CFG/$f"
    done
    return $_d
}

for w in freedoom1 freedoom2; do
    X="$T/saves_$w"; mkdir -p "$X/crispy-doom"; cp "$CFG/default.cfg" "$CFG/crispy-doom.cfg" "$X/crispy-doom/"
    L="$T/$w.log"
    rodar "$L" "$X" -iwad "$T/$w.wad"
    i=0
    while [ $i -lt 240 ] && ! grep -q 'P_SetupLevel' "$L" 2>/dev/null && kill -0 "$_rp" 2>/dev/null; do sleep 1; i=$((i + 1)); done
    grep -q 'P_SetupLevel' "$L"; conta $? "$w: carregou uma fase ($(sed -n 's/^P_SetupLevel: \([A-Z0-9]*\).*/\1/p' "$L" | head -n 1), ${i} s no qemu)"
    grep -q 'S_ChangeMusic' "$L"; conta $? "$w: musica iniciada"
    grep -q 'joystick with GUID "19001e5a010000001200000000010000"' "$L"; conta $? "$w: procura o i2c-keys pelo GUID da configuracao"
    case "$_rp" in ''|*[!0-9]*) conta 1 "PID valido"; echo "falhas: $F"; exit 1 ;; esac
    kill -TERM "$_rp" 2>/dev/null
    wait "$_rp"; r=$?
    conta $r "$w: um SIGTERM fecha com rc 0 (rc=$r)"
    # o stdout do motor tem buffer: esta linha so chega ao arquivo na saida (e e la que o lancar.sh confere)
    grep -q 'ST_Init: Init status bar' "$L"; conta $? "$w: log com a linha do fim normal do lancador (ST_Init)"
    config_igual "$X/crispy-doom" default.cfg crispy-doom.cfg; _d=$?
    [ "$(wc -l < "$X/crispy-doom/crispy-doom.cfg")" -gt 50 ] && [ "$_d" -eq 0 ]
    conta $? "$w: configuracao regravada ao sair, com as chaves do produto iguais ($_d diferentes)"
done

# spec 033: Heretic com o Blasphemer (livre): fase, um SIGTERM -> rc 0, linha do fim normal (SB_Init), .cfg iguais
BZ="$EMU_CACHE/conteudo/blasphemer/blasphem-0.1.8.zip"
if [ -f "$BZ" ] && echo "5838d211add81e1696a621485c1e40771035daf6609d08bad7018f52acfa5e54  $BZ" | sha256sum --quiet -c 2>/dev/null; then
    python3 -I -c 'import sys, zipfile; open(sys.argv[2], "wb").write(zipfile.ZipFile(sys.argv[1]).read("blasphem.wad"))' "$BZ" "$T/blasphem.wad"
    B="$O/crispy-heretic"; X="$T/saves_blasphemer"; L="$T/blasphemer.log"
    mkdir -p "$X/crispy-doom"; cp "$CFG/heretic.cfg" "$CFG/crispy-heretic.cfg" "$X/crispy-doom/"
    rodar "$L" "$X" -iwad "$T/blasphem.wad"
    i=0
    while [ $i -lt 240 ] && ! grep -q 'P_CheckMapFormat' "$L" 2>/dev/null && kill -0 "$_rp" 2>/dev/null; do sleep 1; i=$((i + 1)); done
    grep -q 'P_CheckMapFormat' "$L"; conta $? "heretic (Blasphemer): carregou uma fase ($(sed -n 's/.*P_CheckMapFormat: \[\([A-Z0-9]*\)\].*/\1/p' "$L" | head -n 1), ${i} s no qemu)"
    sleep 3
    case "$_rp" in ''|*[!0-9]*) conta 1 "PID valido"; echo "falhas: $F"; exit 1 ;; esac
    kill -TERM "$_rp" 2>/dev/null
    wait "$_rp"; r=$?
    conta $r "heretic: um SIGTERM fecha com rc 0 (rc=$r)"
    grep -q 'SB_Init: Loading patches' "$L"; conta $? "heretic: log com a linha do fim normal do lancador (SB_Init)"
    config_igual "$X/crispy-doom" heretic.cfg crispy-heretic.cfg; _d=$?
    [ "$_d" -eq 0 ]; conta $? "heretic: configuracao regravada ao sair, com as chaves do produto iguais ($_d diferentes)"
else
    conta 1 "Blasphemer em $BZ (rode: ports/baixar_conteudo.sh blasphemer)"
fi

# spec 038: Hexen com a demo de 4 fases (so testes; baixar_conteudo.sh hexen): fase, um SIGTERM -> rc 0, linha do fim
# normal (SB_Init), .cfg iguais. Sem o patch 04 o SIGTERM abria o "deseja sair?" e o motor nao fechava
P04="$EMU_RAIZ/ports/patches/crispy_doom-m17-04-hexen.patch"
grep -q '^+        I_Quit();$' "$P04" && grep -q '^+    speed = true;$' "$P04" && grep -q '^+#define JOYB_MENU_OK 6$' "$P04" \
  && grep -q '^joyb_toggle_automap  *12$' "$CFG/crispy-hexen.cfg"
conta $? "038: patch 04 (fechar direto, sempre correndo, menu A/B) e SELECT mapa na configuracao"
HZ="$EMU_CACHE/conteudo/hexen/hexndemo.zip"
if [ -f "$HZ" ] && echo "469ee3a254959d2fca624aec7391292fbd1ac3ebd9074b65f05cbc74de3c4572  $HZ" | sha256sum --quiet -c 2>/dev/null; then
    python3 -I -c 'import sys, zipfile; open(sys.argv[2], "wb").write(zipfile.ZipFile(sys.argv[1]).read("HEXEN.WAD"))' "$HZ" "$T/hexen.wad"
    B="$O/crispy-hexen"; X="$T/saves_hexen"; L="$T/hexen.log"
    mkdir -p "$X/crispy-doom"; cp "$CFG/hexen.cfg" "$CFG/crispy-hexen.cfg" "$X/crispy-doom/"
    rodar "$L" "$X" -iwad "$T/hexen.wad"
    i=0
    while [ $i -lt 240 ] && ! grep -q 'P_CheckMapFormat' "$L" 2>/dev/null && kill -0 "$_rp" 2>/dev/null; do sleep 1; i=$((i + 1)); done
    grep -q 'P_CheckMapFormat' "$L"; conta $? "hexen (demo): carregou uma fase ($(sed -n 's/.*P_CheckMapFormat: \[\([A-Z0-9]*\)\].*/\1/p' "$L" | head -n 1), ${i} s no qemu)"
    sleep 3
    case "$_rp" in ''|*[!0-9]*) conta 1 "PID valido"; echo "falhas: $F"; exit 1 ;; esac
    kill -TERM "$_rp" 2>/dev/null
    wait "$_rp"; r=$?
    conta $r "hexen: um SIGTERM fecha com rc 0 (rc=$r)"
    grep -q 'SB_Init: Loading patches' "$L"; conta $? "hexen: log com a linha do fim normal do lancador (SB_Init)"
    config_igual "$X/crispy-doom" hexen.cfg crispy-hexen.cfg; _d=$?
    [ "$_d" -eq 0 ]; conta $? "hexen: configuracao regravada ao sair, com as chaves do produto iguais ($_d diferentes)"
else
    conta 1 "demo do Hexen em $HZ (rode: ports/baixar_conteudo.sh hexen)"
fi

# spec 042 (T08, D-13): o nome do save pelo teclado virtual, no caminho de verdade (Enter/Esc do menu), pelo gancho
# M17_TESTE_SALVAR=<vaga> (abre o save no 1o tic de jogo) e o roteiro do teclado. Espera o .dsg/.hsg por condicao.
P05="$EMU_RAIZ/ports/patches/crispy_doom-m17-05-teclado.patch"
[ "$(grep -c '^+    M17_NomeSave(savegamestrings\[choice\], SAVESTRINGSIZE - 1, ' "$P05")" = 2 ] \
  && [ "$(grep -c '^+        M17_NomeSave(option);$' "$P05")" = 2 ] && grep -q '^+    teclado_sdl.c$' "$P05"
conta $? "patch 05: teclado no nome do save nos 4 jogos (Doom e Strife no M_SaveSelect, Heretic e Hexen no SCSaveGame)"
# salvar MOTOR WAD VAGA ROTEIRO ARQ_ESPERADO -> deixa o log em $T/salvar_<motor>.log; 0 se o arquivo apareceu
salvar() {
    _sm=$1; _sx="$T/salvar_$1"; rm -rf "$_sx"; mkdir -p "$_sx"; printf '%s' "$4" > "$_sx.rot"
    ( cd "$T" && exec env SDL_VIDEODRIVER=dummy SDL_RENDER_DRIVER=software SDL_AUDIODRIVER=dummy \
        XDG_DATA_HOME="$_sx" LD_LIBRARY_PATH="$T/libs" M17_TESTE_SALVAR="$3" M17_TECLADO_ROTEIRO="$_sx.rot" \
        timeout -k 10 300 qemu-arm-static -L "$EMU_ROOTFS" "$O/$1" -iwad "$2" -warp 1 1 ) > "$T/salvar_$1.log" 2>&1 &
    _sp=$!
    _si=0
    while [ $_si -lt 240 ] && kill -0 "$_sp" 2>/dev/null && ! grep -q 'teclado: \(ok\|cancelado\)' "$T/salvar_$1.log"; do
        sleep 1; _si=$((_si + 1))
    done
    _sj=0   # depois do teclado: o save (ou nada, no cancelar) em ate 20 s
    while [ $_sj -lt 20 ] && [ -z "$(find "$_sx" -name "$5" 2>/dev/null)" ]; do sleep 1; _sj=$((_sj + 1)); done
    case "$_sp" in ''|*[!0-9]*) return 1 ;; esac
    kill -TERM "$_sp" 2>/dev/null; wait "$_sp"
    _sa=$(find "$_sx" -name "$5" | head -n 1)
    [ -n "$_sa" ]
}
nome_save() { head -c 24 "$(find "$T/salvar_$1" -name "$2" | head -n 1)" | tr -d '\000'; }
salvar crispy-doom "$T/freedoom1.wad" 0 'BBAS' 'doomsav0.dsg'
r=$?; [ $r -eq 0 ] && grep -q '\[M17\] teclado: aberto \[E1M1\] (max 23)' "$T/salvar_crispy-doom.log" \
  && [ "$(nome_save crispy-doom doomsav0.dsg)" = "E1A" ]
conta $? "doom: o teclado abre com o nome do Crispy (E1M1); B B A START grava doomsav0.dsg com \"E1A\""
salvar crispy-doom "$T/freedoom1.wad" 1 'AAs' 'doomsav1.dsg'
[ $? -ne 0 ] && grep -q '\[M17\] teclado: cancelado' "$T/salvar_crispy-doom.log"
conta $? "doom: SELECT cancela e nada e gravado"
if [ -f "$T/blasphem.wad" ]; then
    salvar crispy-heretic "$T/blasphem.wad" 2 'YAS' 'hticsav2.hsg'
    r=$?; [ $r -eq 0 ] && grep -q '\[M17\] teclado: aberto \[E1M1\] (max 16)' "$T/salvar_crispy-heretic.log" \
      && [ "$(nome_save crispy-heretic hticsav2.hsg)" = "E1M1 A" ]
    conta $? "heretic (Blasphemer): teclado com o nome do Crispy; Y A START grava hticsav2.hsg com \"E1M1 A\""
fi

# sem o IWAD: cada motor sai sozinho com erro
for m in crispy-doom crispy-heretic crispy-strife crispy-hexen; do
    B="$O/$m"; L2="$T/sem_iwad_$m.log"; mkdir -p "$T/saves_sem_$m"
    rodar "$L2" "$T/saves_sem_$m" -iwad "$T/nao_existe.wad"
    wait "$_rp"; r=$?
    [ "$r" -ne 0 ] && [ "$r" -ne 124 ] && [ "$r" -ne 137 ]; conta $? "$m sem o IWAD: sai sozinho com erro (rc=$r), sem travar"
done

echo "falhas: $F"
[ "$F" -eq 0 ]
