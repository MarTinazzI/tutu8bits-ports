/* m17nh_video.c — a tela do NetHack no M17 (spec 036, plano D-03): 80x24 celulas {caractere, cor, inverso} desenhadas
 * com a fonte misc-fixed 6x10 da spec 035 (m17_fonte.h) numa celula 6x11 (80 x 6 = 480, 24 x 11 = 264; 4 px de margem)
 * num buffer RGB565 480x272, enviado ao renderer do SDL2 so quando algo muda. 16 cores (paleta CGA; NetHack CLR_*).
 * M17_TELA=<arq.bmp> e M17_TELA_TXT=<arq> gravam a ultima tela (testes e evidencias). */
#include "m17nh.h"
#include "m17_fonte.h"

#include <stdio.h>
#include <stdlib.h>
#include <string.h>

#define LARG 480
#define ALT 272
#define CEL_L 6
#define CEL_A 11
#define MARGEM ((ALT - M17NH_LINHAS * CEL_A) / 2)

/* CLR_BLACK..CLR_WHITE do NetHack (color.h); o preto (0) desenha em azul-escuro para aparecer no fundo preto, como o tty
 * faz com use_darkgray; NO_COLOR (8) = cinza claro */
static const Uint16 PALETA[16] = {
    0x2945, 0xA800, 0x0540, 0xA2A0, 0x0015, 0xA815, 0x0555, 0xAD55,
    0xAD55, 0xFAAA, 0x57EA, 0xFFEA, 0x52BF, 0xFABF, 0x57FF, 0xFFFF,
};

typedef struct { unsigned char c, cor, inv; } Celula;

static SDL_Window *janela;
static SDL_Renderer *render;
static SDL_Texture *textura;
static Uint16 pix[LARG * ALT];
static Celula tela[M17NH_LINHAS][M17NH_COLUNAS], sombra[M17NH_LINHAS][M17NH_COLUNAS];
static int iniciado, sem_video, sujo = 1, cur_y = -1, cur_x = -1, cur_y_des = -1, cur_x_des = -1;

void m17v_iniciar(void)
{
    if (iniciado)
        return;
    iniciado = 1;
    memset(tela, ' ', sizeof(tela));
    for (int y = 0; y < M17NH_LINHAS; y++)
        for (int x = 0; x < M17NH_COLUNAS; x++)
            tela[y][x].cor = 8, tela[y][x].inv = 0;
    memset(sombra, 0, sizeof(sombra));
    /* o SIGTERM e do jogo (hangup -> save; plano D-15), nao do SDL */
    SDL_SetHint(SDL_HINT_NO_SIGNAL_HANDLERS, "1");
    if (SDL_Init(SDL_INIT_VIDEO | SDL_INIT_JOYSTICK) != 0)
    {
        fprintf(stderr, "[M17] SDL_Init: %s\n", SDL_GetError());
        sem_video = 1;
        return;
    }
    janela = SDL_CreateWindow("NetHack", SDL_WINDOWPOS_CENTERED, SDL_WINDOWPOS_CENTERED, LARG, ALT,
                              getenv("M17_JANELA") ? 0 : SDL_WINDOW_FULLSCREEN);
    if (janela != NULL)
        render = SDL_CreateRenderer(janela, -1, 0);
    if (render != NULL)
        textura = SDL_CreateTexture(render, SDL_PIXELFORMAT_RGB565, SDL_TEXTUREACCESS_STREAMING, LARG, ALT);
    if (textura == NULL)
    {
        fprintf(stderr, "[M17] video: %s\n", SDL_GetError());
        sem_video = 1;
        return;
    }
    SDL_RendererInfo ri;
    if (SDL_GetRendererInfo(render, &ri) == 0)
        fprintf(stderr, "[M17] video: renderer %s\n", ri.name);
    SDL_RenderSetLogicalSize(render, LARG, ALT);
    SDL_ShowCursor(SDL_DISABLE);
}

SDL_Renderer *m17v_renderer(void) { return render; }

