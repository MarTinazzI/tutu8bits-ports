// Arnes da roda de opcoes (spec 048, T02; CA-01, CA-03): a parte pura do roda.c, compilada com o gcc do PC (sem SDL).
// Uso: arnes [arquivo.roda...] — sem argumento, os casos embutidos; com arquivos, so confere que cada um le sem erro
// (a roda do produto e o exemplo do rodas.md, T06/T07).
#include "roda.h"

#include <stdio.h>
#include <string.h>

static int falhas = 0;

static void conta(int ok, const char *o_que)
{
    printf("%s %s\n", ok ? "ok   " : "FALHA", o_que);
    if (!ok)
        falhas++;
}

#define MAX 32767

static void setores(void)
{
    conta(roda_setor(0, -MAX, 8) == 0 && roda_setor(MAX, 0, 8) == 2 && roda_setor(0, MAX, 8) == 4 &&
          roda_setor(-MAX, 0, 8) == 6 && roda_setor(23000, -23000, 8) == 1 && roda_setor(-23000, -23000, 8) == 7,
          "8 fatias: cima 0, direita 2, baixo 4, esquerda 6, diagonais 1 e 7 (horario)");
    conta(roda_setor(0, 0, 8) == -1 && roda_setor(13000, 0, 8) == -1 && roda_setor(13200, 0, 8) == 2,
          "zona morta de 40 %: centro e 13000 = nada; 13200 = fatia");
    conta(roda_setor(0, -MAX, 3) == 0 && roda_setor(MAX, 0, 3) == 1 && roda_setor(0, MAX, 3) == 2 &&
          roda_setor(-MAX, 0, 3) == 2 && roda_setor(-MAX / 2, -MAX, 3) == 0 && roda_setor(-MAX, -MAX / 4, 3) == 2,
          "3 fatias: setores de 120 graus, a 1a em cima");
    conta(roda_setor(MAX, MAX, 1) == 0 && roda_setor(-MAX, 0, 1) == 0 && roda_setor(0, 0, 0) == -1,
          "1 fatia: qualquer direcao fora do centro; 0 fatias = nada");
}

/* roteiro de passos: cada item e (ax, ay, botoes, ms) */
typedef struct { int ax, ay; unsigned b, ms; } P;

static int rodar(const Roda *r, int rapido, const P *ps, int n, int *fatia, int *pagina)
{
    RodaEstado e;
    int res = RODA_SEGUE;
    roda_iniciar(&e, rapido);
    for (int i = 0; i < n && res == RODA_SEGUE; i++)
    {
        RodaEntrada in = { ps[i].b, ps[i].ax, ps[i].ay, ps[i].ms };
        res = roda_passo(&e, r, &in, fatia);
    }
    if (pagina)
        *pagina = e.pagina;
    return res;
}

