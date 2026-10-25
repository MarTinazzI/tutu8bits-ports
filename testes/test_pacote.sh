#!/bin/sh
# ==============================================================================
# tutu8bits — teste do pacote (spec 011, T15; CA-12 parte do PC): monta o zip, descompacta num
# diretorio vazio e confere a arvore do plano §3, as licencas, a auditoria e que a UI abre a partir
# dele (motor no qemu, video "dummy") e que o lancador monta o retroarch.cfg com a pasta real.
# Uso: sh ports/testes/test_pacote.sh
# ==============================================================================
REPO="$(cd "$(dirname "$0")/../.." && pwd)"
TC="$REPO/.cache/toolchains/armv5-eabi--glibc--stable-2023.11-1"
SR="$TC/arm-buildroot-linux-gnueabi/sysroot"
mkdir -p "$REPO/.cache/testes"
TMP="$(mktemp -d "$REPO/.cache/testes/pacote.XXXXXX")"
trap 'rm -rf "$TMP"' EXIT
FALHAS=0
ok()    { echo "  ok    $1"; }
falha() { echo "  FALHA $1"; FALHAS=$((FALHAS + 1)); }

echo "test_pacote.sh"
"$REPO/ports/montar.sh" > "$TMP/montar.txt" 2>&1; rc=$?
V=$(sed -n 's/^#define TUTU_VERSAO "\(.*\)"/\1/p' "$REPO/src/motor/motor.h")
Z="$REPO/.cache/pacote/tutu8bits-$V.zip"
[ "$rc" = 0 ] && [ -f "$Z" ] && grep -q 'auditoria: nenhum dos' "$TMP/montar.txt" \
    && ok "pacote montado e auditado (nada bate com o sistema de fabrica)" || { falha "montar ($rc)"; cat "$TMP/montar.txt"; }

