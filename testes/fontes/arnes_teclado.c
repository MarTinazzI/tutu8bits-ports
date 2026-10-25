// Arnes do teclado virtual (spec 036, T01; CA-02): a parte pura do teclado.c, compilada com o gcc do PC e -DM17T_TESTE
// (sem SDL). As sequencias de botoes sao texto: ^ v < > = direcoes, A B X Y, [ ] = L1 R1, { } = L2 R2, S = START,
// s = SELECT.
#include "teclado.h"

#include <stdio.h>
#include <string.h>

static int falhas = 0;

static int botao(char c)
{
	switch (c)
	{
	case '^': return M17T_CIMA;
	case 'v': return M17T_BAIXO;
	case '<': return M17T_ESQUERDA;
	case '>': return M17T_DIREITA;
	case 'A': return M17T_A;
	case 'B': return M17T_B;
	case 'X': return M17T_X;
	case 'Y': return M17T_Y;
	case '[': return M17T_L1;
	case ']': return M17T_R1;
	case '{': return M17T_L2;
	case '}': return M17T_R2;
	case 'S': return M17T_START;
	case 's': return M17T_SELECT;
	default: return 0;
	}
}

// roda a sequencia; devolve o resultado do ultimo passo que nao foi SEGUE (ou SEGUE)
static int rodar(M17T *t, const char *seq)
{
	int r = M17T_SEGUE;
	for (; *seq; seq++)
	{
		r = teclado_passo(t, botao(*seq));
		if (r != M17T_SEGUE)
			break;
	}
	return r;
}

static void caso(const char *o, const char *inicial, int max, const char *seq, int r_esp,
                 const char *texto_esp, int cursor_esp)
{
	M17T t;
	teclado_iniciar(&t, inicial, max);
	int r = rodar(&t, seq);
	int ok = r == r_esp && strcmp(t.texto, texto_esp) == 0 && (cursor_esp < 0 || t.cursor == cursor_esp)
	         && (int)strlen(t.texto) == t.tam;
	printf("%s %s: r=%d texto=[%s] cursor=%d%s", ok ? "ok   " : "FALHA", o, r, t.texto, t.cursor, ok ? "\n" : "");
	if (!ok)
		printf(" (esperado r=%d [%s] cursor=%d)\n", r_esp, texto_esp, cursor_esp);
	falhas += !ok;
}

int main(void)
{
	// A na 1a tecla = "A"; andar pela grade; maiusculas ligadas no inicio
	caso("primeira tecla", "", 20, "AS", M17T_OK, "A", 1);
	caso("direita e baixo", "", 20, ">>vAS", M17T_OK, "M", 1);   // linha 1, coluna 2 = M
	caso("volta pela borda (esquerda na coluna 0 = coluna 9)", "", 20, "<AS", M17T_OK, "J", 1);
	caso("volta pela borda (cima na linha 0 = linha 3)", "", 20, "^AS", M17T_OK, "0", 1);
	caso("X troca para minusculas e de volta", "", 20, "XAXAS", M17T_OK, "aA", 2);
	caso("minusculas nao mexem nos simbolos", "", 20, "Xvv>>>>>>AS", M17T_OK, ".", 1);   // linha 2 col 6 = '.'
	caso("Y = espaco", "Ana", 20, "YAS", M17T_OK, "Ana A", 5);
	caso("B apaga antes do cursor", "Elbereth", 20, "BBS", M17T_OK, "Elbere", 6);
	caso("B no inicio nao faz nada", "ab", 20, "[[BS", M17T_OK, "ab", 0);
	caso("L1/R1 movem o cursor; A insere no meio", "ac", 20, "[>AS", M17T_OK, "aBc", 2);
	caso("R1 no fim nao passa do fim", "ab", 20, "]]]AS", M17T_OK, "abA", 3);
	caso("pagina 2 pelo R2 (algarismo)", "", 20, "}AS", M17T_OK, "0", 1);
	caso("pagina 2 simbolo e volta pelo L2", "", 20, "}v>A{AS", M17T_OK, "?L", 2);   // p2 l1 c1 = '?'; p1 l1 c1 = L
	caso("maximo respeitado", "abcd", 5, "AAAS", M17T_OK, "abcdA", 5);
	caso("texto inicial cortado no maximo", "abcdefgh", 4, "S", M17T_OK, "abcd", 4);
	caso("caractere de fora vira espaco", "a\tb", 10, "S", M17T_OK, "a b", 3);
	caso("SELECT cancela", "abc", 10, "AAs", M17T_CANCELA, "abcAA", 5);
	caso("botao desconhecido nao faz nada", "abc", 10, "?S", M17T_OK, "abc", 3);

	// a grade inteira: so ASCII imprimivel, nenhuma tecla vazia na pagina 0
	M17T t;
	teclado_iniciar(&t, "", 10);
	int ok = 1;
	for (int p = 0; p < M17T_PAGINAS; p++)
		for (int l = 0; l < M17T_LINHAS; l++)
			for (int c = 0; c < M17T_COLUNAS; c++)
			{
				char k = teclado_tecla(&t, p, l, c);
				if (k < 33 || k > 126)
					ok = 0;
			}
	printf("%s grade: 80 teclas, todas ASCII imprimivel (sem vazias)\n", ok ? "ok   " : "FALHA");
	falhas += !ok;

	printf("falhas: %d\n", falhas);
	return falhas != 0;
}
