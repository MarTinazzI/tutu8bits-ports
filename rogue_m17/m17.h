/* m17.h — a camada do Rogue no M17 (spec 035): o que os arquivos da camada e os ganchos no jogo dividem. */
#ifndef M17_H
#define M17_H

#include "SDL.h"
#include <stdbool.h>

#include "m17entrada.h"

/* --- contexto: que pergunta o jogo esta fazendo (ganchos do patch rogue-m17-01; plano D-05). Os valores M17_* estao
 * no m17entrada.h (a traducao e pura). --- */
void m17_contexto(int c);
void m17_contexto_mais(int esperado);   /* MAIS: o --More-- / wait_for espera esta tecla */
void m17_contexto_item(int tipo);   /* ITEM, com o tipo de objeto que o get_item filtra (0 = qualquer) */
int m17_contexto_atual(void);

/* --- video (m17video.c) --- */
void m17v_iniciar(void);
void m17v_celula(Uint16 *p, int y, int x, unsigned char c, bool inverso, Uint16 frente, Uint16 fundo);
void m17v_apresentar(void);

/* --- entrada (m17entrada.c) --- */
void m17e_iniciar_joystick(void);

void m17_enfileirar(const char *s);   /* teclas que vao ao jogo nas proximas leituras (menus: "?*") */

/* --- menus por cima (m17menus.c; plano D-07) --- */
bool m17m_ativo(void);
void m17m_desenhar(Uint16 *p);
void m17m_abrir_comandos(void);   /* SELECT */
void m17m_abrir_jogo(void);       /* START */
void m17m_abrir_seletor(int tipo);   /* "qual objeto?" */
/* um codigo (direcao/M17E_*) com o menu aberto: > 0 = tecla para o jogo (o resto da sequencia vai para a fila),
 * 0 = nada (continua aberto ou abriu outro), -1 = fechou sem escolher */
int m17m_navegar(int codigo);

/* --- ponte com o jogo (m17_ponte.c, compilado com os cabecalhos do Rogue; plano D-06) --- */
bool m17_heroi_na_escada(void);
/* itens da mochila do tipo pedido (0 = todos): letra e nome, ate max; devolve quantos */
int m17_itens(int tipo, char *letras, char nomes[][64], int max);
void m17_salvar_e_sair(void);   /* o auto_save do jogo (grava e sai com 0) */

#endif
