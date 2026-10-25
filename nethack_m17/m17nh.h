/* m17nh.h — a interface m17 do NetHack no M17 (spec 036): o que os arquivos da camada dividem. */
#ifndef M17NH_H
#define M17NH_H

#ifndef M17NH_TESTE
#include "SDL.h"
#endif
#include "m17entrada.h"

/* --- video (m17nh_video.c): tela 80x24 de celulas {caractere, cor 0-15, inverso} desenhada com a fonte 6x10 da
 * spec 035 numa celula 6x11; M17_TELA=<arq.bmp> e M17_TELA_TXT=<arq> gravam a ultima tela (testes) --- */
#define M17NH_COLUNAS 80
#define M17NH_LINHAS 24
void m17v_iniciar(void);
#ifndef M17NH_TESTE
SDL_Renderer *m17v_renderer(void);
#endif
void m17v_celula(int y, int x, unsigned char c, int cor, int inverso);
void m17v_limpar(void);
void m17v_cursor(int y, int x);           /* cursor visivel (-1 = nenhum) */
void m17v_mostrar(void);                  /* apresenta, se algo mudou */
unsigned char m17v_char(int y, int x);    /* o que esta na tela (testes e caixas por cima) */
void m17v_redesenhar(void);               /* tudo de novo (depois do teclado virtual, que desenha por cima) */
void m17v_fundo(void *ctx);               /* a tela no renderer, sem apresentar (o fundo da roda, spec 048) */

/* --- entrada (m17nh_entrada.c) --- */
#define M17NH_R3 0x200   /* codigo do R3 (spec 048): abre a roda de opcoes (indice M17_R3, padrao 2) */
enum { M17NH_MAPA, M17NH_POSICAO, M17NH_PERGUNTA, M17NH_LISTA, M17NH_TEXTO, M17NH_MAIS };
/* traducao pura: codigo do m17e_passo (direcao 'h'..'n'/maiuscula ou M17E_*) -> tecla do NetHack no contexto;
 * na_escada: '<' ou '>' quando o heroi esta numa escada no mapa (0 = nao). Devolve a tecla, 0 = nada,
 * -1 = menu de comandos, -2 = menu do jogo, -4 = roda de opcoes (R3, spec 048). */
int m17nh_traduzir(int codigo, int contexto, int na_escada);
/* o proximo evento (bloqueia): tecla (> 0), ou 0 com *codigo = codigo do controle, ou -3 = pedido de saida */
int m17nh_ler(int *codigo);
void m17nh_iniciar_entrada(void);
int m17nh_parar(void);   /* (winm17.c) 1 = o jogo recebeu o hangup (SIGTERM): parar de esperar tecla */

#endif
