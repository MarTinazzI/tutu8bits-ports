/* winm17.c — a interface de janelas "m17" do NetHack 3.6.7 no M17 (spec 036, plano D-02..D-11).
 * Tela 80x24 (m17nh_video.c): linha 0 = mensagens, 1..21 = mapa (COLNO x ROWNO), 22..23 = estado (genl_status_*).
 * Listas, textos e perguntas em tela cheia por cima, desenhados com a mesma fonte; texto pelo teclado virtual.
 * Entrada: m17nh_entrada.c (controle cru pela maquina da spec 035, teclado do SDL, roteiro dos testes). */
#include "m17nh.h"   /* antes do hack.h: o math.h do SDL tem um yn() que o hack.h redefine como macro */
#include "roda_sdl.h" /* spec 048: a roda de opcoes (SDL tambem antes do hack.h) */
#include "hack.h"
#include "func_tab.h"
#include "dlb.h"
#include "teclado.h"

#include <stdio.h>
#include <stdlib.h>
#include <string.h>

#define MAX_JANELAS 32
#define L_MAPA0 1        /* 1a linha do mapa na tela */
#define L_ESTADO0 22     /* 1a linha do estado na tela */
#define HIST_MAX 40

typedef struct
{
    char *texto;
    char letra;          /* letra do jogo (0 = sem) */
    int atr;
    boolean escolhivel, escolhido;
    anything id;
} Item;

typedef struct
{
    int tipo;            /* NHW_* (0 = livre) */
    int cx, cy;          /* cursor (0-based) */
    Item *itens;
    int n, cap;
    char *prompt;
} Janela;

static Janela jan[MAX_JANELAS];
static int contexto = M17NH_MAPA;

/* mensagens (o "toplines" do tty): 0 = vazia, 1 = nova sem ter sido vista, 2 = vista */
static char linha_msg[BUFSZ];
static int msg_estado, msg_pular;
static char *hist[HIST_MAX];
static int hist_n;

int m17nh_parar(void) { return program_state.done_hup != 0; }

/* getpos (patch nethack-m17-01, D-09): o cursor aparece no mapa e as direcoes movem o cursor */
void m17nh_contexto_posicao(int ligado)
{
    contexto = ligado ? M17NH_POSICAO : M17NH_MAPA;
    if (!ligado)
        m17v_cursor(-1, -1);
}

/* A no mapa (D-12): '>' ou '<' com o heroi numa escada/escada de mao, senao 0 (pegar) */
static int na_escada(void)
{
    if (!u.ux)
        return 0;
    if ((u.ux == xdnstair && u.uy == ydnstair) || (u.ux == xdnladder && u.uy == ydnladder)
        || (u.ux == sstairs.sx && u.uy == sstairs.sy && !sstairs.up))
        return '>';
    if ((u.ux == xupstair && u.uy == yupstair) || (u.ux == xupladder && u.uy == yupladder)
        || (u.ux == sstairs.sx && u.uy == sstairs.sy && sstairs.up))
        return '<';
    return 0;
}

/* teclas que vao ao jogo nas proximas leituras (menus); um comando estendido pendente vai direto pelo get_ext_cmd */
static char fila[16];
static int fila_n;
static const char *ext_pendente;

/* declaradas antes: a escolha do personagem e os comandos estendidos usam as proprias listas da interface */
static winid m17_create_nhwindow(int);
static void m17_destroy_nhwindow(winid);
static void m17_start_menu(winid);
static void m17_add_menu(winid, int, const ANY_P *, CHAR_P, CHAR_P, int, const char *, BOOLEAN_P);
static void m17_end_menu(winid, const char *);
static int m17_select_menu(winid, int, MENU_ITEM_P **);
static void m17_putstr(winid, int, const char *);
static void m17_display_nhwindow(winid, BOOLEAN_P);

/* ------------------------------------------------------------------ tela */
static void escrever(int y, int x, const char *s, int cor, int inv)
{
    for (; *s && x < M17NH_COLUNAS; s++, x++)
        m17v_celula(y, x, (unsigned char)*s, cor, inv);
}

static void limpar_linha(int y, int x0)
{
    for (int x = x0; x < M17NH_COLUNAS; x++)
        m17v_celula(y, x, ' ', NO_COLOR, 0);
}

/* ------------------------------------------------------------------ leitura de uma tecla, por contexto */
static int ler_tecla(int ctx)
{
    for (;;)
    {
        m17v_mostrar();
        int cod, c = m17nh_ler(&cod);
        if (c == -3)
        {
            /* o SDL pediu para sair (janela fechada): o mesmo caminho do SIGTERM (hangup -> save) */
            if (!program_state.done_hup)
                program_state.done_hup = 1;
            return '\033';
        }
        if (c > 0)
            return c;
        int t = m17nh_traduzir(cod, ctx, ctx == M17NH_MAPA ? na_escada() : 0);
        if (t > 0)
            return t;
        if (t < 0 && ctx == M17NH_MAPA)
            return t;   /* menus (SELECT/START): quem chamou trata */
    }
}

/* ------------------------------------------------------------------ mensagens */
static void hist_guardar(const char *s)
{
    if (hist_n == HIST_MAX)
    {
        free(hist[0]);
        memmove(hist, hist + 1, sizeof(hist[0]) * (HIST_MAX - 1));
        hist_n--;
    }
    hist[hist_n++] = dupstr(s);
    if (getenv("M17_MSGS"))   /* testes: as mensagens no log */
        fprintf(stderr, "[M17] msg: %s\n", s);
}

static void mostrar_msg(void)
{
    limpar_linha(0, 0);
    escrever(0, 0, linha_msg, NO_COLOR, 0);
}

