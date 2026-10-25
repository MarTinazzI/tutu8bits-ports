// Arnes do m17_nomes.c do OpenTyrian (spec 034, T03/T05): compilado com o gcc do PC e -DM17_NOMES_TESTE (sem SDL).
// Uso: arnes_m17_nomes <pasta temporaria>. Imprime "ok"/"FALHA" por caso e sai com o numero de falhas.
#include "m17_nomes.h"

#include <stdio.h>
#include <string.h>

static int falhas = 0;
static void conta(int ok, const char *o)
{
	printf("%s %s\n", ok ? "ok   " : "FALHA", o);
	falhas += !ok;
}
static void escreve(const char *arq, const char *txt)
{
	FILE *f = fopen(arq, "w");
	fputs(txt, f);
	fclose(f);
}
static int sem_o(unsigned char c) { return c != 'o'; }

int main(int argc, char **argv)
{
	char arq[512], nomes[M17_NOMES_MAX][M17_NOME_TAM], dst[64];
	snprintf(arq, sizeof(arq), "%s/nomes.txt", argc > 1 ? argv[1] : ".");

	escreve(arq, "Tutu\r\n  Martinazzi  \n\nDinheiro\n");
	int n = m17_nomes_ler(arq, nomes, M17_NOMES_MAX);
	conta(n == 3 && !strcmp(nomes[0], "Tutu") && !strcmp(nomes[1], "Martinazzi") && !strcmp(nomes[2], "Dinheiro"),
	      "lista valida: 3 nomes, sem \\r, sem espacos nas pontas, linha vazia ignorada");

	escreve(arq, "");
	conta(m17_nomes_ler(arq, nomes, M17_NOMES_MAX) == 0, "lista vazia: 0 nomes");
	conta(m17_nomes_ler("/nao/existe/nomes.txt", nomes, M17_NOMES_MAX) == 0, "lista ausente: 0 nomes");
	conta(m17_nomes_ler(NULL, nomes, M17_NOMES_MAX) == 0, "sem M17_NOMES: 0 nomes");

	escreve(arq, "Jos\xc3\xa9\n\x01lixo\nBom\n\t\n");
	n = m17_nomes_ler(arq, nomes, M17_NOMES_MAX);
	conta(n == 1 && !strcmp(nomes[0], "Bom"), "lista com lixo: so as linhas em ASCII imprimivel ficam");

	size_t t = m17_nome_escolher(nomes, 0, NULL, dst, 14, NULL);
	conta(t == 4 && !memcmp(dst, "Tutu", 4), "sem nomes: Tutu");

	escreve(arq, "Nome Comprido Demais Para O Campo\n");
	n = m17_nomes_ler(arq, nomes, M17_NOMES_MAX);
	t = m17_nome_escolher(nomes, n, NULL, dst, 14, NULL);
	conta(t == 14 && !memcmp(dst, "Nome Comprido ", 14), "corte em 14 (campo do save)");

	escreve(arq, "Tutu\nMartinazzi\nDinheiro\n");
	n = m17_nomes_ler(arq, nomes, M17_NOMES_MAX);
	int dentro = 1, diferente = 1;
	for (int i = 0; i < 300; i++)
	{
		char atual[M17_NOME_TAM];
		snprintf(atual, sizeof(atual), "%s", nomes[i % 3]);
		memset(dst, 0, sizeof(dst));
		t = m17_nome_escolher(nomes, n, atual, dst, 28, NULL);
		dst[t] = '\0';
		if (strcmp(dst, "Tutu") && strcmp(dst, "Martinazzi") && strcmp(dst, "Dinheiro"))
			dentro = 0;
		if (!strcmp(dst, atual))
			diferente = 0;
	}
	conta(dentro, "sorteio sempre dentro da lista (300x)");
	conta(diferente, "sorteio: o novo nome e diferente do atual quando ha 2+ (300x)");

	escreve(arq, "Solo\n");
	n = m17_nomes_ler(arq, nomes, M17_NOMES_MAX);
	t = m17_nome_escolher(nomes, n, "Solo", dst, 28, NULL);
	conta(t == 4 && !memcmp(dst, "Solo", 4), "lista de 1: repete o unico nome");

	t = m17_nome_escolher(nomes, n, NULL, dst, 28, sem_o);
	conta(t == 4 && !memcmp(dst, "S l ", 4), "caractere que a fonte do jogo nao desenha vira espaco");

	printf("falhas: %d\n", falhas);
	return falhas;
}
