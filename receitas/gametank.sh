# GameTank (spec 010 D-05; spec 012 D-07/D-01): GameTank Emulator (C++/SDL2, MIT), programa proprio
# (nao ha nucleo libretro). Compilado contra os cabecalhos fixados do SDL2 2.28.5 e o soname
# libSDL2-2.0.so.0; em runtime usa a libSDL2 do cartao, que desde o spike 011-A e a DO PROJETO.
# Sem X11/XCB/Wayland (auditado): o ImGui desenha pelo renderer do SDL2 (sem OpenGL de PC) e as
# janelas de depuracao so abrem com F6-F12, que o aparelho nao tem.
# Entrada (spec 012): o jogo le pela API SDL_GameController, entao o i2c-keys precisa de um
# mapeamento por GUID (gamecontrollerdb, SDL_GAMECONTROLLERCONFIG_FILE) e o emulador roda SEM
# --nojoystick. O input_cfg.toml de teclado (spike 010, ports/gerar_gametank_cfg.py) nao servia: o
# aparelho nao manda teclas (KB §11i).
RECEITA_OPCOES="OS=Linux bin (SDL2 2.28.5 de fabrica)"
receita_compilar() {
    make -j"$NPROC" OS=Linux OUT_DIR=build-m17 CC="$CC" CPPC="$CXX" OPTIM_FLAGS=-O2 \
        COMPILER_FLAGS="$CXXFLAGS -I$EMU_INC/SDL2 -D_REENTRANT -Isrc/imgui -Isrc/imgui/backends -Isrc/imgui/ext/implot -Isrc/whereami" \
        LINKER_FLAGS="$LDFLAGS -lSDL2 -lpthread -ldl" bin
}
receita_instalar() {
    mkdir -p "$OUT/gametank"
    "$STRIP" -o "$OUT/gametank/GameTankEmulator" build-m17/GameTankEmulator
}
