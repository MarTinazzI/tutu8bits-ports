# Mega Drive / Master System / Game Gear (plano D-04): ARCH=arm liga o asm e os DRCs de ARM do proprio Makefile.
RECEITA_OPCOES="platform=unix ARCH=arm"
# O gerador do Cyclone (68000 em asm ARM) roda durante a compilacao e e compilado com o gcc do PC
# (CYCLONE_CC). Por isso CC/CXX vao so pelo ambiente (ambiente.sh): na linha do make eles valeriam
# tambem no sub-make do gerador e o fariam sair em ARM.
receita_compilar() { AS="$EMU_TC/bin/$EMU_HOST-as" make -f Makefile.libretro -j"$NPROC" $RECEITA_OPCOES CYCLONE_CC=gcc CYCLONE_CXX=g++; }
receita_instalar() { "$STRIP" -o "$OUT/cores/picodrive_libretro.so" picodrive_libretro.so; }