/* --More-- depois do texto da linha; A/Enter/espaco seguem, B/Esc pula as proximas mensagens deste turno */
static void mais(void)
{
    int x = (int)strlen(linha_msg) + 1;
    if (x > M17NH_COLUNAS - 8)
        x = M17NH_COLUNAS - 8;
    escrever(0, x, "--More--", CLR_WHITE, 1);
    m17v_cursor(0, x + 8 < M17NH_COLUNAS ? x + 8 : M17NH_COLUNAS - 1);
    for (;;)
    {
        int c = ler_tecla(M17NH_MAIS);
        if (c == '\033')
        {
            msg_pular = 1;
            break;
        }
        if (c == '\n' || c == '\r' || c == ' ')
            break;
        if (program_state.done_hup)
            break;
    }
    m17v_cursor(-1, -1);
    msg_estado = 2;
}

static void mensagem(const char *s)
{
    hist_guardar(s);
    if (msg_pular)
        return;
    size_t n = strlen(s), a = strlen(linha_msg);
    if (msg_estado == 1 && a > 0 && a + 2 + n <= M17NH_COLUNAS - 9)
    {
        Strcat(linha_msg, "  ");
        Strcat(linha_msg, s);
        mostrar_msg();
        return;
    }
    if (msg_estado == 1 && a > 0)
        mais();
    if (msg_pular)
        return;
    /* mensagem longa: em pedacos de ate 79 caracteres, quebrando no espaco */
    while (n > M17NH_COLUNAS - 9)
    {
        size_t k = M17NH_COLUNAS - 9;
        while (k > 20 && s[k] != ' ')
            k--;
        (void)strncpy(linha_msg, s, k);
        linha_msg[k] = '\0';
        mostrar_msg();
        msg_estado = 1;
        mais();
        if (msg_pular)
            return;
        s += k;
        while (*s == ' ')
            s++;
        n = strlen(s);
    }
    Strcpy(linha_msg, s);
    mostrar_msg();
    msg_estado = 1;
}

static void limpar_msg(void)
{
    linha_msg[0] = '\0';
    limpar_linha(0, 0);
    msg_estado = 0;
    msg_pular = 0;
}

/* ------------------------------------------------------------------ texto em tela cheia (NHW_TEXT e listas sem escolha) */
static void texto_tela_cheia(Janela *j)
{
    /* as linhas, quebradas em 80 colunas */
    int total = 0;
    for (int i = 0; i < j->n; i++)
        total += j->itens[i].texto[0] ? ((int)strlen(j->itens[i].texto) + M17NH_COLUNAS - 1) / M17NH_COLUNAS : 1;
    char **l = (char **)alloc(sizeof(char *) * (unsigned)(total + 1));
    int nl = 0;
    for (int i = 0; i < j->n; i++)
    {
        const char *s = j->itens[i].texto;
        do
        {
            char b[M17NH_COLUNAS + 1];
            (void)strncpy(b, s, M17NH_COLUNAS);
            b[M17NH_COLUNAS] = '\0';
            l[nl++] = dupstr(b);
            s += strlen(b);
        } while (*s);
    }
    int pag = M17NH_LINHAS - 1, ini = 0;
    for (;;)
    {
        m17v_limpar();
        for (int y = 0; y < pag && ini + y < nl; y++)
            escrever(y, 0, l[ini + y], NO_COLOR, 0);
        char rod[80];
        Sprintf(rod, "--(%d/%d)-- A segue  B fecha", ini / pag + 1, (nl + pag - 1) / pag ? (nl + pag - 1) / pag : 1);
        escrever(M17NH_LINHAS - 1, 0, rod, CLR_WHITE, 1);
        int c = ler_tecla(M17NH_MAIS);
        if (c == '\033' || program_state.done_hup)
            break;
        if (c == '<' || c == 'k')
            ini = ini >= pag ? ini - pag : 0;
        else if (ini + pag < nl)
            ini += pag;
        else
            break;
    }
    for (int i = 0; i < nl; i++)
        free(l[i]);
    free(l);
    m17v_limpar();
    docrt();   /* o jogo redesenha o mapa e o estado */
}

/* ------------------------------------------------------------------ janelas */
static void itens_limpar(Janela *j)
{
    for (int i = 0; i < j->n; i++)
        free(j->itens[i].texto);
    j->n = 0;
    if (j->prompt)
        free(j->prompt), j->prompt = NULL;
}

static void item_add(Janela *j, const char *s, char letra, int atr, boolean esc, const anything *id, boolean pre)
{
    if (j->n == j->cap)
    {
        j->cap = j->cap ? j->cap * 2 : 32;
        Item *novo = (Item *)alloc(sizeof(Item) * (unsigned)j->cap);
        if (j->n)
            memcpy(novo, j->itens, sizeof(Item) * (unsigned)j->n);
        if (j->itens)
            free(j->itens);
        j->itens = novo;
    }
    Item *it = &j->itens[j->n++];
    it->texto = dupstr(s);
    it->letra = letra;
    it->atr = atr;
    it->escolhivel = esc;
    it->escolhido = pre;
    if (id)
        it->id = *id;
    else
        it->id = zeroany;
}

static void m17_init_nhwindows(int *argc, char **argv)
{
    (void)argc;
    (void)argv;
    m17v_iniciar();
    m17nh_iniciar_entrada();
    iflags.window_inited = TRUE;
    iflags.cbreak = ON;
    iflags.echo = OFF;
    /* o mapa do jogo cabe inteiro (80x21): sem rolagem */
    fprintf(stderr, "[M17] interface m17 iniciada\n");
}

