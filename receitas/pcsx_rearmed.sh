# PS1 (plano D-04): dynarec ari64, GPU NEON, CHD; BIOS interna (HLE) quando nao houver BIOS em system/.
RECEITA_OPCOES="platform=unix ARCH=arm DYNAREC=ari64 BUILTIN_GPU=neon HAVE_NEON_ASM=1 HAVE_CHD=1 HAVE_PHYSICAL_CDROM=0"
receita_compilar() { make -f Makefile.libretro -j"$NPROC" $RECEITA_OPCOES CC="$CC" CXX="$CXX" AR="$AR"; }
receita_instalar() { "$STRIP" -o "$OUT/cores/pcsx_rearmed_libretro.so" pcsx_rearmed_libretro.so; }