void m17v_celula(int y, int x, unsigned char c, int cor, int inverso)
{
    if (y < 0 || y >= M17NH_LINHAS || x < 0 || x >= M17NH_COLUNAS)
        return;
    if (c < 32 || c > 126)
        c = (c == 0) ? ' ' : '?';
    tela[y][x].c = c;
    tela[y][x].cor = (unsigned char)(cor & 15);
    tela[y][x].inv = (unsigned char)(inverso != 0);
}

void m17v_limpar(void)
{
    for (int y = 0; y < M17NH_LINHAS; y++)
        for (int x = 0; x < M17NH_COLUNAS; x++)
            m17v_celula(y, x, ' ', 8, 0);
}

void m17v_cursor(int y, int x) { cur_y = y, cur_x = x; }

unsigned char m17v_char(int y, int x)
{
    if (y < 0 || y >= M17NH_LINHAS || x < 0 || x >= M17NH_COLUNAS)
        return ' ';
    return tela[y][x].c;
}

static void desenhar_celula(int y, int x, int com_cursor)
{
    const Celula *k = &tela[y][x];
    Uint16 f = PALETA[k->cor], b = 0x0000;
    if (k->inv || com_cursor)
    {
        Uint16 t = f;
        f = b, b = k->inv && com_cursor ? 0x8410 : t;
    }
    const unsigned char *g = m17_fonte[k->c - 32];
    int py = MARGEM + y * CEL_A, px = x * CEL_L;
    for (int r = 0; r < CEL_A; r++)
    {
        unsigned char bits = r < M17_FONTE_ALTURA ? g[r] : 0;
        Uint16 *d = pix + (py + r) * LARG + px;
        for (int i = 0; i < CEL_L; i++)
            d[i] = (bits & (0x80 >> i)) ? f : b;
    }
}

static void gravar(void)
{
    if (m17nh_parar())
        return;   /* depois do pedido de saida a tela so se desfaz: a captura fica com a ultima tela do jogo */
    const char *arq = getenv("M17_TELA");
    if (arq != NULL && *arq)
    {
        SDL_Surface *s = SDL_CreateRGBSurfaceWithFormatFrom(pix, LARG, ALT, 16, LARG * 2, SDL_PIXELFORMAT_RGB565);
        if (s != NULL)
        {
            SDL_SaveBMP(s, arq);
            SDL_FreeSurface(s);
        }
    }
    arq = getenv("M17_TELA_TXT");
    if (arq != NULL && *arq)
    {
        FILE *f = fopen(arq, "w");
        if (f != NULL)
        {
            for (int y = 0; y < M17NH_LINHAS; y++)
            {
                for (int x = 0; x < M17NH_COLUNAS; x++)
                    fputc(tela[y][x].c, f);
                fputc('\n', f);
            }
            fclose(f);
        }
    }
}

void m17v_mostrar(void)
{
    m17v_iniciar();
    int algo = 0;
    for (int y = 0; y < M17NH_LINHAS; y++)
        for (int x = 0; x < M17NH_COLUNAS; x++)
        {
            int c_agora = (y == cur_y && x == cur_x), c_antes = (y == cur_y_des && x == cur_x_des);
            if (!sujo && !c_agora && !c_antes && memcmp(&sombra[y][x], &tela[y][x], sizeof(Celula)) == 0)
                continue;
            sombra[y][x] = tela[y][x];
            desenhar_celula(y, x, c_agora);
            algo = 1;
        }
    cur_y_des = cur_y, cur_x_des = cur_x;
    sujo = 0;
    if (!algo)
        return;
    if (!sem_video)
    {
        SDL_UpdateTexture(textura, NULL, pix, LARG * 2);
        SDL_RenderClear(render);
        SDL_RenderCopy(render, textura, NULL, NULL);
        SDL_RenderPresent(render);
    }
    gravar();
}

/* o fundo da roda de opcoes (spec 048): a tela atual no renderer, sem apresentar */
void m17v_fundo(void *ctx)
{
    (void)ctx;
    m17v_iniciar();
    if (sem_video)
        return;
    SDL_UpdateTexture(textura, NULL, pix, LARG * 2);
    SDL_RenderCopy(render, textura, NULL, NULL);
}

/* depois do teclado virtual (que desenha por cima no mesmo renderer), tudo de novo */
void m17v_redesenhar(void)
{
    sujo = 1;
    m17v_mostrar();
}