static void passos(void)
{
    Roda r;
    char erro[256];
    int f = -1, pg = -1;
    roda_ler_texto("[Um]\na|1|a\nb|2|b\nc|3|c\nd|4|d\n[Dois]\ne|5|e\nf|6|f\n[Tres]\ng|7|g\n", "t", &r, erro, sizeof erro);
    {
        P s[] = { { MAX, 0, 0, 0 }, { MAX, 0, 0, 100 }, { 0, 0, 0, 120 }, { 0, 0, RODA_B_A, 130 } };
        conta(rodar(&r, 0, s, 4, &f, NULL) == RODA_ESCOLHEU && f == 1,
              "sem gatilho: apontar, soltar (centro) e A = a fatia fica escolhida e confirma (1)");
    }
    {
        P s[] = { { 0, 0, RODA_B_A, 0 } };
        conta(rodar(&r, 0, s, 1, &f, NULL) == RODA_SEGUE, "sem gatilho: A sem nada apontado ainda = nada");
    }
    {
        P s[] = { { MAX, 0, 0, 0 }, { 0, 0, 0, 50 }, { -MAX, 0, 0, 60 }, { -MAX, 0, 0, 130 }, { 0, 0, 0, 140 },
                  { 0, 0, RODA_B_A, 150 } };
        conta(rodar(&r, 0, s, 6, &f, NULL) == RODA_ESCOLHEU && f == 3,
              "sem gatilho: apontar outra por 70 ms troca a escolha (3)");
    }
    {
        P s[] = { { MAX, 0, 0, 0 }, { 0, 0, 0, 30 }, { 0, 0, RODA_B_A, 40 } };
        conta(rodar(&r, 1, s, 3, &f, NULL) == RODA_SEGUE, "com gatilho: soltar sem armar tira a escolha; A no centro = nada");
    }
    {
        P s[] = { { MAX, 0, 0, 0 }, { MAX, 0, RODA_B_A, 10 } };
        conta(rodar(&r, 0, s, 2, &f, NULL) == RODA_ESCOLHEU && f == 1, "sem gatilho: apontar a direita e A = fatia 1 (de 4)");
    }
    {
        P s[] = { { 0, MAX, 0, 0 }, { 0, MAX, 0, 30 }, { 0, 0, 0, 40 } };
        conta(rodar(&r, 1, s, 3, &f, NULL) == RODA_SEGUE, "gatilho rapido: 30 ms apontada e solta = nada (nao armou)");
    }
    {
        P s[] = { { 0, MAX, 0, 0 }, { 0, MAX, 0, 70 }, { 0, 0, 0, 80 } };
        conta(rodar(&r, 1, s, 3, &f, NULL) == RODA_ESCOLHEU && f == 2, "gatilho rapido: 70 ms apontada e solta = fatia 2");
    }
    {
        P s[] = { { MAX, 0, 0, 0 }, { MAX, 0, 0, 70 }, { -MAX, 0, 0, 75 }, { -MAX, 0, 0, 85 }, { 0, 0, 0, 90 } };
        conta(rodar(&r, 1, s, 5, &f, NULL) == RODA_ESCOLHEU && f == 1,
              "gatilho rapido: outra fatia por 10 ms e soltar = a armada antes (1)");
    }
    {
        P s[] = { { MAX, 0, 0, 0 }, { MAX, 0, 0, 70 }, { -MAX, 0, 0, 75 }, { -MAX, 0, 0, 145 }, { 0, 0, 0, 150 } };
        conta(rodar(&r, 1, s, 5, &f, NULL) == RODA_ESCOLHEU && f == 3,
              "gatilho rapido: outra fatia por 70 ms e soltar = a nova (3)");
    }
    {
        P s[] = { { MAX, 0, 0, 0 }, { 0, MAX, 0, 10 }, { -MAX, 0, 0, 50 }, { 0, -MAX, 0, 90 }, { 0, 0, 0, 100 } };
        conta(rodar(&r, 1, s, 5, &f, NULL) == RODA_SEGUE,
              "gatilho rapido: cruzar as fatias sem parar em nenhuma e soltar = nada");
    }
    {
        /* soltar na diagonal (sessao 1): a mola zera o eixo x antes do y, e o analogico passa pela fatia de cima */
        Roda o;
        const int D = 23170;   /* 45 graus na borda */
        roda_ler_texto("n|n|n\nne|ne|ne\ne|e|e\nse|se|se\ns|s|s\nso|so|so\no|o|o\nno|no|no\n", "o", &o, erro,
                       sizeof erro);
        P s[] = { { D, -D, 0, 0 }, { D, -D, 0, 100 }, { 0, -D, 0, 110 }, { 0, -D, 0, 150 }, { 0, 0, 0, 160 } };
        P t[] = { { D, -D, 0, 0 }, { D, -D, 0, 100 }, { 0, -D, 0, 110 }, { 0, -D, 0, 150 }, { 0, 0, 0, 160 },
                  { 0, 0, RODA_B_A, 300 } };
        P u[] = { { D, -D, 0, 0 }, { D, -D, 0, 100 }, { -5000, -15000, 0, 110 }, { -5000, -15000, 0, 300 },
                  { 0, 0, 0, 310 } };
        conta(rodar(&o, 1, s, 5, &f, NULL) == RODA_ESCOLHEU && f == 1 &&
              rodar(&o, 0, t, 6, &f, NULL) == RODA_ESCOLHEU && f == 1,
              "soltar na diagonal (8 fatias): a de cima por 50 ms nao toma o lugar (1), com e sem gatilho");
        conta(rodar(&o, 1, u, 5, &f, NULL) == RODA_ESCOLHEU && f == 1,
              "fora da borda (menos de 60 %), outra direcao nao troca a fatia, nem em 200 ms (1)");
    }
    {
        P s[] = { { -MAX, 0, 0, 0 }, { -MAX, 0, RODA_B_A, 5 } };
        conta(rodar(&r, 1, s, 2, &f, NULL) == RODA_ESCOLHEU && f == 3, "gatilho rapido: o A tambem confirma");
    }
    {
        P s[] = { { MAX, 0, 0, 0 }, { MAX, 0, RODA_B_B, 5 } };
        P t[] = { { MAX, 0, 0, 0 }, { MAX, 0, 0, 80 }, { MAX, 0, RODA_B_R3, 90 } };
        conta(rodar(&r, 0, s, 2, &f, NULL) == RODA_CANCELOU && rodar(&r, 1, t, 3, &f, NULL) == RODA_CANCELOU,
              "B e R3 cancelam (nos dois modos, mesmo com fatia armada)");
    }
    {
        P s[] = { { 0, 0, RODA_B_R1, 0 }, { 0, -MAX, 0, 5 }, { 0, -MAX, RODA_B_A, 10 } };
        conta(rodar(&r, 0, s, 3, &f, &pg) == RODA_ESCOLHEU && pg == 1 && f == 0, "R1: pagina 2, fatia 0 dela");
    }
    {
        P s[] = { { 0, 0, RODA_B_L1, 0 } };
        rodar(&r, 0, s, 1, &f, &pg);
        conta(pg == 2, "L1 na 1a pagina vai para a ultima");
    }
    {
        P s[] = { { MAX, 0, 0, 0 }, { MAX, 0, RODA_B_R1, 10 }, { MAX, 0, RODA_B_A, 15 } };
        conta(rodar(&r, 0, s, 3, &f, &pg) == RODA_ESCOLHEU && pg == 1 && f == 1,
              "trocar a pagina tira o destaque; a fatia vale pela pagina nova (2 fatias: direita = 1)");
    }
    {
        Roda u;
        roda_ler_texto("a|1|a\nb|2|b\n", "u", &u, erro, sizeof erro);
        P s[] = { { 0, 0, RODA_B_R1 | RODA_B_L1, 0 } };
        rodar(&u, 0, s, 1, &f, &pg);
        conta(pg == 0, "uma pagina so: L1/R1 nao mudam nada");
    }
}

