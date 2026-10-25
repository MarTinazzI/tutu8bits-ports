// Programa de teste da roda (spec 048, T03; CA-02 do componente): um "jogo" de mentira em 320x240 logicos (o fundo
// com faixas coloridas) abre a roda do arquivo dado e imprime o resultado; com "injetar", poe a acao na fila do SDL
// pelo injetor e lista os eventos. Uso: prog_roda <arquivo.roda> <rapido 0|1> [injetar]
#include "roda_sdl.h"

#include <stdio.h>
#include <string.h>

static void fundo(void *ctx)
{
    SDL_Renderer *rd = (SDL_Renderer *)ctx;
    for (int i = 0; i < 8; i++)
    {
        SDL_Rect q = { i * 40, 0, 40, 240 };
        SDL_SetRenderDrawColor(rd, (Uint8)(i * 30), (Uint8)(200 - i * 20), (Uint8)(80 + i * 20), 255);
        SDL_RenderFillRect(rd, &q);
    }
}

int main(int argc, char **argv)
{
    if (argc < 3)
        return 2;
    if (SDL_Init(SDL_INIT_VIDEO | SDL_INIT_JOYSTICK) != 0)
        return 3;
    SDL_Window *w = SDL_CreateWindow("roda", 0, 0, 480, 272, 0);
    SDL_Renderer *rd = w ? SDL_CreateRenderer(w, -1, 0) : NULL;
    if (rd == NULL)
        return 4;
    SDL_RenderSetLogicalSize(rd, 320, 240);
    Roda r;
    char erro[256], acao[RODA_ACAO + 1] = "";
    if (roda_ler(argv[1], &r, erro, sizeof erro) != 0)
    {
        printf("erro=[%s]\n", erro);
        return 5;
    }
    int res = m17_roda(rd, &r, argv[2][0] == '1', fundo, rd, acao, sizeof acao);
    int lw = 0, lh = 0;
    SDL_RenderGetLogicalSize(rd, &lw, &lh);
    printf("resultado=%d acao=[%s] logico=%dx%d\n", res, acao, lw, lh);
    SDL_PumpEvents();
    printf("quit_na_fila=%d\n", SDL_PeepEvents(NULL, 0, SDL_PEEKEVENT, SDL_QUIT, SDL_QUIT) > 0);
    if (argc > 3 && strcmp(argv[3], "injetar") == 0 && res == 1)
    {
        printf("injetadas=%d\n", m17_roda_injetar(acao));
        SDL_Event ev;
        while (SDL_PollEvent(&ev))
        {
            if (ev.type == SDL_KEYDOWN)
                printf("KEYDOWN %s%s\n", (ev.key.keysym.mod & KMOD_CTRL) ? "Ctrl+" : "", SDL_GetKeyName(ev.key.keysym.sym));
            else if (ev.type == SDL_TEXTINPUT)
                printf("TEXT %s\n", ev.text.text);
            else if (ev.type == SDL_KEYUP)
                printf("KEYUP %s\n", SDL_GetKeyName(ev.key.keysym.sym));
        }
    }
    SDL_DestroyRenderer(rd);
    SDL_DestroyWindow(w);
    SDL_Quit();
    return 0;
}
