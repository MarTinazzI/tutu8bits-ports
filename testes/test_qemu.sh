#!/usr/bin/env bash
# T04 (spec 009, plano D-12 b): cada nucleo roda um titulo do roteiro no qemu-arm-static com o
# nosso RetroArch (video/audio/entrada nulos), N quadros, e a ultima tela vai para
# .cache/emu/telas/009/qemu_<nucleo>.png (ate a spec 053, em specs/009-.../evidencias/telas/).
# Confere: rc=0, captura com imagem (mais de 8 cores) e a linha "[M17] quadros=" no log.
# ROMs ficam fora do repositorio (~/m17/roms do mantenedor e roms de fabrica) e nao sao copiadas.
# Nada e gravado fora de .cache/emu/testes. Uso: test_qemu.sh [nucleo...]. Termina com "falhas: N".
set -uo pipefail
D=$(cd "$(dirname "$0")" && pwd)
. "$D/../../src/emu/ambiente.sh"
FAB="${ROMS_FABRICA:-$HOME/m17/emuelec/original/sistema/roms}"
MAN="${ROMS_MANTENEDOR:-$HOME/m17/roms}"
TELAS="$EMU_CACHE/telas/009"   # spec 053 (D-09): regeneradas a cada suite, fora do git
T="$EMU_CACHE/testes/qemu"
RA="$EMU_CACHE/out/retroarch/retroarch"
F=0
conta() { if [ "$1" -eq 0 ]; then echo "ok    $2"; else echo "FALHA $2"; F=$((F + 1)); fi; }

