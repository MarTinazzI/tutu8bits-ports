// Arnes da entrada do Rogue no M17 (spec 035, T05; CA-02, CA-08): a parte pura do m17entrada.c, compilada com o gcc
// do PC e -DM17E_TESTE (sem SDL), com tempos simulados. Uso: arnes_m17entrada <pasta temporaria>.
#include "m17entrada.h"

#include <stdio.h>
#include <string.h>

static int falhas = 0;
static void conta(int ok, const char *o)
{
	printf("%s %s\n", ok ? "ok   " : "FALHA", o);
	falhas += !ok;
}

#define B(i) (1u << (i))
static M17E_Config cfg;

// roda de t0 a t1 (passo de 10 ms) com os botoes/eixos fixos; junta as saidas como texto ("k@60 k@310")
static void rodar(M17E_Estado *e, unsigned bot, int ax, int ay, unsigned t0, unsigned t1, char *out)
{
	for (unsigned t = t0; t <= t1; t += 10)
	{
		M17E_Entrada in = { bot, ax, ay, t };
		int r;
		while ((r = m17e_passo(e, &cfg, &in)) != 0)
		{
			char b[32];
			if (r < 0x100)
				snprintf(b, sizeof(b), "%s%c@%u", *out ? " " : "", r, t);
			else
				snprintf(b, sizeof(b), "%s#%d@%u", *out ? " " : "", r - 0x100, t);
			strcat(out, b);
		}
	}
}

static void caso(const char *nome, const char *esperado, const char *obtido)
{
	char o[512];
	snprintf(o, sizeof(o), "%s: [%s]%s%s%s", nome, obtido, strcmp(esperado, obtido) ? " esperado [" : "",
	         strcmp(esperado, obtido) ? esperado : "", strcmp(esperado, obtido) ? "]" : "");
	conta(!strcmp(esperado, obtido), o);
}

