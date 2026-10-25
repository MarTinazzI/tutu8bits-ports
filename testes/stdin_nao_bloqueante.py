"""Abre um FIFO como stdin NAO bloqueante e executa o resto da linha (spec 025, T01).

O RetroArch sem HAVE_NETWORKING nao liga o O_NONBLOCK no stdin (command.c) e o read_stdin
(libretro-common/streams/stdin_stream.c) le ate encher o buffer: com um FIFO comum o laco
principal trava. Aberto aqui com O_NONBLOCK, o read volta na hora quando nao ha comando.
Uso: python3 -I stdin_nao_bloqueante.py <fifo> <comando> [args...]
"""
import os
import sys

fd = os.open(sys.argv[1], os.O_RDONLY | os.O_NONBLOCK)
os.dup2(fd, 0)
os.close(fd)
os.execvp(sys.argv[2], sys.argv[2:])
