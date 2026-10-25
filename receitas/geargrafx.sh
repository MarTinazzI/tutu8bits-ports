# PC Engine (spec 049, D-01): Geargrafx, o outro candidato. FORA DO PRODUTO (sessao 1 da 049: 42 fps com 87-103 %
# de um nucleo; o Beetle PCE Fast da 60 com ~35 %). A receita e a linha do test_qemu ficam para quem quiser medir de novo. O Makefile do libretro
# fica em platforms/libretro. LTO=0: com LTO o link refaz o codigo sem o -mfpu do CFLAGS ("target specific builtin
# not available").
RECEITA_OPCOES="platform=unix LTO=0"
receita_compilar() { make -C platforms/libretro -j"$NPROC" $RECEITA_OPCOES CC="$CC" CXX="$CXX" AR="$AR"; }
receita_instalar() { "$STRIP" -o "$OUT/cores/geargrafx_libretro.so" platforms/libretro/geargrafx_libretro.so; }
