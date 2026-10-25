/* m17curses.c — a curses propria do Rogue no M17 (spec 035, plano D-02). Ver curses.h. */
#include "curses.h"

#include <stdio.h>
#include <stdlib.h>
#include <string.h>

WINDOW *stdscr, *curscr;
int LINES = 24, COLS = 80, ESCDELAY = 0;
static bool m17c_fim = false;

static void marcar(WINDOW *w, int y, int x0, int x1)
{
    /* numa subjanela a mudanca vale tambem para a mae (as linhas sao as mesmas) */
    for (WINDOW *j = w; j != NULL; y += j->dy, x0 += j->dx, x1 += j->dx, j = j->mae)
    {
        if (y < 0 || y >= j->linhas)
            continue;
        if (j->mudou_ini[y] < 0 || x0 < j->mudou_ini[y])
            j->mudou_ini[y] = x0;
        if (x1 > j->mudou_fim[y])
            j->mudou_fim[y] = x1;
    }
}

static WINDOW *criar(int linhas, int colunas, int y0, int x0)
{
    if (linhas <= 0)
        linhas = LINES - y0;
    if (colunas <= 0)
        colunas = COLS - x0;
    WINDOW *w = calloc(1, sizeof(*w));
    w->linhas = linhas;
    w->colunas = colunas;
    w->y0 = y0;
    w->x0 = x0;
    w->l = calloc((size_t)linhas, sizeof(chtype *));
    w->mudou_ini = malloc((size_t)linhas * sizeof(int));
    w->mudou_fim = malloc((size_t)linhas * sizeof(int));
    for (int y = 0; y < linhas; y++)
        w->mudou_ini[y] = w->mudou_fim[y] = -1;
    return w;
}

WINDOW *newwin(int linhas, int colunas, int y0, int x0)
{
    WINDOW *w = criar(linhas, colunas, y0, x0);
    for (int y = 0; y < w->linhas; y++)
    {
        w->l[y] = malloc((size_t)w->colunas * sizeof(chtype));
        for (int x = 0; x < w->colunas; x++)
            w->l[y][x] = ' ';
    }
    touchwin(w);
    return w;
}

WINDOW *subwin(WINDOW *mae, int linhas, int colunas, int y0, int x0)
{
    WINDOW *w = criar(linhas, colunas, y0, x0);
    w->mae = mae;
    w->dy = y0 - mae->y0;
    w->dx = x0 - mae->x0;
    for (int y = 0; y < w->linhas; y++)
        w->l[y] = mae->l[y + y0 - mae->y0] + (x0 - mae->x0);
    return w;
}

int delwin(WINDOW *w)
{
    if (w == NULL)
        return ERR;
    if (w->mae == NULL)
        for (int y = 0; y < w->linhas; y++)
            free(w->l[y]);
    free(w->l);
    free(w->mudou_ini);
    free(w->mudou_fim);
    if (w == stdscr)
        stdscr = NULL;
    if (w == curscr)
        curscr = NULL;
    free(w);
    return OK;
}

WINDOW *initscr(void)
{
    m17c_fim = false;
    if (curscr == NULL)
        curscr = newwin(LINES, COLS, 0, 0);
    if (stdscr == NULL)
        stdscr = newwin(LINES, COLS, 0, 0);
    curscr->limpar = true;
    return stdscr;
}

int endwin(void)
{
    m17c_fim = true;
    return OK;
}

bool isendwin(void)
{
    return m17c_fim;
}

int mvwin(WINDOW *w, int y0, int x0)
{
    if (y0 < 0 || x0 < 0 || y0 + w->linhas > LINES || x0 + w->colunas > COLS)
        return ERR;
    w->y0 = y0;
    w->x0 = x0;
    touchwin(w);
    return OK;
}