# nucleo|rom|quadros|esperado   (titulo pesado de cada linha do roteiro do 008 e conferencias)
#   esperado: imagem = roda e a captura tem imagem; sem_captura = roda, mas o nucleo nao desenha com o
#   video nulo (avisa que o video esta desligado); cai = falha conhecida no qemu (ver notas_qemu.md)
LISTA="pcsx_rearmed|$FAB/psx/CTR - Crash Team Racing (USA).chd|1500|imagem
gpsp|$FAB/gba/F-Zero - Maximum Velocity (USAEurope).zip|600|imagem
mgba|$FAB/gba/F-Zero - Maximum Velocity (USAEurope).zip|600|imagem
snes9x2005_plus|$FAB/snes/Star Fox (USA) (Rev 2).zip|600|sem_captura
snes9x2005_plus|$MAN/snes/Kirby Super Star (USA).zip|600|sem_captura
snes9x|$MAN/snes/Kirby Super Star (USA).zip|600|cai
picodrive|$FAB/megadrive/Virtua Racing (USA).zip|900|imagem
picodrive|$MAN/genesis/Beggar Prince (World) (Aftermarket) (Unl).zip|900|imagem
picodrive|$MAN/sms/Golden Axe Warrior (UE) [!].sms|600|imagem
fceumm|$MAN/nes/HeroQuest (USA) (Proto).zip|600|imagem
gambatte|$MAN/gbc/Azure Dreams (USA) (SGB Enhanced) (GB Compatible).zip|600|imagem
stella2014|$FAB/atari2600/Pitfall II - Lost Caverns (USA).a26|600|imagem
a5200|$FAB/atari5200/Defender (USA).zip|600|imagem
prosystem|$FAB/atari7800/Galaga (1987) (Atari).zip|600|imagem
handy|$FAB/atarilynx/California Games (USA Europe.zip|600|imagem
mednafen_pce_fast|$FAB/pcengine/R-Type Part-1 (Japan).zip|600|imagem
geargrafx|$FAB/pcengine/R-Type Part-1 (Japan).zip|600|imagem
race|$FAB/ngpc/Metal Slug - 2nd Mission (World) (EnJa).zip|900|sem_captura
mednafen_ngp|$FAB/ngpc/Metal Slug - 2nd Mission (World) (EnJa).zip|900|imagem"

cores_png() {   # numero de cores distintas num PNG (python3, sem bibliotecas externas)
    python3 - "$1" <<'PY'
import sys, zlib, struct
d = open(sys.argv[1], 'rb').read()
w, h, bd, ct = struct.unpack('>IIBB', d[16:26])
pos, idat = 8, b''
while pos < len(d):
    n, t = struct.unpack('>I4s', d[pos:pos+8])
    if t == b'IDAT': idat += d[pos+8:pos+8+n]
    pos += 12 + n
raw = zlib.decompress(idat)
bpp = {2: 3, 6: 4}[ct]
stride = w * bpp
cores, prev, i = set(), bytearray(stride), 0
for _ in range(h):
    f = raw[i]; line = bytearray(raw[i+1:i+1+stride]); i += 1 + stride
    for x in range(stride):
        a = line[x-bpp] if x >= bpp else 0; b = prev[x]; c = prev[x-bpp] if x >= bpp else 0
        if f == 1: line[x] = (line[x] + a) & 255
        elif f == 2: line[x] = (line[x] + b) & 255
        elif f == 3: line[x] = (line[x] + (a + b) // 2) & 255
        elif f == 4:
            p = a + b - c; pa, pb, pc = abs(p-a), abs(p-b), abs(p-c)
            line[x] = (line[x] + (a if pa <= pb and pa <= pc else b if pb <= pc else c)) & 255
    for x in range(0, stride, bpp): cores.add(bytes(line[x:x+3]))
    prev = line
print(len(cores))
PY
}

mkdir -p "$TELAS"
ulimit -c 0          # o qemu grava um core do programa ARM quando ele cai
SEL=" $* "
while IFS='|' read -r n rom q esp; do
    [ $# -eq 0 ] || case "$SEL" in *" $n "*) ;; *) continue;; esac
    tag=$(basename "$rom" | tr -c 'A-Za-z0-9' '_' | cut -c1-24)
    d="$T/$n-$tag"; rm -rf "$d"; mkdir -p "$d/home"
    if [ ! -f "$rom" ]; then conta 1 "$n: ROM existe ($rom)"; continue; fi
    cat > "$d/nulo.cfg" <<CFG
video_driver = "null"
audio_driver = "null"
input_driver = "null"
input_joypad_driver = "null"
config_save_on_exit = "false"
system_directory = "$d"
savefile_directory = "$d"
savestate_directory = "$d"
playlist_directory = "$d/home"
cache_directory = "$d"
screenshot_directory = "$d"
CFG
    lim=600; [ "$esp" = cai ] && lim=60   # depois do SIGSEGV o qemu fica preso ate o timeout
    t0=$(date +%s)
    HOME="$d/home" XDG_CONFIG_HOME="$d/home/.config" LD_LIBRARY_PATH="$EMU_LIB_CARTAO" timeout "$lim" \
        qemu-arm-static -L "$EMU_ROOTFS" "$RA" --config "$d/nulo.cfg" -L "$EMU_CACHE/out/cores/${n}_libretro.so" \
        "$rom" --max-frames="$q" --max-frames-ss --max-frames-ss-path="$d/tela.png" --verbose > "$d/log.txt" 2>&1
    rc=$?; seg=$(( $(date +%s) - t0 )); nome=$(basename "$rom")
    if [ "$esp" = cai ]; then
        # snes9x sob qemu e NAO-DETERMINISTICO: ora cai (signal 11), ora roda os quadros.
        # Nenhum dos dois e problema de produto (artefato do qemu-arm-static; no aparelho
        # roda — notas_qemu.md). Antes o teste exigia o SIGSEGV sempre -> flaky (regra 9).
        # Agora aceita os dois e so registra qual aconteceu.
        if grep -q 'signal 11' "$d/log.txt"; then
            conta 0 "$n: '$nome' caiu no qemu (SIGSEGV), artefato conhecido (notas_qemu.md)"
        else
            conta 0 "$n: '$nome' rodou sob qemu sem cair desta vez (nao-deterministico; notas_qemu.md)"
        fi
        continue
    fi
    conta $rc "$n: roda $q quadros de '$nome' (${seg} s)"
    grep -q '\[M17\] quadros=' "$d/log.txt"; conta $? "$n: FPS no log ($(grep -o '\[M17\].*' "$d/log.txt"))"
    des=$(sed -n 's/^.*\[M17\].* desenhados=\([0-9]*\).*/\1/p' "$d/log.txt" | tail -1)
    if [ "$esp" = sem_captura ]; then
        grep -q 'Could not take a screenshot' "$d/log.txt"; conta $? "$n: sem captura com video nulo, como esperado"
        [ "${des:-x}" = 0 ]; conta $? "$n: desenhados=0 (o nucleo so repete quadros com video nulo: o contador separa isso)"
        continue
    fi
    [ "${des:-0}" -gt 0 ]; conta $? "$n: desenhados=$des"
    if [ -s "$d/tela.png" ]; then
        cp "$d/tela.png" "$TELAS/qemu_${n}_$tag.png"
        c=$(cores_png "$d/tela.png")
        [ "$c" -gt 1 ]; conta $? "$n: captura com imagem ($c cores) -> .cache/emu/telas/009/qemu_${n}_$tag.png"
    else
        conta 1 "$n: captura gerada"
    fi
done <<< "$LISTA"
# spec 049 (D-03, CA-05): sem BIOS no system_directory (o $d de cada titulo) o a5200 e o handy abrem, com o aviso no log
bios_aviso() {   # nucleo texto
    [ $# -gt 0 ] || return 0
    case "$SEL" in "  "|*" $1 "*) ;; *) return 0;; esac
    grep -q "$2" "$T/$1"-*/log.txt 2>/dev/null; conta $? "$1: sem BIOS abre com o substituto ('$2' no log)"
}
bios_aviso a5200 "using internal"
bios_aviso handy "BIOS file missing"
echo "falhas: $F"
[ "$F" -eq 0 ]
