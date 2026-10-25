/* curses.h do Rogue no M17 (spec 035, plano D-02): so o que o Rogue 5.4.4 usa (inventario do fonte, T01/T02).
 * A tela e uma matriz na memoria (caractere + video inverso); o desenho sai pelo m17video.c (SDL2) e a entrada pelo
 * m17_tecla() (teclado do SDL, M17_ROTEIRO nos testes e, desde a T05, o controle do aparelho).
 * Semantica de curses classica: cada janela marca o que mudou; wrefresh copia so o que mudou para a tela (curscr);
 * touchwin marca tudo; uma subjanela compartilha as linhas da mae. */
#ifndef M17_CURSES_H
#define M17_CURSES_H

#include <stdarg.h>
#include <stdio.h>   /* a curses de verdade inclui (o Rogue conta com o FILE) */
#include <stdbool.h>

#ifndef TRUE
#define TRUE 1
#endif
#ifndef FALSE
#define FALSE 0
#endif
#define ERR (-1)
#define OK 0

typedef unsigned int chtype;
#define A_CHARTEXT 0x000000ffu
#define A_STANDOUT 0x00010000u
#define A_REVERSE A_STANDOUT

/* teclas especiais: o mdport.c do Rogue as nomeia (traducao de teclado numerico); a nossa entrada so devolve ASCII.
 * Valores distintos entre si e dos codigos crus que o mdport.c tambem trata (511..519). */
#define KEY_DOWN 0402
#define KEY_UP 0403
#define KEY_LEFT 0404
#define KEY_RIGHT 0405
#define KEY_HOME 0406
#define KEY_BACKSPACE 0407
#define KEY_NPAGE 0522
#define KEY_PPAGE 0523
#define KEY_EOL 0517
#define KEY_LL 0533
#define KEY_A1 0534
#define KEY_A2 0x1100
#define KEY_A3 0535
#define KEY_B1 0x1101
#define KEY_B2 0536
#define KEY_B3 0x1102
#define KEY_C1 0537
#define KEY_C2 0x1103
#define KEY_C3 0540
#define KEY_END 0550
#define KEY_SEND 0602
#define KEY_SHOME 0607
#define KEY_SLEFT 0611
#define KEY_SNEXT 0616
#define KEY_SPREVIOUS 0620
#define KEY_SRIGHT 0622
#define KEY_SUP 0x1104
#define KEY_SDOWN 0x1105
#define KEY_SNEXTE 0x1106

typedef struct m17_janela
{
    int linhas, colunas;      /* tamanho */
    int y0, x0;               /* posicao na tela */
    int cy, cx;               /* cursor */
    chtype atributo;          /* A_STANDOUT ligado ou nao */
    chtype **l;               /* linhas (numa subjanela, apontam para dentro das linhas da mae) */
    int *mudou_ini, *mudou_fim; /* colunas mudadas por linha desde o ultimo wrefresh (-1 = nenhuma) */
    struct m17_janela *mae;   /* subjanela: a mae (NULL nas outras) */
    int dy, dx;               /* subjanela: deslocamento dentro da mae (fixo desde o subwin) */
    bool limpar;              /* clearok: o proximo wrefresh redesenha a tela inteira */
} WINDOW;

extern WINDOW *stdscr, *curscr;
extern int LINES, COLS, ESCDELAY;

/* inicio e fim */
WINDOW *initscr(void);
int endwin(void);
bool isendwin(void);

/* janelas */
WINDOW *newwin(int linhas, int colunas, int y0, int x0);
WINDOW *subwin(WINDOW *mae, int linhas, int colunas, int y0, int x0);
int delwin(WINDOW *w);
int mvwin(WINDOW *w, int y0, int x0);
int overwrite(const WINDOW *de, WINDOW *para);
int touchwin(WINDOW *w);
int clearok(WINDOW *w, bool sim);

