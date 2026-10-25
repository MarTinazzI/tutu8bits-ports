/* m17nh_entrada.c — a entrada do NetHack no M17 (spec 036, plano D-12).
 * Parte pura (m17nh_traduzir): codigo do controle -> tecla do NetHack, conforme o contexto. Testada no PC.
 * Parte SDL (m17nh_ler): roteiro de teste (M17_ROTEIRO), teclado do SDL e o joystick cru do aparelho pela maquina de
 * estados da spec 035 (m17e_passo: acorde, 8 setores, giro do R1, repeticao, B segurado corre). */
#include "m17nh.h"

#include <stdio.h>
#include <stdlib.h>
#include <string.h>

/* tecla de direcao do NetHack (number_pad 0) a partir do codigo do m17e_passo ('h'..'n', maiuscula = correr) */
static int direcao(int codigo)
{
    /* so letras: um codigo M17E_* (>= 0x100) viraria o '\0' do fim da string no strchr */
    return (codigo > 0 && codigo < 128 && strchr("hjklyubnHJKLYUBN", codigo) != NULL) ? codigo : 0;
}

int m17nh_traduzir(int codigo, int contexto, int na_escada)
{
    int d = direcao(codigo);
    switch (contexto)
    {
    case M17NH_MAPA:
        if (d)
            return d;
        switch (codigo)
        {
        case M17E_A: return na_escada ? na_escada : ',';
        case M17E_B: return 27;
        case M17E_X: return 'i';
        case M17E_Y: return 's';
        case M17E_L1: return '.';
        case M17E_L2: return 'P' & 0x1f;   /* Ctrl+P: mensagens anteriores */
        case M17E_R2: return 'A' & 0x1f;   /* Ctrl+A: repetir (DOAGAIN) */
        case M17E_SELECT: return -1;
        case M17E_START: return -2;
        case M17NH_R3: return -4;   /* spec 048: a roda so no mapa */
        }
        return 0;
    case M17NH_POSICAO:   /* getpos: plano D-09 (B segurado + direcao = passo de 8: a maiuscula do m17e_passo) */
        if (d)
            return d;
        switch (codigo)
        {
        case M17E_A: return '.';
        case M17E_B: return 27;
        case M17E_L1: return '<';
        case M17E_L2: return '>';
        case M17E_X: return 'm';
        case M17E_Y: return 'M';
        case M17E_R2: return '@';
        case M17E_START: return ',';   /* escolher (como o '.'; no getpos ',' tambem escolhe) */
        }
        return 0;
    case M17NH_PERGUNTA:   /* "In what direction?" e afins: direcoes, A = em si, L1/L2 = < > */
        if (d)
            return d >= 'A' && d <= 'Z' ? d - 'A' + 'a' : d;
        switch (codigo)
        {
        case M17E_A: return '.';
        case M17E_B: return 27;
        case M17E_L1: return '<';
        case M17E_L2: return '>';
        }
        return 0;
    case M17NH_MAIS:
        return (codigo == M17E_A || codigo == M17E_START) ? '\n' : codigo == M17E_B ? 27 : 0;
    }
    return 0;
}

#ifndef M17NH_TESTE
/* ------------------------------------------------------------------ parte SDL */
#define BIT(i) (1u << (i))

static SDL_Joystick *joy;
static M17E_Config cfg;
static M17E_Estado est;
static char *roteiro;
static size_t roteiro_i;
static int roteiro_lido, iniciado;

