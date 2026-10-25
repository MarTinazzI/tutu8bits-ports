/* m17menus.c — os menus do Rogue no M17, desenhados por cima da tela do jogo (spec 035, plano D-07):
 * SELECT = comandos (ordem da spec, sec. 8); START = o jogo (ajuda, opcoes, descobertas, versao, salvar e sair,
 * desistir); o seletor de objeto quando o jogo pergunta "qual objeto?". D-pad move, A escolhe, B fecha. Escolher manda
 * a(s) tecla(s) ao jogo como se tivessem sido digitadas. A tela do jogo nao muda: o menu so existe no desenho. */
#include "m17.h"
#include "curses.h"

#include <stdio.h>
#include <string.h>

#define MAX_ITENS 32

typedef struct
{
    char texto[64];
    char envio[8];   /* teclas para o jogo; "" = linha so de aviso; "\x01" = salvar e sair; "\x02" = simbolos */
} Item;

static bool aberto;
static int tipo_menu;   /* 0 comandos, 1 jogo, 2 seletor, 3 simbolos */
static char titulo[64];
static Item itens[MAX_ITENS];
static int n_itens, cursor, topo;

static const Uint16 FRENTE = 0xC618, FUNDO = 0x0000, BORDA = 0xFFE0;   /* borda amarela, para separar do jogo */

static void limpar(const char *t, int tipo)
{
    snprintf(titulo, sizeof(titulo), "%s", t);
    n_itens = cursor = topo = 0;
    tipo_menu = tipo;
    aberto = true;
}

static void item(const char *texto, const char *envio)
{
    if (n_itens >= MAX_ITENS)
        return;
    snprintf(itens[n_itens].texto, sizeof(itens[n_itens].texto), "%s", texto);
    snprintf(itens[n_itens].envio, sizeof(itens[n_itens].envio), "%s", envio);
    n_itens++;
}

bool m17m_ativo(void)
{
    return aberto;
}

void m17m_abrir_comandos(void)
{
    limpar("Comandos", 0);
    item("Beber pocao        q", "q");
    item("Ler pergaminho     r", "r");
    item("Comer              e", "e");
    item("Empunhar arma      w", "w");
    item("Vestir armadura    W", "W");
    item("Tirar armadura     T", "T");
    item("Colocar anel       P", "P");
    item("Tirar anel         R", "R");
    item("Arremessar         t", "t");
    item("Usar varinha       z", "z");
    item("Largar             d", "d");
    item("Lutar ate o fim    f", "f");
    item("Mover sem pegar    m", "m");
    item("Descer escada      >", ">");
    item("Subir escada       <", "<");
    item("Identificar simb.  /", "\x02");
    item("Tipo de armadilha  ^", "^");
    item("Dar nome a objeto  c", "c");
    item("Ver arma           )", ")");
    item("Ver armadura       ]", "]");
    item("Ver aneis          =", "=");
    item("Ver estado         @", "@");
    item("Inventario de um   I", "I");
}

void m17m_abrir_jogo(void)
{
    limpar("Rogue", 1);
    item("Ajuda              ?", "?*");
    item("Opcoes             o", "o");
    item("Descobertas        D", "D*");
    item("Versao             v", "v");
    item("Salvar e sair", "\x01");
    item("Desistir (perde)   Q", "Q");
}

void m17m_abrir_seletor(int tipo)
{
    char letras[MAX_ITENS], nomes[MAX_ITENS][64];
    int n = m17_itens(tipo, letras, nomes, MAX_ITENS);
    limpar("Qual objeto?", 2);
    for (int i = 0; i < n; i++)
    {
        char t[64], e[2] = { letras[i], '\0' };
        snprintf(t, sizeof(t), "%c) %.58s", letras[i], nomes[i]);
        item(t, e);
    }
    if (n == 0)
        item("(nada apropriado)", "");
}

