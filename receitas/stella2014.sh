# Atari 2600 (spec 049, D-01): o Stella de 2014, o leve (o Stella atual e C++ pensado para PC).
RECEITA_OPCOES="platform=unix"
receita_compilar() { make -j"$NPROC" $RECEITA_OPCOES CC="$CC" CXX="$CXX" AR="$AR"; }
receita_instalar() { "$STRIP" -o "$OUT/cores/stella2014_libretro.so" stella2014_libretro.so; }