static void latin1(void)
{
    char s[64];
    conta(roda_latin1("Lançar Perícias", s, sizeof s) == 15 && strcmp(s, "Lan\xe7" "ar Per\xed" "cias") == 0,
          "UTF-8 -> Latin-1: Lançar, Perícias");
    conta(roda_latin1("ação \xf0\x9f\x98\x80!", s, sizeof s) == 7 && strcmp(s, "a\xe7\xe3o ?!") == 0,
          "fora do Latin-1 (emoji) vira ?");
    conta(roda_latin1("a\xc3", s, sizeof s) == 2 && strcmp(s, "a?") == 0 && roda_latin1("\x80x", s, sizeof s) == 2 &&
          strcmp(s, "?x") == 0, "UTF-8 quebrado vira ?");
    conta(roda_latin1("abcdef", s, 4) == -1, "nao cabe = -1");
}

static void teclas(void)
{
    char s[16];
    conta(roda_teclas("^D", s, sizeof s) == 1 && s[0] == 4 && roda_teclas("^x", s, sizeof s) == 1 && s[0] == 0x18,
          "notacao: ^D = Ctrl+D (0x04), ^x = Ctrl+X");
    conta(roda_teclas("s", s, sizeof s) == 1 && strcmp(s, "s") == 0 && roda_teclas("#pray", s, sizeof s) == 5 &&
          strcmp(s, "#pray") == 0 && roda_teclas("a^", s, sizeof s) == 2 && strcmp(s, "a^") == 0,
          "notacao: caracteres como estao; #comando passa como texto; ^ no fim = ^");
    conta(roda_teclas("<F5>", s, sizeof s) == -1 && roda_teclas("0123456789abcdefg", s, sizeof s) == -1,
          "notacao: <Nome> e o que nao cabe = -1");
}

