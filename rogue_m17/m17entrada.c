/* m17entrada.c — a entrada do Rogue no M17 (spec 035, plano D-04/D-05/D-13).
 * Parte pura (m17e_*): botoes, eixos e tempo -> letras/codigos; traducao por contexto; leitura do rogue.cfg. Testada
 * no PC com -DM17E_TESTE (ports/testes/fontes/arnes_m17entrada.c).
 * Parte SDL (m17_tecla): roteiro de teste (M17_ROTEIRO), teclado do SDL e o joystick cru do aparelho; os menus por
 * cima recebem os botoes quando estao abertos. */
#include "m17entrada.h"

#include <ctype.h>
#include <math.h>
#include <stddef.h>
#include <stdio.h>
#include <stdlib.h>
#include <string.h>

#ifndef M_PI
#define M_PI 3.14159265358979323846
#endif

#define BIT(i) (1u << (i))

void m17e_config_padrao(M17E_Config *c)
{
    c->acorde_ms = 60;
    c->atraso_ms = 250;
    c->repeticao_ms = 110;
    c->zona_morta = 12000;
}

static void aviso(char *avisos, int tam, int *n, const char *fmt, const char *a, int b)
{
    size_t u = strlen(avisos);
    if ((int)u < tam - 1)
        snprintf(avisos + u, (size_t)tam - u, fmt, a, b);
    (*n)++;
}

int m17e_config_ler(const char *arq, M17E_Config *c, char *avisos, int tam)
{
    static const struct { const char *chave; int min, max; size_t desloc; } chaves[] = {
        { "acorde_ms", 0, 500, offsetof(M17E_Config, acorde_ms) },
        { "atraso_ms", 50, 2000, offsetof(M17E_Config, atraso_ms) },
        { "repeticao_ms", 30, 1000, offsetof(M17E_Config, repeticao_ms) },
        { "zona_morta", 1000, 30000, offsetof(M17E_Config, zona_morta) },
    };
    int n = 0;
    m17e_config_padrao(c);
    avisos[0] = '\0';
    FILE *f = (arq != NULL && *arq != '\0') ? fopen(arq, "r") : NULL;
    if (f == NULL)
    {
        aviso(avisos, tam, &n, "rogue.cfg ausente (%s), usando o padrao%.0d\n", arq ? arq : "-", 0);
        return n;
    }
    char linha[256];
    while (fgets(linha, sizeof(linha), f) != NULL)
    {
        char *p = linha;
        while (isspace((unsigned char)*p))
            p++;
        if (*p == '#' || *p == '\0')
            continue;
        char *ig = strchr(p, '=');
        if (ig == NULL)
        {
            p[strcspn(p, "\r\n")] = '\0';
            aviso(avisos, tam, &n, "rogue.cfg: linha sem '=' ignorada: %s%.0d\n", p, 0);
            continue;
        }
        *ig = '\0';
        char *k = p, *v = ig + 1;
        k[strcspn(k, " \t")] = '\0';
        v[strcspn(v, "\r\n")] = '\0';
        size_t i;
        for (i = 0; i < sizeof(chaves) / sizeof(chaves[0]); i++)
            if (strcmp(k, chaves[i].chave) == 0)
                break;
        if (i == sizeof(chaves) / sizeof(chaves[0]))
        {
            aviso(avisos, tam, &n, "rogue.cfg: chave desconhecida ignorada: %s%.0d\n", k, 0);
            continue;
        }
        char *fim;
        long x = strtol(v, &fim, 10);
        while (isspace((unsigned char)*fim))
            fim++;
        int *dest = (int *)((char *)c + chaves[i].desloc);
        if (fim == v || *fim != '\0' || x < chaves[i].min || x > chaves[i].max)
            aviso(avisos, tam, &n, "rogue.cfg: %s invalida, usando o padrao %d\n", k, *dest);
        else
            *dest = (int)x;
    }
    fclose(f);
    return n;
}

static const char MAPA[3][3] = { { 'y', 'k', 'u' }, { 'h', 0, 'l' }, { 'b', 'j', 'n' } };