void m17nh_iniciar_entrada(void)
{
    if (iniciado)
        return;
    iniciado = 1;
    char av[1024];
    int n = m17e_config_ler(getenv("M17_NETHACK_CFG"), &cfg, av, sizeof(av));
    /* os avisos do leitor comum (spec 035) falam do rogue.cfg: aqui o arquivo e o nethack.cfg */
    if (n > 0)
        for (char *l = strtok(av, "\n"); l != NULL; l = strtok(NULL, "\n"))
        {
            const char *r = strstr(l, "rogue.cfg");
            if (r != NULL)
                fprintf(stderr, "[M17] %.*snethack.cfg%s\n", (int)(r - l), l, r + strlen("rogue.cfg"));
            else
                fprintf(stderr, "[M17] %s\n", l);
        }
    fprintf(stderr, "[M17] entrada: acorde %d ms, atraso %d ms, repeticao %d ms, zona morta %d\n", cfg.acorde_ms,
            cfg.atraso_ms, cfg.repeticao_ms, cfg.zona_morta);
    if (SDL_NumJoysticks() > 0 && (joy = SDL_JoystickOpen(0)) != NULL)
        fprintf(stderr, "[M17] joystick: %s (%d botoes, %d eixos)\n", SDL_JoystickName(joy),
                SDL_JoystickNumButtons(joy), SDL_JoystickNumAxes(joy));
    else
        fprintf(stderr, "[M17] joystick: nenhum (so teclado)\n");
}

/* roteiro de teste: texto (tecla a tecla); \e = Esc, \n = Enter, \\ = barra, \^X = Ctrl+X; {A} {B} {X} {Y} {L1} {L2}
 * {R2} {SELECT} {START} {R3} {cima} {baixo} {esq} {dir} {CIMA} {BAIXO} {ESQ} {DIR} (B segurado) = botoes do controle
 * (passam pela traducao, como o controle). Quebras de linha do arquivo nao contam. */
static int roteiro_proximo(int *codigo)
{
    *codigo = 0;
    if (!roteiro_lido)
    {
        roteiro_lido = 1;
        const char *arq = getenv("M17_ROTEIRO");
        FILE *f = (arq && *arq) ? fopen(arq, "r") : NULL;
        if (f != NULL)
        {
            fseek(f, 0, SEEK_END);
            long t = ftell(f);
            fseek(f, 0, SEEK_SET);
            roteiro = calloc((size_t)t + 1, 1);
            if (fread(roteiro, 1, (size_t)t, f) != (size_t)t)
                roteiro[0] = '\0';
            fclose(f);
        }
    }
    if (roteiro == NULL)
        return -1;
    for (;;)
    {
        char c = roteiro[roteiro_i];
        if (c == '\0')
        {
            free(roteiro);
            roteiro = NULL;
            fprintf(stderr, "[M17] roteiro: fim\n");
            return -1;
        }
        roteiro_i++;
        if (c == '\r' || c == '\n')
            continue;
        if (c == '\\')
        {
            char d = roteiro[roteiro_i++];
            if (d == '^')
                return roteiro[roteiro_i++] & 0x1f;
            return d == 'e' ? 27 : d == 'n' ? '\n' : (unsigned char)d;
        }
        if (c == '{')
        {
            static const struct { const char *nome; int codigo; } T[] = {
                { "A", M17E_A }, { "B", M17E_B }, { "X", M17E_X }, { "Y", M17E_Y }, { "L1", M17E_L1 },
                { "L2", M17E_L2 }, { "R2", M17E_R2 }, { "SELECT", M17E_SELECT }, { "START", M17E_START },
                { "R3", M17NH_R3 },
                { "cima", 'k' }, { "baixo", 'j' }, { "esq", 'h' }, { "dir", 'l' },
                { "CIMA", 'K' }, { "BAIXO", 'J' }, { "ESQ", 'H' }, { "DIR", 'L' },
            };
            char *f = strchr(roteiro + roteiro_i, '}');
            if (f != NULL)
            {
                size_t t = (size_t)(f - (roteiro + roteiro_i));
                for (size_t i = 0; i < sizeof(T) / sizeof(T[0]); i++)
                    if (strlen(T[i].nome) == t && strncmp(T[i].nome, roteiro + roteiro_i, t) == 0)
                    {
                        roteiro_i += t + 1;
                        *codigo = T[i].codigo;
                        return 0;
                    }
            }
        }
        return (unsigned char)c;
    }
}

