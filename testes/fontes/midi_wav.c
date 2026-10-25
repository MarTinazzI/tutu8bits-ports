/* Spec 047 (T01): toca um MIDI pela SDL2_mixer do projeto (Timidity embutido) e grava N segundos do que sai, cru
 * (s16le, 44100 Hz, estereo), pelo Mix_SetPostMix. Uso: midi_wav CFG MIDI SAIDA.raw SEGUNDOS
 * CFG "-" = sem Mix_SetTimidityCfg: vale o TIMIDITY_CFG do ambiente (o caminho do FreeDink).
 * Imprime os decodificadores de musica ("decoder X") e "ok: <ms>" no fim. */
#include <SDL.h>
#include <SDL_mixer.h>
#include <stdio.h>
#include <stdlib.h>

static FILE *saida;
static long falta;   /* bytes que ainda faltam */

static void pos(void *u, Uint8 *b, int n)
{
    (void)u;
    if (falta <= 0)
        return;
    if (n > falta)
        n = (int)falta;
    fwrite(b, 1, (size_t)n, saida);
    falta -= n;
}

int main(int argc, char **argv)
{
    if (argc < 5) {
        fprintf(stderr, "uso: midi_wav CFG MIDI SAIDA.raw SEGUNDOS\n");
        return 2;
    }
    if (SDL_Init(SDL_INIT_AUDIO) < 0) {
        fprintf(stderr, "SDL_Init: %s\n", SDL_GetError());
        return 1;
    }
    if (SDL_strcmp(argv[1], "-") != 0 && Mix_SetTimidityCfg(argv[1]) == 0) {
        fprintf(stderr, "Mix_SetTimidityCfg: %s\n", Mix_GetError());
        return 1;
    }
    if (Mix_OpenAudio(44100, AUDIO_S16LSB, 2, 1024) < 0) {
        fprintf(stderr, "Mix_OpenAudio: %s\n", Mix_GetError());
        return 1;
    }
    Mix_Init(MIX_INIT_MID);
    for (int i = 0; i < Mix_GetNumMusicDecoders(); i++)
        printf("decoder %s\n", Mix_GetMusicDecoder(i));
    Mix_Music *m = Mix_LoadMUS(argv[2]);
    if (!m) {
        fprintf(stderr, "Mix_LoadMUS: %s\n", Mix_GetError());
        return 1;
    }
    saida = fopen(argv[3], "wb");
    if (!saida)
        return 1;
    falta = atol(argv[4]) * 44100L * 4;
    Mix_SetPostMix(pos, NULL);
    Uint32 t0 = SDL_GetTicks();
    Mix_PlayMusic(m, 0);
    while (falta > 0 && Mix_PlayingMusic())
        SDL_Delay(5);
    Mix_HaltMusic();
    printf("ok: %u ms\n", SDL_GetTicks() - t0);
    fclose(saida);
    Mix_FreeMusic(m);
    Mix_CloseAudio();
    SDL_Quit();
    return 0;
}