C="$TMP/cartao"; mkdir -p "$C"
( cd "$C" && unzip -q "$Z" )
faltam=""
for f in simulator/3168/em_ui.sh LEIA-ME-tutu8bits.md roms/LEIA-ME.txt tutu8bits/iniciar.sh tutu8bits/lancar.sh tutu8bits/comum.sh tutu8bits/backup_nand.sh \
         tutu8bits/bin/tutu tutu8bits/bin/bootscreen tutu8bits/bin/m17atalhos tutu8bits/bin/medir013 tutu8bits/bin/lebateria tutu8bits/lib/libSDL2-2.0.so.0 \
         tutu8bits/lua/inicio.lua tutu8bits/lua/seguro.lua tutu8bits/lua/frontend/init.lua tutu8bits/lua/ui/init.lua \
         tutu8bits/dados/sistemas.lua tutu8bits/dados/estilo.lua tutu8bits/temas/padrao/tema.lua \
         tutu8bits/temas/padrao/fontes/PressStart2P-Regular.ttf tutu8bits/temas/padrao/transicao.png \
         tutu8bits/exemplos/temas/pastel/estilo.lua tutu8bits/exemplos/temas/gameboy/estilo.lua \
         tutu8bits/exemplos/temas/neon/estilo.lua tutu8bits/exemplos/.pacote \
         tutu8bits/docs/temas.md tutu8bits/retroarch/retroarch tutu8bits/retroarch/retroarch.cfg.modelo \
         tutu8bits/retroarch/config/retroarch-core-options.cfg tutu8bits/cores/snes9x2005_plus_libretro.so \
         tutu8bits/cores/pcsx_rearmed_libretro.so tutu8bits/LICENCAS/LEIA-ME.md tutu8bits/LICENCAS/tutu8bits-MIT.txt \
         tutu8bits/gametank/GameTankEmulator tutu8bits/gametank/gamecontrollerdb.txt tutu8bits/LICENCAS/gametank-MIT.txt \
         tutu8bits/cores/ppsspp_libretro.so tutu8bits/ppsspp/PPSSPPSDLTUTU tutu8bits/ppsspp/assets/compat.ini \
         tutu8bits/ppsspp/assets/flash0/font/ltn0.pgf tutu8bits/ppsspp/PPSSPP/compat.ini tutu8bits/ppsspp/PPSSPP/ppge_atlas.zim \
         tutu8bits/opcoes/psp.cfg tutu8bits/opcoes/psp.opt tutu8bits/opcoes/psp.ini \
         tutu8bits/opcoes/psp_controls.ini tutu8bits/LICENCAS/ppsspp-GPL-2.0.txt tutu8bits/LICENCAS/ffmpeg-LGPL-2.1.txt \
         tutu8bits/dados/jogos.lua tutu8bits/jogos/nxengine/nx tutu8bits/jogos/nxengine/extract \
         tutu8bits/jogos/nxengine/data/sprites.sif tutu8bits/lib/libSDL2_mixer-2.0.so.0 tutu8bits/lib/libSDL2_image-2.0.so.0 \
         tutu8bits/LICENCAS/NXEngine-evo-GPL-3.0.txt tutu8bits/LICENCAS/SDL2_mixer-Zlib.txt tutu8bits/LICENCAS/SDL2_image-Zlib.txt \
         roms/jogos/LEIA-ME.txt roms/jogos/cavestory/LEIA-ME.txt roms/jogos/doom/LEIA-ME.txt \
         roms/jogos/heretic/LEIA-ME.txt roms/jogos/strife/LEIA-ME.txt roms/jogos/tyrian/LEIA-ME.txt roms/jogos/hexen/LEIA-ME.txt \
         tutu8bits/jogos/crispy/crispy-hexen tutu8bits/jogos/crispy/hexen.cfg tutu8bits/jogos/crispy/crispy-hexen.cfg \
         tutu8bits/jogos/opentyrian/opentyrian tutu8bits/jogos/opentyrian/padrao/opentyrian.cfg \
         tutu8bits/LICENCAS/OpenTyrian-GPL-2.0.txt tutu8bits/dados/nomes.txt \
         tutu8bits/jogos/rogue/rogue tutu8bits/jogos/rogue/LEIA-ME.txt tutu8bits/dados/rogue.cfg \
         tutu8bits/LICENCAS/Rogue-BSD.txt tutu8bits/LICENCAS/misc-fixed-6x10-dominio-publico.txt \
         tutu8bits/jogos/crispy/crispy-heretic tutu8bits/jogos/crispy/crispy-strife tutu8bits/jogos/crispy/heretic.cfg \
         tutu8bits/jogos/crispy/crispy-heretic.cfg tutu8bits/jogos/crispy/strife.cfg tutu8bits/jogos/crispy/crispy-strife.cfg \
         tutu8bits/jogos/blasphemer/blasphem.wad tutu8bits/LICENCAS/Blasphemer-BSD.md \
         tutu8bits/jogos/crispy/crispy-doom tutu8bits/jogos/crispy/default.cfg tutu8bits/jogos/crispy/crispy-doom.cfg \
         tutu8bits/jogos/freedoom/freedoom1.wad tutu8bits/jogos/freedoom/freedoom2.wad \
         tutu8bits/LICENCAS/Crispy-Doom-GPL-2.0.md tutu8bits/LICENCAS/Freedoom-BSD.txt; do
    [ -f "$C/$f" ] || faltam="$faltam $f"
done
for d in bios saves states screenshots roms/ps1 roms/snes roms/gba roms/pico8 roms/gametank; do [ -d "$C/$d" ] || faltam="$faltam $d/"; done
[ -z "$faltam" ] && ok "arvore do plano §3 completa (trampolim, tutu8bits/, pastas do usuario)" || falha "faltam:$faltam"
# spec 028 (RF-02): os binarios chamados pelo produto sao conferidos no src/testes/test_estrutura.sh (e);
# o pacote e o cartao/ inteiro, e a arvore acima ja exige os cinco (incl. o lebateria)
# spec 024 (CA-09): a base traz so o tema padrao; exemplos em exemplos/temas com o id do pacote; opcoes na base;
# nada de config/ no zip; home/ e do usuario (criada no boot): no zip so o LEIA-ME.txt (spec 028)
[ "$(ls "$C/tutu8bits/temas")" = padrao ] && [ ! -e "$C/tutu8bits/config" ] && [ "$(ls -A "$C/home")" = LEIA-ME.txt ] \
  && grep -q '^[0-9a-z]*-[0-9]\{14\}$' "$C/tutu8bits/exemplos/.pacote" && ! find "$C" -name 'exemplo_triangulo' | grep -q . \
  && ! grep -rq 'base = ' "$C/tutu8bits/exemplos/temas" \
    && ok "024: base so com o tema padrao; exemplos em exemplos/temas (sem base =) com .pacote; sem config/; home/ so com o LEIA-ME.txt (028)" \
    || { falha "024: arvore de temas/config"; ls "$C/tutu8bits/temas" "$C/tutu8bits/exemplos"; cat "$C/tutu8bits/exemplos/.pacote"; }
