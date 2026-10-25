# Arcade, classicos leves (spec 010, plano D-03): MAME 2003-Plus (romset 0.78+).
# Spec 053: sem o -I$EMU_INC global. O zlib embutido do nucleo (src/lib/zlib) pegava o zlib.h de .cache/emu/include
# (entrou depois deste nucleo, para o mupen64plus) e nao compilava num clone limpo; o nucleo nao usa nenhum
# cabecalho de la.
RECEITA_OPCOES="platform=unix ARM=1"
receita_compilar() { CFLAGS="${CFLAGS//-I$EMU_INC/}" CXXFLAGS="${CXXFLAGS//-I$EMU_INC/}" make -j"$NPROC" $RECEITA_OPCOES; }
receita_instalar() { "$STRIP" -o "$OUT/cores/mame2003_plus_libretro.so" mame2003_plus_libretro.so; }