static void aleatorio(void)
{
    if (flags.initrole < 0)
    {
        flags.initrole = pick_role(flags.initrace, flags.initgend, flags.initalign, PICK_RANDOM);
        if (flags.initrole < 0)
            flags.initrole = randrole(FALSE);
    }
    if (flags.initrace < 0 || !validrace(flags.initrole, flags.initrace))
    {
        flags.initrace = pick_race(flags.initrole, flags.initgend, flags.initalign, PICK_RANDOM);
        if (flags.initrace < 0)
            flags.initrace = randrace(flags.initrole);
    }
    if (flags.initgend < 0 || !validgend(flags.initrole, flags.initrace, flags.initgend))
    {
        flags.initgend = pick_gend(flags.initrole, flags.initrace, flags.initalign, PICK_RANDOM);
        if (flags.initgend < 0)
            flags.initgend = randgend(flags.initrole, flags.initrace);
    }
    if (flags.initalign < 0 || !validalign(flags.initrole, flags.initrace, flags.initalign))
    {
        flags.initalign = pick_align(flags.initrole, flags.initrace, flags.initgend, PICK_RANDOM);
        if (flags.initalign < 0)
            flags.initalign = randalign(flags.initrole, flags.initrace);
    }
}

/* uma escolha por lista: itens (texto, valor), com "Aleatorio" no topo (valor ROLE_RANDOM); -1 = cancelou */
static int escolha(const char *titulo, const char **textos, const int *valores, int n)
{
    winid w = m17_create_nhwindow(NHW_MENU);
    m17_start_menu(w);
    anything id = zeroany;
    id.a_int = ROLE_RANDOM + 1000;
    m17_add_menu(w, NO_GLYPH, &id, '*', 0, ATR_NONE, "Aleatorio", FALSE);
    for (int i = 0; i < n; i++)
    {
        id.a_int = valores[i] + 1000;
        m17_add_menu(w, NO_GLYPH, &id, (char)(i < 26 ? 'a' + i : 'A' + i - 26), 0, ATR_NONE, textos[i], FALSE);
    }
    m17_end_menu(w, titulo);
    MENU_ITEM_P *sel = 0;
    int r = m17_select_menu(w, PICK_ONE, &sel), v = -1;
    if (r > 0)
    {
        v = sel[0].item.a_int - 1000;
        free((genericptr_t)sel);
    }
    m17_destroy_nhwindow(w);
    return v;
}

/* escolha do personagem (D-11): "aleatorio" ou classe -> raca -> sexo -> alinhamento, so com o que o jogo aceita */
static void m17_player_selection(void)
{
    const char *t[64];
    int v[64], n, r;
    rigid_role_checks();
    if (flags.initrole >= 0 && flags.initrace >= 0 && flags.initgend >= 0 && flags.initalign >= 0)
        return;
    t[0] = "Aleatorio (o jogo escolhe tudo)";
    t[1] = "Escolher classe, raca, sexo e alinhamento";
    v[0] = 0, v[1] = 1;
    winid w = m17_create_nhwindow(NHW_MENU);
    m17_start_menu(w);
    anything id = zeroany;
    id.a_int = 1;
    m17_add_menu(w, NO_GLYPH, &id, 'a', 0, ATR_NONE, t[0], FALSE);
    id.a_int = 2;
    m17_add_menu(w, NO_GLYPH, &id, 'b', 0, ATR_NONE, t[1], FALSE);
    m17_end_menu(w, "Novo personagem");
    MENU_ITEM_P *sel = 0;
    r = m17_select_menu(w, PICK_ONE, &sel);
    int escolher = (r > 0 && sel[0].item.a_int == 2);
    if (r > 0)
        free((genericptr_t)sel);
    m17_destroy_nhwindow(w);
    if (escolher)
    {
        if (flags.initrole < 0)
        {
            n = 0;
            for (int i = 0; roles[i].name.m && n < 64; i++)
                if (ok_role(i, flags.initrace, flags.initgend, flags.initalign))
                    t[n] = roles[i].name.m, v[n++] = i;
            flags.initrole = escolha("Classe", t, v, n);
            if (flags.initrole == ROLE_RANDOM || flags.initrole < 0)
                flags.initrole = ROLE_NONE;
        }
        if (flags.initrole >= 0 && flags.initrace < 0)
        {
            n = 0;
            for (int i = 0; races[i].noun && n < 64; i++)
                if (ok_race(flags.initrole, i, flags.initgend, flags.initalign))
                    t[n] = races[i].noun, v[n++] = i;
            flags.initrace = escolha("Raca", t, v, n);
            if (flags.initrace < 0)
                flags.initrace = ROLE_NONE;
        }
        if (flags.initrole >= 0 && flags.initrace >= 0 && flags.initgend < 0)
        {
            n = 0;
            for (int i = 0; i < ROLE_GENDERS; i++)
                if (ok_gend(flags.initrole, flags.initrace, i, flags.initalign))
                    t[n] = genders[i].adj, v[n++] = i;
            flags.initgend = escolha("Sexo", t, v, n);
            if (flags.initgend < 0)
                flags.initgend = ROLE_NONE;
        }
        if (flags.initrole >= 0 && flags.initrace >= 0 && flags.initgend >= 0 && flags.initalign < 0)
        {
            n = 0;
            for (int i = 0; i < ROLE_ALIGNS; i++)
                if (ok_align(flags.initrole, flags.initrace, flags.initgend, i))
                    t[n] = aligns[i].adj, v[n++] = i;
            flags.initalign = escolha("Alinhamento", t, v, n);
            if (flags.initalign < 0)
                flags.initalign = ROLE_NONE;
        }
    }
    aleatorio();
}

static void m17_askname(void)
{
    char b[PL_NSIZ] = "";
    if (m17_teclado(m17v_renderer(), "Nome do personagem", b, PL_NSIZ - 1) && b[0])
        (void)strncpy(plname, b, PL_NSIZ - 1);
    else
        Strcpy(plname, "Tutu");
    m17v_redesenhar();
}