[ "$(ls "$C/tutu8bits/cores" | wc -l)" = 20 ] && [ ! -e "$C/tutu8bits/cores/tyrquake_libretro.so" ] && [ ! -d "$C/tutu8bits/lua/testes" ] \
  && ! find "$C" -name '*mupen*' -not -path '*/LICENCAS/*' -o -name '*.gtr' -o -name 'input_cfg.toml' -o -name 'PPSSPPSDL' | grep -q . \
  && [ ! -d "$C/tutu8bits/ppsspp/assets/debugger" ] && [ ! -d "$C/bios/PPSSPP" ] \
    && ok "os 20 nucleos (N64 parallel_n64, spec 015; PSP ppsspp, spec 023; os 7 da 049; sem mupen; o Quake e nativo desde a 050, sem o tyrquake), sem ROMs de GameTank, sem o input_cfg de teclado, sem os testes, PSP fora da bios/" || { falha "conteudo extra"; ls "$C/tutu8bits/cores"; }
# spec 030 (CA-07): o Cave Story vem so com o motor; nada do freeware (Doukutsu.exe, data/ do jogo, stage.dat)
# no pacote, e em roms/jogos/ so os LEIA-ME.txt
# (cada jogo nativo novo poe a sua pasta com o LEIA-ME.txt: a conferencia e "so LEIA-ME.txt", nao a lista fixa)
[ -z "$(find "$C/roms/jogos" -type f ! -name LEIA-ME.txt)" ] && [ -f "$C/roms/jogos/cavestory/LEIA-ME.txt" ] \
  && ! find "$C" -iname 'Doukutsu.exe' -o -iname 'stage.dat' -o -iname 'npc.tbl' -o -iname '*.pxt' | grep -q . \
  && grep -q 'NXEngine-evo' "$C/tutu8bits/LICENCAS/LEIA-ME.md" \
    && ok "030: Cave Story so com o motor e as licencas; nada do jogo no pacote; roms/jogos/ so com os LEIA-ME.txt" \
    || { falha "030: conteudo do jogo nativo"; find "$C/roms/jogos" -type f; }
# spec 031 (CA-07): o Freedoom vem inteiro (os dois WADs, com o sha256 do zip fixado); nenhum WAD original
[ "$(wc -c < "$C/tutu8bits/jogos/freedoom/freedoom1.wad")" = 28795076 ] && [ "$(wc -c < "$C/tutu8bits/jogos/freedoom/freedoom2.wad")" = 28787748 ] \
  && ! find "$C" -iname 'DOOM.WAD' -o -iname 'DOOM2.WAD' -o -iname 'DOOM1.WAD' | grep -q . \
  && grep -q 'Crispy Doom' "$C/tutu8bits/LICENCAS/LEIA-ME.md" && grep -q 'joyb_menu_activate' "$C/tutu8bits/jogos/crispy/crispy-doom.cfg" \
    && ok "031: Crispy Doom, configuracao inicial e Freedoom 1 e 2 no pacote; nenhum WAD original; licencas" \
    || { falha "031: Doom no pacote"; ls -la "$C/tutu8bits/jogos/freedoom" "$C/tutu8bits/jogos/crispy"; }
# spec 033 (CA-06): Crispy Heretic e Strife com a configuracao inicial (Strife com show_endoom 0); o Blasphemer
# inteiro (20417448 bytes, do zip fixado) com a licenca; nenhum WAD comercial do Heretic nem do Strife
[ "$(wc -c < "$C/tutu8bits/jogos/blasphemer/blasphem.wad")" = 20417448 ] \
  && ! find "$C" -iname 'HERETIC.WAD' -o -iname 'HERETIC1.WAD' -o -iname 'STRIFE1.WAD' -o -iname 'VOICES.WAD' | grep -q . \
  && grep -q '^show_endoom  *0$' "$C/tutu8bits/jogos/crispy/crispy-strife.cfg" \
  && grep -q 'Blasphemer' "$C/tutu8bits/LICENCAS/LEIA-ME.md" && grep -q 'Crispy Strife' "$C/tutu8bits/LICENCAS/LEIA-ME.md" \
    && ok "033: Crispy Heretic e Strife, configuracao inicial e Blasphemer no pacote; nenhum WAD comercial; licencas" \
    || { falha "033: Heretic/Strife no pacote"; ls -la "$C/tutu8bits/jogos/blasphemer" "$C/tutu8bits/jogos/crispy"; }