static int direcao(const M17E_Config *c, const M17E_Entrada *in, int *dx, int *dy)
{
    unsigned b = in->botoes;
    *dx = !!(b & BIT(M17B_DIREITA)) - !!(b & BIT(M17B_ESQUERDA));
    *dy = !!(b & BIT(M17B_BAIXO)) - !!(b & BIT(M17B_CIMA));
    if (*dx == 0 && *dy == 0)
    {
        /* D-pad solto: o analogico, em 8 setores de 45 graus, fora da zona morta */
        long ax = in->ax, ay = in->ay;
        if (ax * ax + ay * ay < (long)c->zona_morta * c->zona_morta)
            return 0;
        int s = (int)lround(atan2((double)ay, (double)ax) / (M_PI / 4)) & 7;
        static const int sx[8] = { 1, 1, 0, -1, -1, -1, 0, 1 }, sy[8] = { 0, 1, 1, 1, 0, -1, -1, -1 };
        *dx = sx[s];
        *dy = sy[s];
    }
    if (b & BIT(M17B_R1))
    {
        /* R1 segurado: gira 45 graus no sentido horario (cima -> cima-direita, direita -> baixo-direita...) */
        int rx = *dx - *dy, ry = *dx + *dy;
        *dx = rx > 0 ? 1 : rx < 0 ? -1 : 0;
        *dy = ry > 0 ? 1 : ry < 0 ? -1 : 0;
    }
    return *dx != 0 || *dy != 0;
}

int m17e_passo(M17E_Estado *e, const M17E_Config *c, const M17E_Entrada *in)
{
    unsigned b = in->botoes, novo = b & ~e->antes, solto = e->antes & ~b;
    int botao = 0;
    static const struct { int bit, codigo; } BOTOES[] = {
        { M17B_A, M17E_A }, { M17B_X, M17E_X }, { M17B_Y, M17E_Y }, { M17B_L1, M17E_L1 }, { M17B_L2, M17E_L2 },
        { M17B_R2, M17E_R2 }, { M17B_SELECT, M17E_SELECT }, { M17B_START, M17E_START },
    };
    for (size_t i = 0; i < sizeof(BOTOES) / sizeof(BOTOES[0]) && !botao; i++)
        if (novo & BIT(BOTOES[i].bit))
            botao = BOTOES[i].codigo;
    if (novo & BIT(M17B_B))
        e->b_com_direcao = 0;

    int saida = 0, dx, dy;
    if (direcao(c, in, &dx, &dy))
    {
        if (!e->segurando)
        {
            e->segurando = 1;
            e->t0 = in->ms;
            e->emitiu = 0;
        }
        int correr = (b & BIT(M17B_B)) != 0;
        if (correr)
            e->b_com_direcao = 1;
        int letra = MAPA[dy + 1][dx + 1];
        if (correr)
            letra = toupper(letra);
        if (!e->emitiu && ((int)(in->ms - e->t0) >= c->acorde_ms || (dx != 0 && dy != 0)))
        {
            e->emitiu = 1;
            e->prox = in->ms + (unsigned)c->atraso_ms;
            saida = letra;
        }
        else if (e->emitiu && (int)(in->ms - e->prox) >= 0)
        {
            e->prox = in->ms + (unsigned)c->repeticao_ms;   /* trocar de direcao troca a letra, sem reiniciar o atraso */
            saida = letra;
        }
    }
    else
    {
        e->segurando = 0;
        e->emitiu = 0;
    }
    /* B solto sem ter corrido = voltar (Esc) */
    if (!botao && (solto & BIT(M17B_B)) && !e->b_com_direcao)
        botao = M17E_B;
    e->antes = b;

    if (saida && botao)
    {
        e->pendente = botao;
        return saida;
    }
    if (!saida && !botao && e->pendente)
    {
        botao = e->pendente;
        e->pendente = 0;
    }
    return saida ? saida : botao;
}

int m17e_ocupado(const M17E_Estado *e)
{
    return e->segurando || (e->antes & BIT(M17B_B)) || e->pendente;
}

static int eh_direcao(int codigo)
{
    return codigo > 0 && codigo < 0x100 && strchr("ykuhlbjnYKUHLBJN", codigo) != NULL;
}