static void m17_get_nh_event(void) { }

static void m17_exit_nhwindows(const char *s)
{
    if (s && *s)
        fprintf(stderr, "%s\n", s);
    m17v_mostrar();
}

static void m17_suspend_nhwindows(const char *s) { (void)s; }
static void m17_resume_nhwindows(void) { m17v_redesenhar(); }

static winid m17_create_nhwindow(int tipo)
{
    for (int i = 1; i < MAX_JANELAS; i++)
        if (jan[i].tipo == 0)
        {
            jan[i].tipo = tipo;
            jan[i].cx = jan[i].cy = 0;
            jan[i].n = 0;
            return i;
        }
    panic("m17: janelas demais");
    return WIN_ERR;
}

static void m17_clear_nhwindow(winid w)
{
    if (w < 0 || w >= MAX_JANELAS)
        return;
    switch (jan[w].tipo)
    {
    case NHW_MESSAGE:
        limpar_msg();
        break;
    case NHW_MAP:
        for (int y = L_MAPA0; y < L_MAPA0 + ROWNO; y++)
            limpar_linha(y, 0);
        break;
    case NHW_STATUS:
        limpar_linha(L_ESTADO0, 0);
        limpar_linha(L_ESTADO0 + 1, 0);
        break;
    default:
        itens_limpar(&jan[w]);
        break;
    }
}

static void m17_display_nhwindow(winid w, BOOLEAN_P bloquear)
{
    if (w < 0 || w >= MAX_JANELAS)
        return;
    Janela *j = &jan[w];
    switch (j->tipo)
    {
    case NHW_MESSAGE:
        if (msg_estado == 1 && bloquear)
            mais();
        m17v_mostrar();
        break;
    case NHW_MAP:
    case NHW_STATUS:
        m17v_mostrar();
        break;
    default:
        if (j->n > 0)
            texto_tela_cheia(j);
        break;
    }
}

static void m17_destroy_nhwindow(winid w)
{
    if (w <= 0 || w >= MAX_JANELAS)
        return;
    itens_limpar(&jan[w]);
    if (jan[w].itens)
        free(jan[w].itens);
    memset(&jan[w], 0, sizeof(jan[w]));
}

static void m17_curs(winid w, int x, int y)
{
    if (w < 0 || w >= MAX_JANELAS)
        return;
    jan[w].cx = x - 1;   /* o jogo conta as colunas a partir de 1 (como o tty) */
    jan[w].cy = y;
    if (jan[w].tipo == NHW_MAP && contexto == M17NH_POSICAO)
        m17v_cursor(L_MAPA0 + y, x - 1);
}

static void m17_putstr(winid w, int atr, const char *s)
{
    if (w < 0 || w >= MAX_JANELAS)
        return;
    Janela *j = &jan[w];
    switch (j->tipo)
    {
    case NHW_MESSAGE:
        mensagem(s);
        break;
    case NHW_STATUS:
        if (j->cy >= 0 && j->cy < 2)
        {
            limpar_linha(L_ESTADO0 + j->cy, 0);
            escrever(L_ESTADO0 + j->cy, j->cx > 0 ? j->cx : 0, s, NO_COLOR, 0);
        }
        break;
    case NHW_MAP:
        escrever(L_MAPA0 + j->cy, j->cx, s, NO_COLOR, atr == ATR_INVERSE);
        break;
    default:
        item_add(j, s, 0, atr, FALSE, NULL, FALSE);
        break;
    }
}

static void m17_display_file(const char *nome, BOOLEAN_P avisar)
{
    dlb *f = dlb_fopen(nome, "r");
    if (f == NULL)
    {
        if (avisar)
            pline("Nao achei o arquivo \"%s\".", nome);
        return;
    }
    winid w = m17_create_nhwindow(NHW_TEXT);
    char b[BUFSZ];
    while (dlb_fgets(b, BUFSZ, f))
    {
        char *p = index(b, '\n');
        if (p)
            *p = '\0';
        p = index(b, '\t');   /* o arquivo pode ter tabulacoes: o texto e mostrado como esta */
        if (p)
            *p = ' ';
        m17_putstr(w, 0, b);
    }
    (void)dlb_fclose(f);
    m17_display_nhwindow(w, TRUE);
    m17_destroy_nhwindow(w);
}

/* ------------------------------------------------------------------ listas (T05) */
static void m17_start_menu(winid w)
{
    if (w > 0 && w < MAX_JANELAS)
        itens_limpar(&jan[w]);
}

static void m17_add_menu(winid w, int glifo, const ANY_P *id, CHAR_P letra, CHAR_P grupo, int atr, const char *s,
                         BOOLEAN_P pre)
{
    (void)glifo;
    (void)grupo;
    if (w <= 0 || w >= MAX_JANELAS)
        return;
    item_add(&jan[w], s, letra, atr, id && id->a_void != 0, id, pre);
}

static void m17_end_menu(winid w, const char *prompt)
{
    if (w > 0 && w < MAX_JANELAS && prompt)
        jan[w].prompt = dupstr(prompt);
}

/* um evento cru: tecla (> 0) ou 0 com *cod = codigo do controle; -3 = sair */
static int ler_evento(int *cod)
{
    m17v_mostrar();
    int c = m17nh_ler(cod);
    if (c == -3 && !program_state.done_hup)
        program_state.done_hup = 1;
    return c;
}

/* "?" automatico nas perguntas de objeto (D-08): se a lista que ele abriu for cancelada, a proxima vez devolve Esc */
static int lista_auto, lista_auto_cancelada;