static void leitura(void)
{
    Roda r;
    char erro[256];
    const char *ok =
        "# roda de teste\n"
        "rapido = sim\n"
        "\n"
        "[Ações]\n"
        "Pegar  | Pegar o que está no chão | ,\n"
        "Rezar  |                          | #pray\n"
        "Lançar | Lançar uma magia         | Z\n"
        "Barra  | Uma barra na ação        | a|b\n"
        "[Olhar]\r\n"
        "Olhar | Olhar um ponto | ;\r\n";
    int res = roda_ler_texto(ok, "ok.roda", &r, erro, sizeof erro);
    conta(res == 0 && r.rapido == 1 && r.npaginas == 2 && r.p[0].n == 4 && r.p[1].n == 1,
          "arquivo bom: rapido = sim, 2 paginas, 4 + 1 fatias (comentarios, linhas vazias e CRLF ignorados)");
    conta(res == 0 && strcmp(r.p[0].nome, "A\xe7\xf5" "es") == 0 && strcmp(r.p[0].f[2].rotulo, "Lan\xe7" "ar") == 0 &&
          strcmp(r.p[0].f[0].descricao, "Pegar o que est\xe1 no ch\xe3o") == 0,
          "nomes, rotulos e descricoes em Latin-1");
    conta(res == 0 && strcmp(r.p[0].f[1].acao, "#pray") == 0 && r.p[0].f[1].descricao[0] == '\0' &&
          strcmp(r.p[0].f[3].acao, "a|b") == 0, "acao como no arquivo (#pray; \"|\" no resto da linha); descricao vazia vale");
    conta(roda_ler_texto("a|1|a\n", "s", &r, erro, sizeof erro) == 0 && r.npaginas == 1 && r.p[0].nome[0] == '\0' &&
          r.rapido == 0, "sem \"[...]\": uma pagina sem nome; rapido padrao = nao");

    struct { const char *txt, *esperado, *o_que; } E[] = {
        { "a|1|a\nb 2 b\n", "e.roda linha 2: fatia sem os dois", "linha sem os dois |" },
        { "x|1\n", "e.roda linha 1: fatia sem os dois", "linha com um | so" },
        { " | sem rotulo | a\n", "e.roda linha 1: rotulo vazio", "rotulo vazio" },
        { "Rotulo009|x|a\n", "e.roda linha 1: rotulo com mais de 8", "rotulo de 9 caracteres" },
        { "Açõesxyz|x|a\n", NULL, "rotulo de 8 caracteres com acento vale (conta caracteres, nao bytes)" },
        { "a|1234567890123456789012345678901234567890123456789012345678901|a\n", "linha 1: descricao com mais de 60",
          "descricao de 61" },
        { "a|x|\n", "e.roda linha 1: acao vazia", "acao vazia" },
        { "a|x|12345678901234567890123456789012345678901234567890123456789012345\n", "linha 1: acao com mais de 64",
          "acao de 65 bytes" },
        { "1|1|1\n2|2|2\n3|3|3\n4|4|4\n5|5|5\n6|6|6\n7|7|7\n8|8|8\n9|9|9\n", "e.roda linha 9: mais de 8 fatias",
          "9 fatias numa pagina" },
        { "[1]\na|a|a\n[2]\na|a|a\n[3]\na|a|a\n[4]\na|a|a\n[5]\na|a|a\n[6]\na|a|a\n[7]\na|a|a\n[8]\na|a|a\n[9]\na|a|a\n",
          "e.roda linha 17: mais de 8 paginas", "9 paginas" },
        { "# so comentario\n\n", "e.roda linha 2: nenhuma fatia", "nenhuma fatia" },
        { "rapido = talvez\na|a|a\n", "e.roda linha 1: rapido = \"talvez\"", "rapido com valor errado" },
        { "cor = azul\na|a|a\n", "e.roda linha 1: chave desconhecida \"cor\"", "chave desconhecida" },
        { "a|a|a\nrapido = sim\n", "e.roda linha 2: \"rapido =\" so antes", "chave depois da 1a fatia" },
        { "[Um]\n[Dois]\na|a|a\n", "e.roda linha 1: pagina vazia", "pagina vazia no meio" },
        { "a|a|a\n[Fim]\n", "e.roda linha 2: pagina vazia", "pagina vazia no fim" },
        { "[Sem fim\na|a|a\n", "e.roda linha 1: pagina sem \"]\"", "pagina sem ]" },
    };
    for (size_t i = 0; i < sizeof E / sizeof E[0]; i++)
    {
        char o[512];
        int rr = roda_ler_texto(E[i].txt, "e.roda", &r, erro, sizeof erro);
        int certo = E[i].esperado ? (rr == -1 && strstr(erro, E[i].esperado) != NULL) : rr == 0;
        snprintf(o, sizeof o, "erro: %s%s%s", E[i].o_que, certo ? "" : " -> ", certo ? "" : erro);
        conta(certo, o);
    }
    {
        char longa[700];
        memset(longa, 'x', sizeof longa);
        memcpy(longa, "a|b|", 4);
        longa[sizeof longa - 1] = '\0';
        conta(roda_ler_texto(longa, "e.roda", &r, erro, sizeof erro) == -1 && strstr(erro, "linha 1: linha com mais de 512"),
              "erro: linha com mais de 512 bytes");
    }
    conta(roda_ler("/nao/existe.roda", &r, erro, sizeof erro) == -1 && strstr(erro, "/nao/existe.roda: nao abre"),
          "arquivo que nao existe: \"nao abre\"");
}

int main(int argc, char **argv)
{
    if (argc > 1)
    {
        for (int i = 1; i < argc; i++)
        {
            Roda r;
            char erro[256], o[400];
            int res = roda_ler(argv[i], &r, erro, sizeof erro);
            snprintf(o, sizeof o, "%s le sem erro%s%s", argv[i], res ? ": " : "", res ? erro : "");
            conta(res == 0, o);
        }
    }
    else
    {
        setores();
        passos();
        latin1();
        teclas();
        leitura();
    }
    printf("falhas: %d\n", falhas);
    return falhas != 0;
}