int m17e_traduzir(int codigo, int contexto, int extra)
{
    switch (contexto)
    {
    case M17_NADA:
        if (eh_direcao(codigo))
            return codigo;
        switch (codigo)
        {
        case M17E_A: return extra ? '>' : ',';   /* na escada desce; senao pega */
        case M17E_B: return 27;
        case M17E_X: return 'i';
        case M17E_Y: return 's';
        case M17E_L1: return '.';
        case M17E_L2: return 'P' & 0x1f;          /* Ctrl+P: repetir a mensagem */
        case M17E_R2: return 'a';
        case M17E_SELECT: return -1;
        case M17E_START: return -2;
        }
        return 0;
    case M17_DIRECAO:
        if (eh_direcao(codigo))
            return tolower(codigo);
        return codigo == M17E_B ? 27 : 0;
    case M17_SIMNAO:
        return codigo == M17E_A ? 'y' : codigo == M17E_B ? 'n' : 0;
    case M17_TEXTO:
        return codigo == M17E_A ? '\n' : codigo == M17E_B ? 27 : 0;
    case M17_MAIS:
        return (codigo == M17E_A || codigo == M17E_B) ? extra : 0;
    case M17_OPCOES:
        if (codigo == M17E_A)
            return '\n';
        if (codigo == M17E_B)
            return 27;
        if (codigo == 'k')
            return '-';   /* volta para a opcao de cima */
        if (codigo == 'l')
            return 't';
        if (codigo == 'h')
            return 'f';
        return 0;
    case M17_ITEM:
        return codigo == M17E_B ? 27 : 0;   /* o seletor cuida do resto */
    }
    return 0;
}

#ifndef M17E_TESTE
/* ------------------------------------------------------------------ parte SDL */
#include "m17.h"
#include "curses.h"

int m17_partida_encerrada;
static SDL_Joystick *joy;
static M17E_Config cfg;
static M17E_Estado est;
static int contexto = M17_NADA, contexto_extra;
static char fila[32];
static int fila_n;
static char *roteiro;
static size_t roteiro_i;
static int roteiro_lido;

void m17_contexto(int c)
{
    contexto = c;
    contexto_extra = 0;
}

void m17_contexto_item(int tipo)
{
    contexto = M17_ITEM;
    contexto_extra = tipo;
}

void m17_contexto_mais(int esperado)
{
    contexto = M17_MAIS;
    contexto_extra = esperado;
}

int m17_contexto_atual(void)
{
    return contexto;
}

void m17_enfileirar(const char *s)
{
    while (*s && fila_n < (int)sizeof(fila))
        fila[fila_n++] = *s++;
}

static int desenfileirar(void)
{
    int c = (unsigned char)fila[0];
    memmove(fila, fila + 1, (size_t)--fila_n);
    return c;
}

void m17e_iniciar_joystick(void)
{
    char av[1024];
    int n = m17e_config_ler(getenv("M17_ROGUE_CFG"), &cfg, av, sizeof(av));
    if (n > 0)
        for (char *l = strtok(av, "\n"); l != NULL; l = strtok(NULL, "\n"))
            fprintf(stderr, "[M17] %s\n", l);
    fprintf(stderr, "[M17] entrada: acorde %d ms, atraso %d ms, repeticao %d ms, zona morta %d\n", cfg.acorde_ms,
            cfg.atraso_ms, cfg.repeticao_ms, cfg.zona_morta);
    if (SDL_NumJoysticks() > 0)
    {
        joy = SDL_JoystickOpen(0);
        if (joy != NULL)
            fprintf(stderr, "[M17] joystick: %s (%d botoes, %d eixos)\n", SDL_JoystickName(joy),
                    SDL_JoystickNumButtons(joy), SDL_JoystickNumAxes(joy));
    }
    else
        fprintf(stderr, "[M17] joystick: nenhum (so teclado)\n");
}

/* roteiro de teste: texto; \e = Esc, \n = Enter, \\ = barra; {A} {B} {X} {Y} {L1} {L2} {R2} {SELECT} {START}
 * {cima} {baixo} {esq} {dir} = o botao do controle (passa pela mesma traducao que o controle) */