/* a lista em tela cheia (D-07): linha 0 = titulo, 1..22 = itens, 23 = ajuda. Devolve o numero escolhido (sel) ou -1 */
static int lista(Janela *j, int como, MENU_ITEM_P **sel)
{
    const int pag = M17NH_LINHAS - 2;
    int n = j->n, cur = -1, ini = 0, res = -1;
    for (int i = 0; i < n && cur < 0; i++)
        if (j->itens[i].escolhivel)
            cur = i;
    if (cur < 0)
    {
        texto_tela_cheia(j);
        return 0;
    }
    for (;;)
    {
        if (cur < ini)
            ini = (cur / pag) * pag;
        if (cur >= ini + pag)
            ini = (cur / pag) * pag;
        m17v_limpar();
        escrever(0, 0, j->prompt ? j->prompt : (como == PICK_ANY ? "Escolha (varios)" : "Escolha"), CLR_YELLOW, 0);
        for (int y = 0; y < pag && ini + y < n; y++)
        {
            Item *it = &j->itens[ini + y];
            char b[BUFSZ];
            if (it->escolhivel)
                Sprintf(b, "%c %c %s", it->letra ? it->letra : ' ',
                        como == PICK_ANY ? (it->escolhido ? '+' : '-') : '-', it->texto);
            else
                Sprintf(b, "%s", it->texto);
            int cor = it->escolhivel ? NO_COLOR : (it->atr == ATR_INVERSE || it->atr == ATR_BOLD ? CLR_WHITE : NO_COLOR);
            escrever(1 + y, 0, b, cor, (ini + y == cur) || (!it->escolhivel && it->atr == ATR_INVERSE));
        }
        char ajuda[96];
        Sprintf(ajuda, "%s B volta  <-/-> pagina %d/%d%s", como == PICK_ANY ? "A marca  X todos  START ok" : "A escolhe",
                ini / pag + 1, (n + pag - 1) / pag, como == PICK_ANY ? "" : "");
        escrever(M17NH_LINHAS - 1, 0, ajuda, CLR_WHITE, 1);
        int cod, c = ler_evento(&cod);
        if (c == -3 || program_state.done_hup)
            break;
        int acao = 0;   /* 1 escolhe/marca, 2 confirma, 3 cancela, 4 todos */
        if (c > 0)
        {
            if (c == '\033')
                acao = 3;
            else if (c == '\n' || c == '\r')
                acao = (como == PICK_ONE) ? 1 : 2;
            else if (c == '>' )
                cur = (ini + pag < n) ? ini + pag : cur;
            else if (c == '<')
                cur = ini >= pag ? ini - pag : 0;
            else if (c == '.' && como == PICK_ANY)
                acao = 4;
            else
                for (int i = 0; i < n; i++)
                    if (j->itens[i].escolhivel && j->itens[i].letra == c)
                    {
                        cur = i;
                        acao = 1;
                        break;
                    }
        }
        else
        {
            switch (cod)
            {
            case 'k': case 'K': case 'y': case 'u':
                for (int i = cur - 1; i >= 0; i--)
                    if (j->itens[i].escolhivel) { cur = i; break; }
                break;
            case 'j': case 'J': case 'b': case 'n':
                for (int i = cur + 1; i < n; i++)
                    if (j->itens[i].escolhivel) { cur = i; break; }
                break;
            case 'h': case 'H':
                cur = ini >= pag ? ini - pag : 0;
                break;
            case 'l': case 'L':
                cur = ini + pag < n ? ini + pag : n - 1;
                break;
            case M17E_A: acao = 1; break;
            case M17E_START: acao = 2; break;
            case M17E_B: acao = 3; break;
            case M17E_X: acao = (como == PICK_ANY) ? 4 : 0; break;
            }
            /* paginas: o cursor vai para o 1o item escolhivel a partir dali */
            while (cur < n && !j->itens[cur].escolhivel)
                cur++;
            if (cur >= n)
                for (cur = n - 1; cur > 0 && !j->itens[cur].escolhivel; cur--)
                    ;
        }
        if (acao == 1)
        {
            if (como == PICK_ONE)
            {
                for (int i = 0; i < n; i++)
                    j->itens[i].escolhido = (i == cur);
                acao = 2;
            }
            else
                j->itens[cur].escolhido = !j->itens[cur].escolhido;
        }
        if (acao == 4)
        {
            int todos = 1;
            for (int i = 0; i < n; i++)
                if (j->itens[i].escolhivel && !j->itens[i].escolhido)
                    todos = 0;
            for (int i = 0; i < n; i++)
                if (j->itens[i].escolhivel)
                    j->itens[i].escolhido = !todos;
        }
        if (acao == 3)
            break;
        if (acao == 2)
        {
            int k = 0;
            for (int i = 0; i < n; i++)
                if (j->itens[i].escolhivel && j->itens[i].escolhido)
                    k++;
            if (k > 0)
            {
                *sel = (MENU_ITEM_P *)alloc(sizeof(MENU_ITEM_P) * (unsigned)k);
                k = 0;
                for (int i = 0; i < n; i++)
                    if (j->itens[i].escolhivel && j->itens[i].escolhido)
                    {
                        (*sel)[k].item = j->itens[i].id;
                        (*sel)[k].count = -1L;
                        k++;
                    }
            }
            res = k;
            break;
        }
    }
    m17v_limpar();
    if (iflags.window_inited && u.ux)
        docrt();
    return res;
}

static int m17_select_menu(winid w, int como, MENU_ITEM_P **sel)
{
    *sel = (MENU_ITEM_P *)0;
    if (w <= 0 || w >= MAX_JANELAS)
        return -1;
    if (como == PICK_NONE)
    {
        texto_tela_cheia(&jan[w]);
        return 0;
    }
    int r = lista(&jan[w], como, sel);
    if (lista_auto)
    {
        lista_auto_cancelada = (r <= 0);
        lista_auto = 0;
    }
    return r;
}