/* teclado do SDL (PC): a tecla como o tty a daria */
static int teclado(const SDL_Event *ev)
{
    if (ev->type == SDL_TEXTINPUT)
    {
        unsigned char c = (unsigned char)ev->text.text[0];
        return (c >= 32 && c < 127) ? c : 0;
    }
    if (ev->type != SDL_KEYDOWN)
        return 0;
    SDL_Keycode k = ev->key.keysym.sym;
    if (k == SDLK_RETURN || k == SDLK_KP_ENTER)
        return '\n';
    if (k == SDLK_ESCAPE)
        return 27;
    if (k == SDLK_BACKSPACE)
        return '\b';
    if (k == SDLK_UP || k == SDLK_DOWN || k == SDLK_LEFT || k == SDLK_RIGHT)
        return k == SDLK_UP ? 'k' : k == SDLK_DOWN ? 'j' : k == SDLK_LEFT ? 'h' : 'l';
    if ((ev->key.keysym.mod & KMOD_CTRL) && k >= SDLK_a && k <= SDLK_z)
        return (int)(k - SDLK_a + 1);
    return 0;
}

/* o proximo evento: devolve uma tecla (> 0), ou 0 com *codigo = um codigo do controle (direcao/M17E_*), ou -3 = o
 * SDL pediu para sair (SIGTERM do m17atalhos com o SDL tratando sinais, ou janela fechada no PC) */
int m17nh_ler(int *codigo)
{
    *codigo = 0;
    m17nh_iniciar_entrada();
    int c = roteiro_proximo(codigo);
    if (c >= 0)
        return c;
    for (;;)
    {
        SDL_Event ev;
        int tem = m17e_ocupado(&est) ? SDL_WaitEventTimeout(&ev, 10) : SDL_WaitEventTimeout(&ev, 200);
        while (tem)
        {
            if (ev.type == SDL_QUIT)
                return -3;
            if (ev.type == SDL_JOYDEVICEADDED && joy == NULL)
                joy = SDL_JoystickOpen(ev.jdevice.which);
            int k = teclado(&ev);
            if (k > 0)
                return k;
            tem = SDL_PollEvent(&ev);
        }
        if (m17nh_parar())
            return -3;
        if (joy == NULL)
            continue;
        M17E_Entrada in;
        in.botoes = 0;
        for (int i = 0; i < SDL_JoystickNumButtons(joy) && i < 32; i++)
            if (SDL_JoystickGetButton(joy, i))
                in.botoes |= BIT(i);
        in.ax = SDL_JoystickNumAxes(joy) > 0 ? SDL_JoystickGetAxis(joy, 0) : 0;
        in.ay = SDL_JoystickNumAxes(joy) > 1 ? SDL_JoystickGetAxis(joy, 1) : 0;
        in.ms = SDL_GetTicks();
        /* spec 048: o R3 (indice M17_R3, padrao 2; KB 11k: H) abre a roda; os botoes que nada aqui conhece vao ao
         * log, para a sessao no aparelho achar o indice certo do R3 (plano D-08) */
        static unsigned antes;
        static int r3 = -1;
        if (r3 < 0)
        {
            const char *e = getenv("M17_R3");
            r3 = (e != NULL && *e) ? atoi(e) : 2;
        }
        unsigned novos = in.botoes & ~antes;
        antes = in.botoes;
        const unsigned conhecidos = 0x1fff8u;   /* 3..16 (KB 11k) */
        for (int i = 0; i < 32; i++)
            if ((novos & BIT(i)) && i != r3 && !(conhecidos & BIT(i)))
                fprintf(stderr, "[M17] botao %d\n", i);
        if (r3 >= 0 && r3 < 32 && (novos & BIT(r3)))
        {
            *codigo = M17NH_R3;
            return 0;
        }
        int cod = m17e_passo(&est, &cfg, &in);
        if (cod != 0)
        {
            *codigo = cod;
            return 0;
        }
    }
}
#endif