static int roteiro_proximo(int *codigo)
{
    *codigo = 0;
    if (!roteiro_lido)
    {
        roteiro_lido = 1;
        const char *arq = getenv("M17_ROTEIRO");
        FILE *f = arq ? fopen(arq, "r") : NULL;
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
        if (c == '\r' || (c == '\n'))
            continue;   /* quebras de linha do arquivo nao contam: Enter e \n */
        if (c == '\\')
        {
            char d = roteiro[roteiro_i++];
            return d == 'e' ? 27 : d == 'n' ? '\n' : d;
        }
        if (c == '{')
        {
            static const struct { const char *nome; int codigo; } T[] = {
                { "A", M17E_A }, { "B", M17E_B }, { "X", M17E_X }, { "Y", M17E_Y }, { "L1", M17E_L1 },
                { "L2", M17E_L2 }, { "R2", M17E_R2 }, { "SELECT", M17E_SELECT }, { "START", M17E_START },
                { "cima", 'k' }, { "baixo", 'j' }, { "esq", 'h' }, { "dir", 'l' },
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

/* um codigo do controle (ou do roteiro): menus abertos, contexto do jogo; devolve a tecla para o jogo ou 0 */
static int tratar(int codigo)
{
    if (m17m_ativo())
    {
        int r = m17m_navegar(codigo);
        m17v_apresentar();
        if (r > 0)
            return r;
        if (r < 0 && contexto == M17_ITEM)
            return 27;   /* fechou o seletor sem escolher: o jogo recebe Esc */
        return 0;
    }
    int t = m17e_traduzir(codigo, contexto, contexto == M17_NADA ? m17_heroi_na_escada() : contexto_extra);
    if (t == -1 || t == -2)
    {
        if (t == -1)
            m17m_abrir_comandos();
        else
            m17m_abrir_jogo();
        m17v_apresentar();
        return 0;
    }
    return t > 0 ? t : 0;
}

static int teclado(const SDL_Event *ev)
{
    if (ev->type == SDL_TEXTINPUT)
    {
        unsigned char c = (unsigned char)ev->text.text[0];
        if (c >= 32 && c < 127 && !m17m_ativo())
            return c;
        return 0;
    }
    if (ev->type != SDL_KEYDOWN)
        return 0;
    SDL_Keycode k = ev->key.keysym.sym;
    if (m17m_ativo())
    {
        int cod = k == SDLK_UP ? 'k' : k == SDLK_DOWN ? 'j' : k == SDLK_LEFT ? 'h' : k == SDLK_RIGHT ? 'l'
                : k == SDLK_RETURN ? M17E_A : k == SDLK_ESCAPE ? M17E_B : 0;
        return cod ? tratar(cod) : 0;
    }
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

int m17_tecla(void)
{
    m17v_iniciar();
    if (fila_n > 0)
        return desenfileirar();
    /* o jogo pergunta "qual objeto?": o seletor abre sozinho */
    if (contexto == M17_ITEM && !m17m_ativo())
    {
        m17m_abrir_seletor(contexto_extra);
        m17v_apresentar();
    }
    for (;;)
    {
        int cod, c = roteiro_proximo(&cod);
        if (c < 0)
            break;
        if (cod)
            c = tratar(cod);
        if (c > 0)
            return c;
        if (fila_n > 0)
            return desenfileirar();
    }
    for (;;)
    {
        SDL_Event ev;
        int tem = m17e_ocupado(&est) ? SDL_WaitEventTimeout(&ev, 10) : SDL_WaitEvent(&ev);
        while (tem)
        {
            if (ev.type == SDL_QUIT)
                m17_salvar_e_sair();
            if (ev.type == SDL_JOYDEVICEADDED && joy == NULL)
                joy = SDL_JoystickOpen(ev.jdevice.which);
            int c = teclado(&ev);
            if (c > 0)
                return c;
            if (fila_n > 0)
                return desenfileirar();
            tem = SDL_PollEvent(&ev);
        }
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
        int cod;
        while ((cod = m17e_passo(&est, &cfg, &in)) != 0)
        {
            int c = tratar(cod);
            if (fila_n > 0 && c <= 0)
                return desenfileirar();
            if (c > 0)
                return c;
        }
    }
}
#endif