/* um item so na pergunta de objeto (getobj -> display_pickinv): o genl_message_menu so escreve a linha e devolve 0,
 * o getobj pergunta de novo, o '?' automatico volta e o jogo nao sai do laco (nem com o SIGTERM: sessao 1 da 048,
 * "Aplicar" com uma ferramenta so, SIGKILL sem salvar). Aqui vira a mesma lista de sempre, com um item */
static char m17_message_menu(CHAR_P letra, int como, const char *s)
{
    if (como != PICK_ONE)
        return genl_message_menu(letra, como, s);
    winid w = m17_create_nhwindow(NHW_MENU);
    anything id;
    MENU_ITEM_P *sel = NULL;
    id = zeroany;
    id.a_char = letra;
    m17_start_menu(w);
    if (s[0] == letra && !strncmp(s + 1, " - ", 3))
        s += 4;   /* o xprname ja traz "c - ": a lista poe a letra */
    m17_add_menu(w, NO_GLYPH, &id, letra, 0, ATR_NONE, s, FALSE);
    m17_end_menu(w, (char *)0);
    int n = m17_select_menu(w, PICK_ONE, &sel);
    m17_destroy_nhwindow(w);
    lista_auto_cancelada = 0;   /* a resposta vai agora; a proxima pergunta de objeto comeca do zero */
    if (n > 0 && sel)
    {
        char c = sel[0].item.a_char;
        free(sel);
        return c;
    }
    if (sel)
        free(sel);
    return '\033';
}

static void m17_update_inventory(void) { }
static void m17_mark_synch(void) { m17v_mostrar(); }
static void m17_wait_synch(void) { m17v_mostrar(); }
static void m17_cliparound(int x, int y) { (void)x, (void)y; }   /* o mapa cabe inteiro */

static void m17_print_glyph(winid w, XCHAR_P x, XCHAR_P y, int glifo, int fundo)
{
    (void)w;
    (void)fundo;
    int ch, cor;
    unsigned especial;
    (void)mapglyph(glifo, &ch, &cor, &especial, x, y, 0);
    int inv = ((especial & MG_PET) && iflags.hilite_pet) || ((especial & MG_OBJPILE) && iflags.hilite_pile)
              || ((especial & MG_DETECT) && iflags.use_inverse);
    if (!iflags.use_color)
        cor = NO_COLOR;
    m17v_celula(L_MAPA0 + y, x - 1, (unsigned char)ch, cor, inv);
}

static void m17_raw_print(const char *s)
{
    fprintf(stderr, "%s\n", s);
    if (iflags.window_inited)
        mensagem(s);
}

/* menus do controle (D-13): SELECT = comandos agrupados, START = jogo. Devolve a tecla (e enfileira o resto) ou 0 */
typedef struct { const char *nome, *teclas; } Comando;
static const Comando CMD_SELECT[] = {
    { "-- Itens --", NULL },
    { "Beber (q)", "q" }, { "Ler (r)", "r" }, { "Comer (e)", "e" }, { "Empunhar (w)", "w" },
    { "Vestir (W)", "W" }, { "Tirar armadura (T)", "T" }, { "Colocar acessorio (P)", "P" },
    { "Remover acessorio (R)", "R" }, { "Aplicar/usar (a)", "a" }, { "Largar (d)", "d" },
    { "Largar varios (D)", "D" }, { "Arremessar (t)", "t" }, { "Disparar a aljava (f)", "f" },
    { "Escolher a aljava (Q)", "Q" }, { "Pegar (,)", "," },
    { "-- Magia --", NULL },
    { "Lancar magia (Z)", "Z" }, { "Usar varinha (z)", "z" }, { "Invocar (#invoke)", "#invoke" },
    { "-- Movimento --", NULL },
    { "Subir (<)", "<" }, { "Descer (>)", ">" }, { "Viajar ate um lugar (_)", "_" }, { "Ir longe (G)", "G" },
    { "-- Combate --", NULL },
    { "Lutar numa direcao (F)", "F" }, { "Chutar (^D)", "\004" },
    { "-- Acoes --", NULL },
    { "Procurar (s)", "s" }, { "Abrir porta (o)", "o" }, { "Fechar porta (c)", "c" }, { "Gravar no chao (E)", "E" },
    { "Pagar (p)", "p" }, { "Rezar (#pray)", "#pray" }, { "Oferecer (#offer)", "#offer" },
    { "Saquear (#loot)", "#loot" }, { "Forcar fechadura (#force)", "#force" }, { "Sentar (#sit)", "#sit" },
    { "Mergulhar (#dip)", "#dip" }, { "Melhorar pericias (#enhance)", "#enhance" },
    { "Conversar (#chat)", "#chat" }, { "Outros comandos (#)", "#" },
    { "-- Informacao --", NULL },
    { "Olhar no mapa (;)", ";" }, { "Olhar aqui (:)", ":" }, { "Descobertas [\\]", "\\" },
    { "Arma em uso [)]", ")" }, { "Armadura em uso [[]", "[" }, { "Aneis em uso [=]", "=" }, { "Amuleto em uso [\"]", "\"" },
    { "Ferramentas em uso [(]", "(" }, { "Atributos (^X)", "\030" }, { "Mensagens anteriores (^P)", "\020" },
    { NULL, NULL }
};
static const Comando CMD_START[] = {
    { "Ajuda (?)", "?" }, { "Opcoes (O)", "O" }, { "Salvar e sair (S)", "S" }, { "Desistir da partida (#quit)", "#quit" },
    { NULL, NULL }
};