# spec 034 (CA-07): o OpenTyrian com a configuracao inicial em padrao/ (nunca ao lado do binario: modo portatil) e a
# lista de nomes do sistema; nenhum arquivo do Tyrian (o zip so traz a licenca comercial da Epic); licenca
[ ! -e "$C/tutu8bits/jogos/opentyrian/opentyrian.cfg" ] \
  && grep -qx "section 'joystick' 'i2c-keys'" "$C/tutu8bits/jogos/opentyrian/padrao/opentyrian.cfg" \
  && [ "$(cat "$C/tutu8bits/dados/nomes.txt")" = "$(printf 'Tutu\nMartinazzi\nDinheiro')" ] \
  && ! find "$C" -iname 'tyrian*.lvl' -o -iname 'tyrian.hdt' -o -iname 'tyrian21*' -o -iname '*.shp' -o -iname 'voices.snd' | grep -q . \
  && grep -q 'OpenTyrian' "$C/tutu8bits/LICENCAS/LEIA-ME.md" \
    && ok "034: OpenTyrian com a configuracao em padrao/ e a lista de nomes; nenhum arquivo do Tyrian; licencas" \
    || { falha "034: Tyrian no pacote"; ls -laR "$C/tutu8bits/jogos/opentyrian"; }
# spec 035 (CA-09): o Rogue inteiro (motor ARM, LEIA-ME com os controles), os tempos do controle e as licencas
file "$C/tutu8bits/jogos/rogue/rogue" | grep -q 'ARM' && grep -q 'segure VOL+ por 2 s; a partida e salva' "$C/tutu8bits/jogos/rogue/LEIA-ME.txt" \
  && grep -q '^acorde_ms=60$' "$C/tutu8bits/dados/rogue.cfg" && grep -q 'Rogue 5.4.4' "$C/tutu8bits/LICENCAS/LEIA-ME.md" \
  && grep -q 'Redistribution and use' "$C/tutu8bits/LICENCAS/Rogue-BSD.txt" \
    && ok "035: Rogue no pacote (motor, LEIA-ME, rogue.cfg) e as licencas (BSD e a da fonte)" \
    || { falha "035: Rogue no pacote"; ls -la "$C/tutu8bits/jogos/rogue"; }
# spec 037 (CA-05): os 3 motores do Wolf4SDL; o shareware 1.4 inteiro (os 14 arquivos, com o VENDOR.DOC e o READ1ST.TXT);
# nenhum arquivo do completo nem do Spear; as licencas (GPL, id e o OPL do MAME)
file "$C/tutu8bits/jogos/wolf4sdl/wolf3d-sw" | grep -q 'ARM' && [ -x "$C/tutu8bits/jogos/wolf4sdl/wolf3d" ] && [ -x "$C/tutu8bits/jogos/wolf4sdl/spear" ] \
  && [ "$(ls "$C/tutu8bits/jogos/wolf3d" | wc -l)" = 13 ] && [ -f "$C/tutu8bits/jogos/wolf3d/VSWAP.WL1" ] \
  && [ -f "$C/tutu8bits/jogos/wolf3d/VENDOR.DOC" ] && [ -f "$C/tutu8bits/jogos/wolf3d/READ1ST.TXT" ] \
  && ! find "$C" -iname '*.wl6' -o -iname '*.sod' -o -iname '*.sd2' -o -iname '*.sd3' | grep -q . \
  && [ -s "$C/tutu8bits/LICENCAS/Wolf4SDL-GPL-2.0.txt" ] && [ -s "$C/tutu8bits/LICENCAS/Wolf4SDL-OPL-MAME-nao-comercial.txt" ] \
  && grep -q 'Wolfenstein 3D shareware 1.4' "$C/tutu8bits/LICENCAS/LEIA-ME.md" && [ -f "$C/roms/jogos/wolf3d/LEIA-ME.txt" ] \
    && ok "037: Wolf4SDL (3 motores), o shareware inteiro, nada do completo/Spear; licencas e LEIA-ME" \
    || { falha "037: Wolf3D no pacote"; ls -la "$C/tutu8bits/jogos/wolf3d" "$C/tutu8bits/jogos/wolf4sdl"; }
