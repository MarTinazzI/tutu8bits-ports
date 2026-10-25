// Arnes da traducao botao -> tecla do NetHack (spec 036, T07; plano D-08, D-09, D-12): a parte pura do
// m17nh_entrada.c, compilada com o gcc do PC e -DM17NH_TESTE (sem SDL).
#include "m17nh.h"

#include <stdio.h>

static int falhas = 0;

static void caso(const char *o, int obtido, int esperado)
{
	int ok = obtido == esperado;
	printf("%s %s: %d%s", ok ? "ok   " : "FALHA", o, obtido, ok ? "\n" : "");
	if (!ok)
		printf(" (esperado %d)\n", esperado);
	falhas += !ok;
}

int main(void)
{
	// mapa (D-12, spec §8)
	caso("mapa: direcao k", m17nh_traduzir('k', M17NH_MAPA, 0), 'k');
	caso("mapa: B segurado + direcao = correr (maiuscula)", m17nh_traduzir('Y', M17NH_MAPA, 0), 'Y');
	caso("mapa: A sem escada = pegar", m17nh_traduzir(M17E_A, M17NH_MAPA, 0), ',');
	caso("mapa: A na escada de descer", m17nh_traduzir(M17E_A, M17NH_MAPA, '>'), '>');
	caso("mapa: A na escada de subir", m17nh_traduzir(M17E_A, M17NH_MAPA, '<'), '<');
	caso("mapa: B = Esc", m17nh_traduzir(M17E_B, M17NH_MAPA, 0), 27);
	caso("mapa: X = inventario", m17nh_traduzir(M17E_X, M17NH_MAPA, 0), 'i');
	caso("mapa: Y = procurar", m17nh_traduzir(M17E_Y, M17NH_MAPA, 0), 's');
	caso("mapa: L1 = descansar", m17nh_traduzir(M17E_L1, M17NH_MAPA, 0), '.');
	caso("mapa: L2 = mensagens anteriores (^P)", m17nh_traduzir(M17E_L2, M17NH_MAPA, 0), 16);
	caso("mapa: R2 = repetir (^A)", m17nh_traduzir(M17E_R2, M17NH_MAPA, 0), 1);
	caso("mapa: SELECT = menu de comandos", m17nh_traduzir(M17E_SELECT, M17NH_MAPA, 0), -1);
	caso("mapa: START = menu do jogo", m17nh_traduzir(M17E_START, M17NH_MAPA, 0), -2);
	caso("mapa: R3 = roda de opcoes (spec 048)", m17nh_traduzir(M17NH_R3, M17NH_MAPA, 0), -4);
	caso("lista: R3 nao faz nada", m17nh_traduzir(M17NH_R3, M17NH_LISTA, 0), 0);
	// posicao no mapa (getpos, D-09)
	caso("posicao: direcao move o cursor", m17nh_traduzir('n', M17NH_POSICAO, 0), 'n');
	caso("posicao: B segurado + direcao = passo de 8", m17nh_traduzir('L', M17NH_POSICAO, 0), 'L');
	caso("posicao: A escolhe (.)", m17nh_traduzir(M17E_A, M17NH_POSICAO, 0), '.');
	caso("posicao: B = Esc", m17nh_traduzir(M17E_B, M17NH_POSICAO, 0), 27);
	caso("posicao: L1 = escada <", m17nh_traduzir(M17E_L1, M17NH_POSICAO, 0), '<');
	caso("posicao: L2 = escada >", m17nh_traduzir(M17E_L2, M17NH_POSICAO, 0), '>');
	caso("posicao: X = proximo monstro (m)", m17nh_traduzir(M17E_X, M17NH_POSICAO, 0), 'm');
	caso("posicao: Y = monstro anterior (M)", m17nh_traduzir(M17E_Y, M17NH_POSICAO, 0), 'M');
	caso("posicao: R2 = si mesmo (@)", m17nh_traduzir(M17E_R2, M17NH_POSICAO, 0), '@');
	// pergunta de direcao (D-08)
	caso("direcao: maiuscula vira minuscula", m17nh_traduzir('J', M17NH_PERGUNTA, 0), 'j');
	caso("direcao: A = em si (.)", m17nh_traduzir(M17E_A, M17NH_PERGUNTA, 0), '.');
	caso("direcao: L1/L2 = < >", m17nh_traduzir(M17E_L1, M17NH_PERGUNTA, 0) * 1000 + m17nh_traduzir(M17E_L2, M17NH_PERGUNTA, 0), '<' * 1000 + '>');
	caso("direcao: X nao faz nada", m17nh_traduzir(M17E_X, M17NH_PERGUNTA, 0), 0);
	// --More--
	caso("mais: A segue", m17nh_traduzir(M17E_A, M17NH_MAIS, 0), '\n');
	caso("mais: B pula (Esc)", m17nh_traduzir(M17E_B, M17NH_MAIS, 0), 27);
	caso("mais: direcao nao segue (nao pular mensagem sem querer)", m17nh_traduzir('k', M17NH_MAIS, 0), 0);
	printf("falhas: %d\n", falhas);
	return falhas != 0;
}