int overwrite(const WINDOW *de, WINDOW *para)
{
    /* copia a parte que se sobrepoe (na tela), espacos inclusive */
    for (int y = 0; y < de->linhas; y++)
    {
        int ty = y + de->y0 - para->y0;
        if (ty < 0 || ty >= para->linhas)
            continue;
        for (int x = 0; x < de->colunas; x++)
        {
            int tx = x + de->x0 - para->x0;
            if (tx < 0 || tx >= para->colunas)
                continue;
            para->l[ty][tx] = de->l[y][x];
        }
        marcar(para, ty, 0, para->colunas - 1);
    }
    return OK;
}

int touchwin(WINDOW *w)
{
    for (int y = 0; y < w->linhas; y++)
        marcar(w, y, 0, w->colunas - 1);
    return OK;
}

int clearok(WINDOW *w, bool sim)
{
    w->limpar = sim;
    return OK;
}

int wmove(WINDOW *w, int y, int x)
{
    if (y < 0 || y >= w->linhas || x < 0 || x >= w->colunas)
        return ERR;
    w->cy = y;
    w->cx = x;
    return OK;
}

int waddch(WINDOW *w, chtype c)
{
    unsigned char ch = (unsigned char)(c & A_CHARTEXT);
    if (ch == '\n')
    {
        wclrtoeol(w);
        if (w->cy + 1 < w->linhas)
            w->cy++;
        w->cx = 0;
        return OK;
    }
    if (ch == '\r')
    {
        w->cx = 0;
        return OK;
    }
    if (ch == '\b')
    {
        if (w->cx > 0)
            w->cx--;
        return OK;
    }
    if (ch == '\t')
    {
        do
            waddch(w, ' ');
        while (w->cx % 8 != 0 && w->cx != 0);
        return OK;
    }
    if (ch < 32 || ch == 127)
    {
        /* controle aparece como ^X, como na curses */
        const char *u = unctrl(ch);
        while (*u)
            waddch(w, (chtype)(unsigned char)*u++ | (c & ~A_CHARTEXT));
        return OK;
    }
    w->l[w->cy][w->cx] = ch | ((c | w->atributo) & A_STANDOUT);
    marcar(w, w->cy, w->cx, w->cx);
    if (++w->cx >= w->colunas)
    {
        w->cx = 0;
        if (w->cy + 1 < w->linhas)
            w->cy++;
        else
        {
            w->cx = w->colunas - 1;   /* sem rolar: fica no canto, como o scrollok desligado */
            return ERR;
        }
    }
    return OK;
}

int waddstr(WINDOW *w, const char *s)
{
    while (*s)
        if (waddch(w, (unsigned char)*s++) == ERR)
            return ERR;
    return OK;
}

static int vw(WINDOW *w, const char *fmt, va_list a)
{
    char b[1024];
    vsnprintf(b, sizeof(b), fmt, a);
    return waddstr(w, b);
}

int wprintw(WINDOW *w, const char *fmt, ...)
{
    va_list a;
    va_start(a, fmt);
    int r = vw(w, fmt, a);
    va_end(a);
    return r;
}

int mvwprintw(WINDOW *w, int y, int x, const char *fmt, ...)
{
    if (wmove(w, y, x) == ERR)
        return ERR;
    va_list a;
    va_start(a, fmt);
    int r = vw(w, fmt, a);
    va_end(a);
    return r;
}

int printw(const char *fmt, ...)
{
    va_list a;
    va_start(a, fmt);
    int r = vw(stdscr, fmt, a);
    va_end(a);
    return r;
}

int mvprintw(int y, int x, const char *fmt, ...)
{
    if (wmove(stdscr, y, x) == ERR)
        return ERR;
    va_list a;
    va_start(a, fmt);
    int r = vw(stdscr, fmt, a);
    va_end(a);
    return r;
}

int werase(WINDOW *w)
{
    for (int y = 0; y < w->linhas; y++)
    {
        for (int x = 0; x < w->colunas; x++)
            w->l[y][x] = ' ';
        marcar(w, y, 0, w->colunas - 1);
    }
    w->cy = w->cx = 0;
    return OK;
}

int wclear(WINDOW *w)
{
    werase(w);
    w->limpar = true;
    return OK;
}

int wclrtoeol(WINDOW *w)
{
    for (int x = w->cx; x < w->colunas; x++)
        w->l[w->cy][x] = ' ';
    marcar(w, w->cy, w->cx, w->colunas - 1);
    return OK;
}