# spec 040 (CA-05): o JFDuke3D, o duke3d.cfg inicial e o gamecontrollerdb; o shareware 1.3d inteiro (os 17 arquivos do 7z);
# nenhum outro GRP; as licencas (GPL do jogo e a do Build)
DK="$C/tutu8bits/jogos/jfduke3d"
file "$DK/duke3d" | grep -q 'ARM' && grep -q '^ScreenWidth = 320$' "$DK/duke3d.cfg" \
  && grep -q '^19001e5a010000001200000000010000,i2c-keys,.*lefttrigger:b8,righttrigger:b10,' "$DK/gamecontrollerdb.txt" \
  && [ "$(ls "$C/tutu8bits/jogos/duke3d" | wc -l)" = 17 ] && [ -f "$C/tutu8bits/jogos/duke3d/DUKE3D.GRP" ] \
  && [ -f "$C/tutu8bits/jogos/duke3d/LICENSE.TXT" ] && [ "$(find "$C" -iname '*.grp' | wc -l)" = 1 ] \
  && [ -s "$C/tutu8bits/LICENCAS/JFDuke3D-GPL-2.0.txt" ] && grep -q 'commercial' "$C/tutu8bits/LICENCAS/Build-licenca-Ken-Silverman.txt" \
  && grep -q 'Duke Nukem 3D shareware 1.3d' "$C/tutu8bits/LICENCAS/LEIA-ME.md" && [ -f "$C/roms/jogos/duke3d/LEIA-ME.txt" ] \
    && ok "040: JFDuke3D (motor, cfg, gamecontrollerdb), o shareware inteiro, um GRP so; licencas e LEIA-ME" \
    || { falha "040: Duke 3D no pacote"; ls -la "$DK" "$C/tutu8bits/jogos/duke3d"; }
# spec 039 (CA-05): o LibreQuake lite (os .pak e a licenca); nenhum .pak do Quake; o perfil do nucleo saiu (spec 050, CA-08)
LQ="$C/tutu8bits/jogos/librequake/id1"
[ ! -e "$C/tutu8bits/opcoes/tyrquake.cfg" ] && [ ! -e "$C/tutu8bits/opcoes/tyrquake.opt" ] \
  && [ -s "$LQ/pak0.pak" ] && [ -s "$LQ/pak1.pak" ] && [ -f "$LQ/docs/README-IMPORTANT-LICENCE-INFO" ] \
  && [ "$(find "$C" -iname '*.pak' | wc -l)" = 2 ] && grep -q 'Redistribution and use' "$C/tutu8bits/LICENCAS/LibreQuake-BSD-3.txt" \
  && [ -s "$C/tutu8bits/LICENCAS/TyrQuake-GPL-2.0.txt" ] && grep -q 'LibreQuake' "$C/tutu8bits/LICENCAS/LEIA-ME.md" \
  && [ -f "$C/roms/jogos/quake/LEIA-ME.txt" ] \
    && ok "039: sem o perfil do nucleo; o LibreQuake lite (2 .pak, so os dele) e as licencas; LEIA-ME" \
    || { falha "039: Quake no pacote"; ls -la "$LQ"; }
# spec 050 (RF-10): o Quake nativo (TyrQuake original) com o config.cfg dos botoes e o gamecontrollerdb; licenca e LEIA-ME
QN="$C/tutu8bits/jogos/tyrquake"
file "$QN/tyr-quake" | grep -q 'ARM' && grep -q '^bind "PAD_L3" "m17_devagar"$' "$QN/config.cfg" && [ -s "$QN/gamecontrollerdb.txt" ] \
  && grep -q 'GNU GENERAL PUBLIC LICENSE' "$C/tutu8bits/LICENCAS/TyrQuake-GPL-2.0.txt" \
  && grep -q 'TyrQuake original' "$C/tutu8bits/LICENCAS/LEIA-ME.md" && grep -q 'motor TyrQuake' "$C/roms/jogos/quake/LEIA-ME.txt" \
    && ok "050: Quake nativo (motor, config.cfg, gamecontrollerdb), licenca e LEIA-ME" \
    || { falha "050: Quake nativo no pacote"; ls -la "$QN"; }
