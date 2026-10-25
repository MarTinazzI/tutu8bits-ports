# Arcade (spec 010, plano D-03): FBNeo. platform=armv-neon: Cyclone (68000 em asm ARM) e NEON.
# CC/CXX so pelo ambiente (ambiente.sh), como no picodrive.
RECEITA_OPCOES="platform=armv-neon USE_CYCLONE=1 HAVE_NEON=1"
receita_compilar() { make -C src/burner/libretro -j"$NPROC" $RECEITA_OPCOES; }
receita_instalar() { "$STRIP" -o "$OUT/cores/fbneo_libretro.so" src/burner/libretro/fbneo_libretro.so; }
