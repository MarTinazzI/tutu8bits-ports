# GBA (plano D-04): dynarec ARM. UNAME forcado: sem isso o Makefile ve o x86_64 do PC e liga o dynarec x86.
RECEITA_OPCOES="platform=unix UNAME=armv7l CPU_ARCH=arm HAVE_DYNAREC=1"
receita_compilar() { make -j"$NPROC" $RECEITA_OPCOES CC="$CC" CXX="$CXX" AR="$AR"; }
receita_instalar() { "$STRIP" -o "$OUT/cores/gpsp_libretro.so" gpsp_libretro.so; }