# spec 038 (CA-05): o Crispy Hexen e a configuracao dele; nenhum WAD do Hexen (nem a demo) no pacote
file "$C/tutu8bits/jogos/crispy/crispy-hexen" | grep -q 'ARM' && grep -q '^joyb_jump  *6$' "$C/tutu8bits/jogos/crispy/hexen.cfg" \
  && ! find "$C" -iname 'hexen.wad' -o -iname 'hexdd.wad' -o -iname 'hexndemo*' | grep -q . \
  && grep -q 'Crispy Hexen' "$C/tutu8bits/LICENCAS/LEIA-ME.md" && grep -q 'HEXDD.WAD' "$C/roms/jogos/hexen/LEIA-ME.txt" \
    && ok "038: Crispy Hexen e a configuracao no pacote; nenhum WAD do Hexen; LEIA-ME e licencas" \
    || { falha "038: Hexen no pacote"; ls -la "$C/tutu8bits/jogos/crispy"; }
# spec 036 (CA-09): o NetHack inteiro (motor e recover ARM, dados, sysconf, nethackrc, LEIA-ME), os tempos e a NGPL
N="$C/tutu8bits/jogos/nethack"
file "$N/nethack" | grep -q 'ARM' && file "$N/recover" | grep -q 'ARM' && [ -s "$N/nhdat" ] && [ -s "$N/symbols" ] \
  && grep -q '^CHECK_SAVE_UID=0$' "$N/sysconf" && grep -q '^OPTIONS=color' "$N/nethackrc" \
  && grep -q 'segure VOL+ por 2 s; a partida e salva' "$N/LEIA-ME.txt" && grep -q 'teclado' "$N/LEIA-ME.txt" \
  && grep -q '^acorde_ms=60$' "$C/tutu8bits/dados/nethack.cfg" && grep -q 'NetHack 3.6.7' "$C/tutu8bits/LICENCAS/LEIA-ME.md" \
  && grep -q 'NETHACK GENERAL PUBLIC LICENSE' "$C/tutu8bits/LICENCAS/NetHack-NGPL.txt" \
    && ok "036: NetHack no pacote (motor, recover, dados, sysconf, nethackrc, LEIA-ME, nethack.cfg) e a NGPL" \
    || { falha "036: NetHack no pacote"; ls -la "$N"; }