static int menu_comandos(const Comando *t, const char *titulo)
{
    winid w = m17_create_nhwindow(NHW_MENU);
    m17_start_menu(w);
    anything id;
    for (int i = 0; t[i].nome; i++)
    {
        id = zeroany;
        if (t[i].teclas)
            id.a_int = i + 1;
        m17_add_menu(w, NO_GLYPH, &id, 0, 0, t[i].teclas ? ATR_NONE : ATR_INVERSE, t[i].nome, FALSE);
    }
    m17_end_menu(w, titulo);
    MENU_ITEM_P *sel = 0;
    int r = m17_select_menu(w, PICK_ONE, &sel), k = 0;
    if (r > 0)
    {
        const char *tc = t[sel[0].item.a_int - 1].teclas;
        free((genericptr_t)sel);
        if (tc[0] == '#' && tc[1])
        {
            ext_pendente = tc + 1;   /* o get_ext_cmd devolve este, sem a lista */
            k = '#';
        }
        else
        {
            k = (unsigned char)tc[0];
            for (int i = 1; tc[i] && fila_n < (int)sizeof(fila); i++)
                fila[fila_n++] = tc[i];
        }
    }
    m17_destroy_nhwindow(w);
    return k;
}

/* a roda de opcoes (spec 048, plano D-04/D-12): o R3 no mapa. A acao entra pelo mesmo caminho do menu do SELECT:
 * "#comando" = comando estendido; o resto pela notacao comum (caracteres, ^X), a 1a tecla devolvida e as outras na
 * fila. Devolve a tecla, 0 = nada (cancelada, sem roda, acao que o NetHack nao executa) ou -3 = SDL_QUIT */
static int roda_abrir(void)
{
    static Roda roda;
    static int lida, tem, rapido;
    static char ext[RODA_ACAO + 1];
    char acao[RODA_ACAO + 1], b[RODA_ACAO + 1];
    if (!lida)
    {
        lida = 1;
        tem = m17_roda_carregar(&roda, &rapido);
        m17_roda_definir_parar(m17nh_parar);   /* o VOL+ segurado (SIGTERM) fecha a roda aberta */
    }
    if (!tem)
        return 0;
    int r = m17_roda(m17v_renderer(), &roda, rapido, m17v_fundo, NULL, acao, sizeof acao);
    m17v_redesenhar();
    if (r < 0)
        return -3;
    if (r == 0)
        return 0;
    if (acao[0] == '#' && acao[1])
    {
        snprintf(ext, sizeof ext, "%s", acao + 1);
        ext_pendente = ext;   /* o get_ext_cmd devolve este, sem a lista */
        return '#';
    }
    if (acao[0] == '@' || roda_teclas(acao, b, (int)sizeof b) <= 0)
    {
        fprintf(stderr, "[M17] roda: acao \"%s\" o NetHack nao executa\n", acao);
        return 0;
    }
    for (int i = 1; b[i] && fila_n < (int)sizeof(fila); i++)
        fila[fila_n++] = b[i];
    return (unsigned char)b[0];
}

static int m17_nhgetch(void)
{
    if (msg_estado == 1)
        msg_estado = 2;
    if (fila_n > 0)
    {
        int c = (unsigned char)fila[0];
        memmove(fila, fila + 1, (size_t)--fila_n);
        return c;
    }
    for (;;)
    {
        int c = ler_tecla(contexto);
        if (c == -4)
        {
            c = roda_abrir();
            if (c == -3)
            {
                /* SDL_QUIT com a roda aberta: o mesmo caminho do ler_tecla (hangup -> save) */
                if (!program_state.done_hup)
                    program_state.done_hup = 1;
                return '\033';
            }
            if (c == 0)
                continue;
            return c;
        }
        if (c == -1 || c == -2)
        {
            c = menu_comandos(c == -1 ? CMD_SELECT : CMD_START, c == -1 ? "Comandos (SELECT)" : "Jogo (START)");
            if (c == 0)
                continue;
        }
        return c < 0 ? 0 : c;
    }
}

static int m17_nh_poskey(int *x, int *y, int *mod)
{
    (void)x, (void)y, (void)mod;
    return m17_nhgetch();
}

static void m17_nhbell(void) { }

static int m17_doprev_message(void)
{
    winid w = m17_create_nhwindow(NHW_TEXT);
    for (int i = 0; i < hist_n; i++)
        m17_putstr(w, 0, hist[i]);
    m17_display_nhwindow(w, TRUE);
    m17_destroy_nhwindow(w);
    return 0;
}

/* pergunta (D-08): com as respostas dadas pelo jogo, A = y, B = Esc (vira q/n), X = q; sem respostas e com "?*]" (qual
 * objeto?) devolve "?" e o jogo abre a lista dele; sem respostas = direcao (as 8, A = em si, L1/L2 = < >) */