static void abrir_simbolos(void)
{
    static const char *const S[][2] = {
        { "@ voce", "@" }, { "% escada", "%" }, { "+ porta", "+" }, { "# corredor", "#" }, { ". chao", "." },
        { "- parede", "-" }, { "| parede", "|" }, { "^ armadilha", "^" }, { ": comida", ":" }, { "! pocao", "!" },
        { "? pergaminho", "?" }, { ") arma", ")" }, { "] armadura", "]" }, { "= anel", "=" },
        { "/ varinha", "/" }, { "* ouro", "*" }, { ", amuleto", "," },
    };
    limpar("Identificar simbolo", 3);
    for (size_t i = 0; i < sizeof(S) / sizeof(S[0]); i++)
    {
        char e[3] = { '/', S[i][1][0], '\0' };
        item(S[i][0], e);
    }
}

int m17m_navegar(int codigo)
{
    if (!aberto)
        return -1;
    int visiveis = 18;
    switch (codigo)
    {
    case 'k': case 'K': case 'y': case 'u':
        cursor = (cursor + n_itens - 1) % n_itens;
        break;
    case 'j': case 'J': case 'b': case 'n':
        cursor = (cursor + 1) % n_itens;
        break;
    case 'h': case 'H':
        cursor = cursor >= visiveis ? cursor - visiveis : 0;
        break;
    case 'l': case 'L':
        cursor = cursor + visiveis < n_itens ? cursor + visiveis : n_itens - 1;
        break;
    case M17E_B:
    case M17E_SELECT:
    case M17E_START:
        aberto = false;
        return -1;
    case M17E_A:
    {
        const char *e = itens[cursor].envio;
        if (e[0] == '\x01')
        {
            aberto = false;
            m17_salvar_e_sair();
            return 0;
        }
        if (e[0] == '\x02')
        {
            abrir_simbolos();
            return 0;
        }
        aberto = false;
        if (e[0] == '\0')
            return -1;
        m17_enfileirar(e + 1);
        return (unsigned char)e[0];
    }
    default:
        return 0;
    }
    if (cursor < topo)
        topo = cursor;
    if (cursor >= topo + visiveis)
        topo = cursor - visiveis + 1;
    return 0;
}

static void texto(Uint16 *p, int y, int x, const char *s, int largura, bool inverso, Uint16 frente)
{
    for (int i = 0; i < largura; i++)
    {
        char c = *s ? *s++ : ' ';
        m17v_celula(p, y, x + i, (unsigned char)c, inverso, frente, FUNDO);
    }
}

void m17m_desenhar(Uint16 *p)
{
    if (!aberto)
        return;
    int largura = (int)strlen(titulo);
    for (int i = 0; i < n_itens; i++)
        if ((int)strlen(itens[i].texto) > largura)
            largura = (int)strlen(itens[i].texto);
    largura += 2;
    int visiveis = n_itens < 18 ? n_itens : 18;
    int alto = visiveis + 4;   /* borda, titulo, linha, itens, borda */
    int y0 = (24 - alto) / 2, x0 = (80 - (largura + 2)) / 2;
    /* moldura */
    char linha[82];
    memset(linha, '-', sizeof(linha));
    linha[0] = '+';
    linha[largura + 1] = '+';
    linha[largura + 2] = '\0';
    texto(p, y0, x0, linha, largura + 2, false, BORDA);
    texto(p, y0 + alto - 1, x0, linha, largura + 2, false, BORDA);
    for (int y = y0 + 1; y < y0 + alto - 1; y++)
    {
        texto(p, y, x0, "|", 1, false, BORDA);
        texto(p, y, x0 + largura + 1, "|", 1, false, BORDA);
    }
    char t[82];
    snprintf(t, sizeof(t), " %s", titulo);
    texto(p, y0 + 1, x0 + 1, t, largura, false, BORDA);
    texto(p, y0 + 2, x0 + 1, "", largura, false, FRENTE);
    for (int i = 0; i < visiveis; i++)
    {
        int k = topo + i;
        snprintf(t, sizeof(t), " %s", itens[k].texto);
        texto(p, y0 + 3 + i, x0 + 1, t, largura, k == cursor, FRENTE);
    }
}