# spec 047 (CA-07): o FreeDink (motor, fonte, os dados do Dink), o FreePats (crude.cfg e os instrumentos), as libs
# SDL2_ttf/SDL2_gfx, a roda do Pilgrim's Quest, o LEIA-ME dos D-Mods e as licencas; NENHUM D-Mod (o unico dmod.diz e o
# do proprio Dink, em jogos/dink/dink/)
DK="$C/tutu8bits/jogos/dink"
licencas_dink() {
    for l in FreeDink-GPL-3.0.txt LiberationSans-1.05-GPL-2.0-excecoes.txt freedink-data-README.txt \
             freedink-data-README-REPLACEMENTS.txt FreePats-GPL-2.0-README.txt Timidity-Artistic.txt SDL2_ttf-Zlib.txt \
             FreeType-FTL.txt SDL2_gfx-Zlib.txt; do
        [ -s "$C/tutu8bits/LICENCAS/$l" ] || { echo "    falta LICENCAS/$l"; return 1; }
    done
}
[ -x "$DK/freedink" ] && [ -f "$DK/LiberationSans-Regular.ttf" ] && [ -f "$DK/dink/Dink.dat" ] && [ -d "$DK/dink/graphics" ] \
  && [ -f "$C/tutu8bits/midi/freepats/crude.cfg" ] && [ -d "$C/tutu8bits/midi/freepats/Tone_000" ] \
  && [ -d "$C/tutu8bits/midi/freepats/Drum_000" ] && [ -f "$C/tutu8bits/lib/libSDL2_ttf-2.0.so.0" ] \
  && [ -f "$C/tutu8bits/lib/libSDL2_gfx-1.0.so.0" ] && [ -f "$C/tutu8bits/dados/rodas/dink_pq.roda" ] \
  && [ -f "$C/roms/jogos/dink/LEIA-ME.txt" ] \
  && [ "$(find "$C" -iname 'dmod.diz' | sed "s#^$C/##")" = "tutu8bits/jogos/dink/dink/dmod.diz" ] \
  && ! find "$C" -iname '*.dmod' | grep -q . \
  && licencas_dink \
  && grep -q 'GNU FreeDink' "$C/tutu8bits/LICENCAS/LEIA-ME.md" && grep -q 'FreePats' "$C/tutu8bits/LICENCAS/LEIA-ME.md" \
    && ok "047: FreeDink, dados do Dink, FreePats, SDL2_ttf/gfx, roda do PQ, LEIA-ME dos D-Mods e licencas; nenhum D-Mod" \
    || { falha "047: Dink no pacote"; ls -la "$DK" "$C/tutu8bits/midi/freepats"; find "$C" -iname 'dmod.diz'; }
grep -q '^19001e5a010000001200000000010000,i2c-keys,a:b6,.*,back:b12,.*,leftx:a0,lefty:a1,.*platform:Linux,$' "$C/tutu8bits/ppsspp/assets/gamecontrollerdb.txt" \
  && [ "$(grep -c '^19001e5a010000001200000000010000,' "$C/tutu8bits/ppsspp/assets/gamecontrollerdb.txt")" = 1 ] \
  && [ "$(wc -l < "$C/tutu8bits/ppsspp/assets/gamecontrollerdb.txt")" -gt 100 ] \
    && ok "PSP: a linha do i2c-keys (com SELECT e analogicos) somada ao gamecontrollerdb do PPSSPP" || { falha "gamecontrollerdb do PSP"; tail -2 "$C/tutu8bits/ppsspp/assets/gamecontrollerdb.txt"; }
grep -q '^19001e5a010000001200000000010000,i2c-keys,a:b6,.*,start:b5,platform:Linux,$' "$C/tutu8bits/gametank/gamecontrollerdb.txt" \
  && [ "$(wc -l < "$C/tutu8bits/gametank/gamecontrollerdb.txt")" = 1 ] && ! grep -q 'back:' "$C/tutu8bits/gametank/gamecontrollerdb.txt" \
    && ok "GameTank: mapeamento de game controller do i2c-keys no pacote (sem o SELECT)" || { falha "gamecontrollerdb"; cat "$C/tutu8bits/gametank/gamecontrollerdb.txt"; }
[ "$(wc -l < "$C/tutu8bits/LICENCAS/Lua-MIT.txt")" -lt 30 ] && grep -q 'Permission is hereby granted' "$C/tutu8bits/LICENCAS/Lua-MIT.txt" \
  && [ "$(ls "$C/tutu8bits/LICENCAS" | wc -l)" -ge 19 ] && grep -q 'nao pode ser vendido\|não pode ser vendido' "$C/tutu8bits/LICENCAS/LEIA-ME.md" \
    && ok "licencas: tutu8bits, Lua, stb, SDL2, RetroArch, nucleos, fontes; aviso de nao comercial" || falha "licencas"

# a UI abre a partir do pacote (tema padrao, 1 quadro)
cp "$C/tutu8bits/lib/libSDL2-2.0.so.0" "$TMP/"; echo "" > "$TMP/egl.c"; "$TC/bin/arm-buildroot-linux-gnueabi-gcc" -shared -o "$TMP/libEGL.so" "$TMP/egl.c"
mkdir -p "$C/home/config" "$C/tutu8bits/cache" "$C/tutu8bits/logs" "$TMP/tmp"
TUTU_TMP="$TMP/tmp" SDL_VIDEODRIVER=dummy TUTU_SOFTWARE=1 LD_LIBRARY_PATH="$TMP" timeout 60 \
    qemu-arm-static -L "$SR" "$C/tutu8bits/bin/tutu" --raiz "$C/tutu8bits" --quadros 2 --log "$TMP/ui.txt"; rc=$?
[ "$rc" = 0 ] && grep -q 'ui: tema padrao' "$TMP/ui.txt" && ! grep -q 'ERRO' "$TMP/ui.txt" \
    && ok "a UI abre a partir do pacote (tema padrao, sem erros)" || { falha "UI do pacote ($rc)"; cat "$TMP/ui.txt"; }

# o lancador monta o retroarch.cfg trocando @RAIZ@ pela pasta real
: > "$C/roms/snes/Jogo.sfc"
printf 'tipo=jogo\nsistema=snes\npasta=snes\nrom=%s\nemulador=snes9x2005_plus\nlancador=retroarch\nnucleo=snes9x2005_plus\n' "$C/roms/snes/Jogo.sfc" > "$TMP/tmp/pedido"
printf '#!/bin/sh\necho "[INFO] [Core] Unloading core..."\n' > "$TMP/ra"; chmod +x "$TMP/ra"
TUTU_TMP="$TMP/tmp" TUTU_RA="$TMP/ra" TUTU_ATALHOS=true sh "$C/tutu8bits/lancar.sh"
grep -q "^libretro_directory = \"$C/tutu8bits/retroarch/cores\"" "$TMP/tmp/retroarch.cfg" && ! grep -q '@RAIZ@' "$TMP/tmp/retroarch.cfg" \
  && grep -q "^savefile_directory = \"$C/saves\"" "$TMP/tmp/ra_pastas.cfg" && grep -q '^fim=normal' "$TMP/tmp/ultimo" \
  && [ -d "$C/tutu8bits/retroarch/cache" ] && [ -d "$C/tutu8bits/retroarch/config/playlists" ] \
    && ok "lancador: retroarch.cfg montado com a pasta real; pastas do RetroArch criadas (cache: .zip do gpsp); saves na raiz" || { falha "cfg do lancador"; grep -n 'directory' "$TMP/tmp/retroarch.cfg" | head -5; cat "$TMP/tmp/ultimo"; }

# o lancador abre um jogo de GameTank a partir do pacote (emulador falso: o de verdade e ARM)
: > "$C/roms/gametank/Jogo.gtr"
printf 'tipo=jogo\nsistema=gametank\npasta=gametank\nrom=%s\nemulador=gametank\nlancador=gametank\n' "$C/roms/gametank/Jogo.gtr" > "$TMP/tmp/pedido"
printf '#!/bin/sh\necho "loading $1 gcc=$SDL_GAMECONTROLLERCONFIG_FILE ld=$LD_LIBRARY_PATH"\n' > "$TMP/gt"; chmod +x "$TMP/gt"
TUTU_TMP="$TMP/tmp" TUTU_GT="$TMP/gt" TUTU_ATALHOS=true sh "$C/tutu8bits/lancar.sh"
grep -q '^fim=normal' "$TMP/tmp/ultimo" && grep -q '^sistema=gametank' "$TMP/tmp/ultimo" \
  && grep -q "^loading $C/roms/gametank/Jogo.gtr gcc=$C/tutu8bits/gametank/gamecontrollerdb.txt ld=$C/tutu8bits/lib" "$C/tutu8bits/logs/jogos/ultimo.txt" \
    && ok "lancador: GameTank com a ROM, o mapeamento e a libSDL2 do pacote" || { falha "lancador gametank"; cat "$TMP/tmp/ultimo" "$C/tutu8bits/logs/jogos/ultimo.txt"; }

# a copia para o cartao (levar.sh, spec 028) e testada no test_levar.sh

# auditoria (spec 023, D-13; 049: e um texto de licenca do LICENCAS/): um asset publico do PPSSPP que a fabrica tambem tem passa pela
# procedencia; qualquer outro arquivo igual ao da fabrica continua barrando o pacote
mkdir -p "$TMP/fab_pub" "$TMP/fab_outro"
cp "$REPO/.cache/emu/out/system/PPSSPP/flash0/font/ltn0.pgf" "$TMP/fab_pub/"
cp "$REPO/cartao/tutu8bits/LICENCAS/RetroArch-GPL-3.0.txt" "$TMP/fab_pub/COPYING"   # spec 049: texto de licenca publico
cp "$REPO/cartao/tutu8bits/lancar.sh" "$TMP/fab_outro/lancar_copiado.sh"
FABRICA="$TMP/fab_pub" "$REPO/ports/montar.sh" --sem-zip > "$TMP/m_pub.txt" 2>&1; r1=$?
FABRICA="$TMP/fab_outro" "$REPO/ports/montar.sh" --sem-zip > "$TMP/m_outro.txt" 2>&1; r2=$?
[ "$r1" = 0 ] && grep -q 'auditoria: 2 arquivos publicos (PPSSPP' "$TMP/m_pub.txt" \
  && [ "$r2" != 0 ] && grep -q 'arquivo(s) do sistema de fabrica' "$TMP/m_outro.txt" \
    && ok "auditoria: asset publico do PPSSPP e texto de licenca (049) aceitos pela procedencia; outro arquivo da fabrica ainda barra" || { falha "auditoria com procedencia ($r1/$r2)"; tail -3 "$TMP/m_pub.txt" "$TMP/m_outro.txt"; }

echo "falhas: $FALHAS"
[ "$FALHAS" -eq 0 ]