static char m17_yn_function(const char *q, const char *opcoes, CHAR_P padrao)
{
    char p[BUFSZ];
    if (opcoes && *opcoes)
    {
        char r[BUFSZ];
        Strcpy(r, opcoes);
        char *e = index(r, '\033');
        if (e)
            *e = '\0';
        if (padrao)
            Sprintf(p, "%s [%s] (%c) ", q, r, padrao);
        else
            Sprintf(p, "%s [%s] ", q, r);
    }
    else
        Sprintf(p, "%s ", q);
    if (msg_estado == 1)
        mais();
    limpar_msg();
    Strcpy(linha_msg, p);
    mostrar_msg();
    hist_guardar(p);
    m17v_cursor(0, (int)strlen(p) < M17NH_COLUNAS ? (int)strlen(p) : M17NH_COLUNAS - 1);
    int objeto = (!opcoes || !*opcoes) && strstr(q, "?*]") != NULL;
    if (objeto)
    {
        m17v_cursor(-1, -1);
        if (lista_auto_cancelada)
        {
            lista_auto_cancelada = 0;
            limpar_msg();
            return '\033';
        }
        lista_auto = 1;
        return '?';
    }
    char res = padrao;
    for (;;)
    {
        int cod, c = ler_evento(&cod);
        if (c == -3 || program_state.done_hup)
        {
            res = '\033';
            break;
        }
        if (c == 0)
        {
            if (opcoes && *opcoes)
            {
                c = cod == M17E_A ? (index(opcoes, 'y') ? 'y' : padrao)
                    : cod == M17E_B ? '\033'
                    : (cod == M17E_X && index(opcoes, 'q')) ? 'q' : 0;
                if (c == 0)
                    continue;
            }
            else
            {
                c = m17nh_traduzir(cod, M17NH_PERGUNTA, 0);
                if (c <= 0)
                    continue;
            }
        }
        if (c == '\033')
        {
            res = (opcoes && index(opcoes, 'q')) ? 'q' : (opcoes && index(opcoes, 'n')) ? 'n'
                  : (opcoes && *opcoes) ? padrao : '\033';
            break;
        }
        if ((c == '\n' || c == ' ' || c == '\r') && padrao)
        {
            res = padrao;
            break;
        }
        if (!opcoes || !*opcoes || index(opcoes, c))
        {
            res = (char)c;
            break;
        }
    }
    m17v_cursor(-1, -1);
    limpar_msg();
    return res;
}

static void m17_getlin(const char *q, char *b)
{
    b[0] = '\0';
    if (!m17_teclado(m17v_renderer(), q, b, BUFSZ - 1))
        Strcpy(b, "\033");
    m17v_redesenhar();
}

/* comandos estendidos (D-10): lista, os mais usados primeiro */
static int m17_get_ext_cmd(void)
{
    if (ext_pendente)
    {
        const char *p = ext_pendente;
        ext_pendente = NULL;
        for (int i = 0; extcmdlist[i].ef_txt; i++)
            if (!strcmp(extcmdlist[i].ef_txt, p))
                return i;
        return -1;
    }
    static const char *primeiro[] = { "pray", "offer", "loot", "force", "sit", "dip", "enhance", "chat", "ride",
                                      "turn", "untrap", "jump", "monster", "wipe", "name", "conduct", "overview",
                                      NULL };
    winid w = m17_create_nhwindow(NHW_MENU);
    m17_start_menu(w);
    anything id;
    int n = 0;
    /* 1o os mais usados, na ordem de "primeiro"; depois o resto, na ordem do jogo */
    int nprim = 0;
    while (primeiro[nprim])
        nprim++;
    for (int f = 0; f <= nprim; f++)
        for (int i = 0; extcmdlist[i].ef_txt; i++)
        {
            const struct ext_func_tab *e = &extcmdlist[i];
            if ((e->flags & (WIZMODECMD | CMD_NOT_AVAILABLE)) && !wizard)
                continue;
            if (!strcmp(e->ef_txt, "#") || !strcmp(e->ef_txt, "?"))
                continue;
            int pref = -1;
            for (int k = 0; primeiro[k]; k++)
                if (!strcmp(primeiro[k], e->ef_txt))
                    pref = k;
            if (f < nprim ? pref != f : pref >= 0)
                continue;
            char b2[BUFSZ];
            Sprintf(b2, "%-12s %s", e->ef_txt, e->ef_desc ? e->ef_desc : "");
            id = zeroany;
            id.a_int = i + 1;
            m17_add_menu(w, NO_GLYPH, &id, 0, 0, ATR_NONE, b2, FALSE);
            n++;
        }
    m17_end_menu(w, "Comando estendido (#)");
    MENU_ITEM_P *sel = 0;
    int r = n ? m17_select_menu(w, PICK_ONE, &sel) : -1;
    int res = -1;
    if (r > 0)
    {
        res = sel[0].item.a_int - 1;
        free((genericptr_t)sel);
    }
    m17_destroy_nhwindow(w);
    return res;
}
static void m17_number_pad(int s) { (void)s; }
static void m17_delay_output(void)
{
    m17v_mostrar();
    SDL_Delay(50);
}
static void m17_start_screen(void) { }
static void m17_end_screen(void) { }

static void m17_outrip(winid w, int como, time_t quando)
{
    (void)como;
    (void)quando;
    m17_putstr(w, 0, "");
}

struct window_procs m17_procs = {
    "m17", WC_COLOR | WC_HILITE_PET | WC_INVERSE, 0L,
    { 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1 },
    m17_init_nhwindows, m17_player_selection, m17_askname, m17_get_nh_event, m17_exit_nhwindows,
    m17_suspend_nhwindows, m17_resume_nhwindows, m17_create_nhwindow, m17_clear_nhwindow, m17_display_nhwindow,
    m17_destroy_nhwindow, m17_curs, m17_putstr, genl_putmixed, m17_display_file, m17_start_menu, m17_add_menu,
    m17_end_menu, m17_select_menu, m17_message_menu, m17_update_inventory, m17_mark_synch, m17_wait_synch,
#ifdef CLIPPING
    m17_cliparound,
#endif
#ifdef POSITIONBAR
    donull,
#endif
    m17_print_glyph, m17_raw_print, m17_raw_print, m17_nhgetch, m17_nh_poskey, m17_nhbell, m17_doprev_message,
    m17_yn_function, m17_getlin, m17_get_ext_cmd, m17_number_pad, m17_delay_output,
#ifdef CHANGE_COLOR
    donull, donull,
#ifdef MAC
    donull, donull,
#endif
#endif
    m17_start_screen, m17_end_screen, m17_outrip, genl_preference_update, genl_getmsghistory, genl_putmsghistory,
    genl_status_init, genl_status_finish, genl_status_enablefield, genl_status_update, genl_can_suspend_no,
};