int wclrtobot(WINDOW *w)
{
    wclrtoeol(w);
    for (int y = w->cy + 1; y < w->linhas; y++)
    {
        for (int x = 0; x < w->colunas; x++)
            w->l[y][x] = ' ';
        marcar(w, y, 0, w->colunas - 1);
    }
    return OK;
}

int wstandout(WINDOW *w)
{
    w->atributo = A_STANDOUT;
    return OK;
}

int wstandend(WINDOW *w)
{
    w->atributo = 0;
    return OK;
}

chtype winch(WINDOW *w)
{
    return w->l[w->cy][w->cx];
}

int wrefresh(WINDOW *w)
{
    if (curscr == NULL)
        return ERR;
    if (w == curscr)
    {
        /* wrefresh(curscr) = redesenhar a tela inteira como ela esta */
        curscr->limpar = true;
        m17v_mostrar(curscr);
        return OK;
    }
    if (w->limpar)
    {
        werase(curscr);
        curscr->limpar = true;
        touchwin(w);
        w->limpar = false;
    }
    for (int y = 0; y < w->linhas; y++)
    {
        if (w->mudou_ini[y] < 0)
            continue;
        int ty = y + w->y0;
        for (int x = w->mudou_ini[y]; x <= w->mudou_fim[y] && x < w->colunas; x++)
        {
            int tx = x + w->x0;
            if (ty >= 0 && ty < LINES && tx >= 0 && tx < COLS && curscr->l[ty][tx] != w->l[y][x])
            {
                curscr->l[ty][tx] = w->l[y][x];
                marcar(curscr, ty, tx, tx);
            }
        }
        w->mudou_ini[y] = w->mudou_fim[y] = -1;
    }
    curscr->cy = w->y0 + w->cy;
    curscr->cx = w->x0 + w->cx;
    m17v_mostrar(curscr);
    return OK;
}

int wgetch(WINDOW *w)
{
    wrefresh(w);
    return m17_tecla();
}

int wgetnstr(WINDOW *w, char *s, int n)
{
    /* so o "[Press return to continue]" do fim usa: espera confirmar ou voltar e devolve vazio */
    (void)n;
    wrefresh(w);
    for (;;)
    {
        int c = m17_tecla();
        if (c == '\n' || c == '\r' || c == 27 || c == ' ')
            break;
    }
    s[0] = '\0';
    return OK;
}

int raw(void) { return OK; }
int noraw(void) { return OK; }
int cbreak(void) { return OK; }
int nocbreak(void) { return OK; }
int echo(void) { return OK; }
int noecho(void) { return OK; }
int nl(void) { return OK; }
int nonl(void) { return OK; }
int halfdelay(int decimos) { (void)decimos; return OK; }
int keypad(WINDOW *w, bool sim) { (void)w; (void)sim; return OK; }
int idlok(WINDOW *w, bool sim) { (void)w; (void)sim; return OK; }
int leaveok(WINDOW *w, bool sim) { (void)w; (void)sim; return OK; }
int scrollok(WINDOW *w, bool sim) { (void)w; (void)sim; return OK; }
int typeahead(int fd) { (void)fd; return OK; }
int flushinp(void) { return OK; }
int baudrate(void) { return 38400; }
int mvcur(int ya, int xa, int y, int x) { (void)ya; (void)xa; (void)y; (void)x; return OK; }
char erasechar(void) { return '\b'; }
char killchar(void) { return 21; /* Ctrl+U */ }

const char *unctrl(chtype c)
{
    static char b[3];
    unsigned char ch = (unsigned char)(c & A_CHARTEXT);
    if (ch < 32)
    {
        b[0] = '^';
        b[1] = (char)(ch + '@');
        b[2] = '\0';
    }
    else if (ch == 127)
    {
        b[0] = '^';
        b[1] = '?';
        b[2] = '\0';
    }
    else
    {
        b[0] = (char)ch;
        b[1] = '\0';
    }
    return b;
}