int main(int argc, char **argv)
{
	m17e_config_padrao(&cfg);
	char out[512];
	M17E_Estado e;

	// retas, acorde, repeticao
	memset(&e, 0, sizeof(e)); out[0] = 0;
	rodar(&e, B(M17B_CIMA), 0, 0, 0, 540, out);
	caso("cima segurado: 1a letra no fim do acorde (60), repete aos 250 e a cada 110", "k@60 k@310 k@420 k@530", out);

	memset(&e, 0, sizeof(e)); out[0] = 0;
	rodar(&e, B(M17B_CIMA), 0, 0, 0, 20, out);
	rodar(&e, B(M17B_CIMA) | B(M17B_DIREITA), 0, 0, 30, 30, out);
	caso("acorde: cima e direita a 30 ms um do outro = cima-direita na hora", "u@30", out);

	memset(&e, 0, sizeof(e)); out[0] = 0;
	rodar(&e, B(M17B_CIMA), 0, 0, 0, 100, out);
	rodar(&e, B(M17B_CIMA) | B(M17B_DIREITA), 0, 0, 110, 320, out);
	caso("fora do acorde: sai a reta; a 2a seta troca a letra na repeticao, sem reiniciar o atraso", "k@60 u@310", out);

	memset(&e, 0, sizeof(e)); out[0] = 0;
	rodar(&e, B(M17B_BAIXO), 0, 0, 0, 30, out);
	rodar(&e, 0, 0, 0, 40, 100, out);
	caso("toque mais curto que o acorde nao anda (soltou antes dos 60 ms)", "", out);

	// analogico em 8 setores
	struct { int ax, ay; const char *l; } S[] = {
		{ 32767, 0, "l" }, { -32767, 0, "h" }, { 0, -32767, "k" }, { 0, 32767, "j" },
		{ 23170, -23170, "u" }, { -23170, -23170, "y" }, { 23170, 23170, "n" }, { -23170, 23170, "b" },
		{ 30000, 10000, "l" }, { 10000, 30000, "j" },   // 18,4 e 71,6 graus: ainda l e j
	};
	int ok = 1;
	char lista[128] = "";
	for (size_t i = 0; i < sizeof(S) / sizeof(S[0]); i++)
	{
		memset(&e, 0, sizeof(e)); out[0] = 0;
		rodar(&e, 0, S[i].ax, S[i].ay, 0, 60, out);
		if (out[0] != S[i].l[0])
			ok = 0;
		char b[8];
		snprintf(b, sizeof(b), "%c", out[0] ? out[0] : '-');
		strcat(lista, b);
	}
	char o[256];
	snprintf(o, sizeof(o), "analogico: 8 setores de 45 graus (l h k j u y n b l j) [%s]", lista);
	conta(ok, o);

	memset(&e, 0, sizeof(e)); out[0] = 0;
	rodar(&e, 0, 8000, 8000, 0, 300, out);
	caso("analogico dentro da zona morta (12000): nada", "", out);

	memset(&e, 0, sizeof(e)); out[0] = 0;
	rodar(&e, B(M17B_ESQUERDA), 32767, 0, 0, 60, out);
	caso("D-pad vale mais que o analogico (esquerda no D-pad, direita no analogico)", "h@60", out);

	// R1 gira 45 graus
	unsigned dirs[4] = { B(M17B_CIMA), B(M17B_DIREITA), B(M17B_BAIXO), B(M17B_ESQUERDA) };
	lista[0] = 0;
	for (int i = 0; i < 4; i++)
	{
		memset(&e, 0, sizeof(e)); out[0] = 0;
		rodar(&e, dirs[i] | B(M17B_R1), 0, 0, 0, 0, out);
		strcat(lista, out[0] ? (char[2]){ out[0], 0 } : "-");
	}
	caso("R1 segurado gira 45 graus, na hora (cima direita baixo esquerda -> u n b y)", "unby", lista);

	// correr com B, Esc ao soltar B
	memset(&e, 0, sizeof(e)); out[0] = 0;
	rodar(&e, B(M17B_B), 0, 0, 0, 20, out);
	rodar(&e, B(M17B_B) | B(M17B_CIMA), 0, 0, 30, 100, out);
	rodar(&e, 0, 0, 0, 110, 120, out);
	caso("B segurado + cima = K (correr); soltar o B depois nao vira Esc", "K@90", out);

	memset(&e, 0, sizeof(e)); out[0] = 0;
	rodar(&e, B(M17B_B), 0, 0, 0, 50, out);
	rodar(&e, 0, 0, 0, 60, 60, out);
	caso("toque no B (sem direcao) = voltar, ao soltar", "#1@60", out);

	memset(&e, 0, sizeof(e)); out[0] = 0;
	rodar(&e, B(M17B_A), 0, 0, 0, 500, out);
	caso("A segurado: uma vez so (botoes nao repetem)", "#0@0", out);

	memset(&e, 0, sizeof(e)); out[0] = 0;
	rodar(&e, B(M17B_A) | B(M17B_CIMA) | B(M17B_DIREITA), 0, 0, 0, 10, out);
	caso("A junto com uma diagonal: a diagonal e depois o A, nenhum se perde", "u@0 #0@0", out);

	// traducao por contexto
	ok = m17e_traduzir(M17E_A, M17_NADA, 1) == '>' && m17e_traduzir(M17E_A, M17_NADA, 0) == ',' &&
	     m17e_traduzir(M17E_X, M17_NADA, 0) == 'i' && m17e_traduzir(M17E_Y, M17_NADA, 0) == 's' &&
	     m17e_traduzir(M17E_L1, M17_NADA, 0) == '.' && m17e_traduzir(M17E_L2, M17_NADA, 0) == 16 &&
	     m17e_traduzir(M17E_R2, M17_NADA, 0) == 'a' && m17e_traduzir(M17E_B, M17_NADA, 0) == 27 &&
	     m17e_traduzir(M17E_SELECT, M17_NADA, 0) == -1 && m17e_traduzir(M17E_START, M17_NADA, 0) == -2 &&
	     m17e_traduzir('K', M17_NADA, 0) == 'K';
	conta(ok, "mapa: A pega (ou desce na escada), X inventario, Y procura, L1 descansa, L2 Ctrl+P, R2 repete, B Esc, SELECT/START menus, correr passa");
	ok = m17e_traduzir('K', M17_DIRECAO, 0) == 'k' && m17e_traduzir(M17E_A, M17_DIRECAO, 0) == 0 &&
	     m17e_traduzir(M17E_B, M17_DIRECAO, 0) == 27 && m17e_traduzir(M17E_X, M17_DIRECAO, 0) == 0;
	conta(ok, "direcao?: so direcoes (minusculas), B = Esc, o resto nada");
	ok = m17e_traduzir(M17E_A, M17_SIMNAO, 0) == 'y' && m17e_traduzir(M17E_B, M17_SIMNAO, 0) == 'n' &&
	     m17e_traduzir('k', M17_SIMNAO, 0) == 0;
	conta(ok, "sim/nao: A = y, B = n");
	ok = m17e_traduzir(M17E_A, M17_TEXTO, 0) == '\n' && m17e_traduzir(M17E_B, M17_TEXTO, 0) == 27;
	conta(ok, "texto (call it, opcoes): A = Enter (mantem), B = Esc (cancela)");
	ok = m17e_traduzir(M17E_A, M17_MAIS, ' ') == ' ' && m17e_traduzir(M17E_B, M17_MAIS, ' ') == ' ' &&
	     m17e_traduzir(M17E_A, M17_MAIS, '\n') == '\n';
	conta(ok, "--More--: A ou B avancam (a tecla que o jogo espera)");
	ok = m17e_traduzir(M17E_A, M17_OPCOES, 0) == '\n' && m17e_traduzir('k', M17_OPCOES, 0) == '-' &&
	     m17e_traduzir('l', M17_OPCOES, 0) == 't' && m17e_traduzir('h', M17_OPCOES, 0) == 'f' &&
	     m17e_traduzir(M17E_B, M17_OPCOES, 0) == 27;
	conta(ok, "opcoes: A mantem, direita/esquerda sim/nao, cima volta, B sai");
	ok = m17e_traduzir(M17E_B, M17_ITEM, 0) == 27 && m17e_traduzir(M17E_A, M17_ITEM, 0) == 0;
	conta(ok, "qual objeto?: B = Esc (o seletor cuida do resto)");

	// rogue.cfg
	char arq[512], av[1024];
	M17E_Config c;
	snprintf(arq, sizeof(arq), "%s/rogue.cfg", argc > 1 ? argv[1] : ".");
	int n = m17e_config_ler("/nao/existe/rogue.cfg", &c, av, sizeof(av));
	conta(n == 1 && c.acorde_ms == 60 && c.atraso_ms == 250 && c.repeticao_ms == 110 && c.zona_morta == 12000,
	      "rogue.cfg ausente: o padrao (60/250/110/12000) e um aviso");
	FILE *f = fopen(arq, "w");
	fputs("# comentario\nacorde_ms=80\n atraso_ms = 300\r\nrepeticao_ms=90\nzona_morta=15000\n", f);
	fclose(f);
	n = m17e_config_ler(arq, &c, av, sizeof(av));
	conta(n == 0 && c.acorde_ms == 80 && c.atraso_ms == 300 && c.repeticao_ms == 90 && c.zona_morta == 15000,
	      "rogue.cfg valido (com comentario, espacos e \\r): os quatro valores, sem aviso");
	f = fopen(arq, "w");
	fputs("acorde_ms=9999\natraso_ms=abc\nlixo\ncor=azul\nrepeticao_ms=100\n", f);
	fclose(f);
	n = m17e_config_ler(arq, &c, av, sizeof(av));
	conta(n == 4 && c.acorde_ms == 60 && c.atraso_ms == 250 && c.repeticao_ms == 100 && strstr(av, "acorde_ms invalida") &&
	      strstr(av, "chave desconhecida"),
	      "rogue.cfg com lixo: fora da faixa/nao numero/sem '='/chave estranha -> padrao e 4 avisos; o valido fica");

	printf("falhas: %d\n", falhas);
	return falhas;
}
