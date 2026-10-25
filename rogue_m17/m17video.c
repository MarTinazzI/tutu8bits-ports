/* m17video.c — a tela do Rogue no M17 (spec 035, plano D-03): o terminal 80x24 da curses propria desenhado com a
 * fonte misc-fixed 6x10 numa celula de 6x11 (80 x 6 = 480, 24 x 11 = 264; 4 px de margem em cima e embaixo) num
 * buffer RGB565 480x272, enviado ao renderer do SDL2 so quando algo muda. Video inverso = cores trocadas.
 * M17_TELA=<arq.bmp>: grava a ultima tela desenhada (testes e evidencias). Os menus da camada (m17menus.c) sao
 * desenhados por cima, sem mexer na tela do jogo. */
#include "curses.h"
#include "m17.h"
#include "m17_fonte.h"

#include "SDL.h"

#include <stdio.h>
#include <stdlib.h>
#include <string.h>

#define LARG 480
#define ALT 272
#define CEL_L 6
#define CEL_A 11
#define MARGEM ((ALT - 24 * CEL_A) / 2)

static SDL_Window *janela;
static SDL_Renderer *render;
static SDL_Texture *textura;
static Uint16 pix[LARG * ALT];
static chtype sombra[24][80];   /* o que esta desenhado no pix */
static bool iniciado, sem_video;

static const Uint16 FRENTE = 0xC618;   /* cinza claro (198,195,198) */
static const Uint16 FUNDO = 0x0000;

void m17v_iniciar(void)
{
    if (iniciado)
        return;
    iniciado = true;
    /* o SIGTERM da saida (VOL+ segurado) e do Rogue (auto_save, patch rogue-m17-01), nao do SDL */
    SDL_SetHint(SDL_HINT_NO_SIGNAL_HANDLERS, "1");
    if (SDL_Init(SDL_INIT_VIDEO | SDL_INIT_JOYSTICK) != 0)
    {
        fprintf(stderr, "[M17] SDL_Init: %s\n", SDL_GetError());
        sem_video = true;
        return;
    }
    janela = SDL_CreateWindow("Rogue", SDL_WINDOWPOS_CENTERED, SDL_WINDOWPOS_CENTERED, LARG, ALT,
                              getenv("M17_JANELA") ? 0 : SDL_WINDOW_FULLSCREEN);
    if (janela != NULL)
        render = SDL_CreateRenderer(janela, -1, 0);
    if (render != NULL)
        textura = SDL_CreateTexture(render, SDL_PIXELFORMAT_RGB565, SDL_TEXTUREACCESS_STREAMING, LARG, ALT);
    if (textura == NULL)
    {
        fprintf(stderr, "[M17] video: %s\n", SDL_GetError());
        sem_video = true;
        return;
    }
    SDL_RendererInfo ri;
    if (SDL_GetRendererInfo(render, &ri) == 0)
        fprintf(stderr, "[M17] video: renderer %s\n", ri.name);
    SDL_RenderSetLogicalSize(render, LARG, ALT);
    SDL_ShowCursor(SDL_DISABLE);
    m17e_iniciar_joystick();
}

void m17v_celula(Uint16 *p, int y, int x, unsigned char c, bool inverso, Uint16 frente, Uint16 fundo)
{
    Uint16 f = inverso ? fundo : frente, b = inverso ? frente : fundo;
    const unsigned char *g = (c >= 32 && c <= 126) ? m17_fonte[c - 32] : m17_fonte['?' - 32];
    int py = MARGEM + y * CEL_A, px = x * CEL_L;
    for (int r = 0; r < CEL_A; r++)
    {
        unsigned char bits = r < M17_FONTE_ALTURA ? g[r] : 0;
        Uint16 *d = p + (py + r) * LARG + px;
        for (int k = 0; k < CEL_L; k++)
            d[k] = (bits & (0x80 >> k)) ? f : b;
    }
}

static void gravar_bmp(const Uint16 *buf)
{
    const char *arq = getenv("M17_TELA");
    if (arq == NULL || *arq == '\0')
        return;
    SDL_Surface *s = SDL_CreateRGBSurfaceWithFormatFrom((void *)buf, LARG, ALT, 16, LARG * 2, SDL_PIXELFORMAT_RGB565);
    if (s != NULL)
    {
        SDL_SaveBMP(s, arq);
        SDL_FreeSurface(s);
    }
}

/* o texto da tela como esta (testes: M17_TELA_TXT=<arq>) */
static void gravar_txt(const WINDOW *tela)
{
    const char *arq = getenv("M17_TELA_TXT");
    if (arq == NULL || *arq == '\0')
        return;
    FILE *f = fopen(arq, "w");
    if (f == NULL)
        return;
    for (int y = 0; y < tela->linhas; y++)
    {
        for (int x = 0; x < tela->colunas; x++)
            fputc((int)(tela->l[y][x] & A_CHARTEXT), f);
        fputc('\n', f);
    }
    fclose(f);
}

void m17v_apresentar(void)
{
    static Uint16 com_menu[LARG * ALT];
    const Uint16 *origem = pix;
    if (m17m_ativo())
    {
        memcpy(com_menu, pix, sizeof(pix));
        m17m_desenhar(com_menu);
        origem = com_menu;
    }
    if (!sem_video)
    {
        SDL_UpdateTexture(textura, NULL, origem, LARG * 2);
        SDL_RenderClear(render);
        SDL_RenderCopy(render, textura, NULL, NULL);
        SDL_RenderPresent(render);
    }
    gravar_bmp(origem);   /* com menu aberto, a captura mostra o menu */
}

void m17v_mostrar(const WINDOW *tela)
{
    m17v_iniciar();
    bool tudo = tela->limpar, algo = tudo;
    for (int y = 0; y < 24 && y < tela->linhas; y++)
        for (int x = 0; x < 80 && x < tela->colunas; x++)
        {
            chtype c = tela->l[y][x];
            if (!tudo && sombra[y][x] == c)
                continue;
            sombra[y][x] = c;
            m17v_celula(pix, y, x, (unsigned char)(c & A_CHARTEXT), (c & A_STANDOUT) != 0, FRENTE, FUNDO);
            algo = true;
        }
    ((WINDOW *)tela)->limpar = false;
    if (algo || m17m_ativo())
    {
        gravar_txt(tela);
        m17v_apresentar();
    }
}