/* escrita */
int wmove(WINDOW *w, int y, int x);
int waddch(WINDOW *w, chtype c);
int waddstr(WINDOW *w, const char *s);
int wprintw(WINDOW *w, const char *fmt, ...);
int mvwprintw(WINDOW *w, int y, int x, const char *fmt, ...);
int printw(const char *fmt, ...);
int mvprintw(int y, int x, const char *fmt, ...);
int wclear(WINDOW *w);
int werase(WINDOW *w);
int wclrtoeol(WINDOW *w);
int wclrtobot(WINDOW *w);
int wstandout(WINDOW *w);
int wstandend(WINDOW *w);
chtype winch(WINDOW *w);
int wrefresh(WINDOW *w);
int wgetch(WINDOW *w);
int wgetnstr(WINDOW *w, char *s, int n);

#define move(y, x) wmove(stdscr, (y), (x))
#define addch(c) waddch(stdscr, (c))
#define addstr(s) waddstr(stdscr, (s))
#define clear() wclear(stdscr)
#define erase() werase(stdscr)
#define clrtoeol() wclrtoeol(stdscr)
#define clrtobot() wclrtobot(stdscr)
#define standout() wstandout(stdscr)
#define standend() wstandend(stdscr)
#define inch() winch(stdscr)
#define refresh() wrefresh(stdscr)
#define getch() wgetch(stdscr)
#define mvaddch(y, x, c) (wmove(stdscr, (y), (x)) == ERR ? ERR : waddch(stdscr, (c)))
#define mvaddstr(y, x, s) (wmove(stdscr, (y), (x)) == ERR ? ERR : waddstr(stdscr, (s)))
#define mvinch(y, x) (wmove(stdscr, (y), (x)) == ERR ? (chtype)ERR : winch(stdscr))
#define mvwaddch(w, y, x, c) (wmove((w), (y), (x)) == ERR ? ERR : waddch((w), (c)))
#define mvwaddstr(w, y, x, s) (wmove((w), (y), (x)) == ERR ? ERR : waddstr((w), (s)))
#define mvwinch(w, y, x) (wmove((w), (y), (x)) == ERR ? (chtype)ERR : winch(w))
#define getyx(w, y, x) ((y) = (w)->cy, (x) = (w)->cx)
#define getmaxy(w) ((w)->linhas)
#define getmaxx(w) ((w)->colunas)

/* o md_hasclreol do mdport.c pergunta se o terminal limpa ate o fim da linha: limpa */
#define clr_eol "\033[K"

/* modos do terminal: nao ha terminal; ficam como nada */
int raw(void);
int noraw(void);
int cbreak(void);
int nocbreak(void);
int echo(void);
int noecho(void);
int nl(void);
int nonl(void);
int halfdelay(int decimos);
int keypad(WINDOW *w, bool sim);
int idlok(WINDOW *w, bool sim);
int leaveok(WINDOW *w, bool sim);
int scrollok(WINDOW *w, bool sim);
int typeahead(int fd);
int flushinp(void);
int baudrate(void);
int mvcur(int ya, int xa, int y, int x);
char erasechar(void);
char killchar(void);
const char *unctrl(chtype c);
#define crmode() cbreak()
#define nocrmode() nocbreak()

/* --- M17: ponte com o video e a entrada (m17video.c / m17entrada.c) --- */
#include "m17entrada.h"   /* M17_NADA, M17_ITEM... (os ganchos do patch rogue-m17-01 usam) */
void m17_contexto(int c);
void m17_contexto_item(int tipo);
void m17_contexto_mais(int esperado);
extern int m17_partida_encerrada;   /* o placar comecou: o save automatico so sai */
/* desenha a tela (curscr) se algo mudou */
void m17v_mostrar(const WINDOW *tela);
/* proxima tecla (ASCII): roteiro de teste, teclado do SDL e controle; bloqueia esperando eventos */
int m17_tecla(void);

#endif
