/* m17entrada.h — a entrada do Rogue no M17 (spec 035, plano D-04): parte PURA (sem SDL), testada no PC com tempos
 * simulados (ports/testes/fontes/arnes_m17entrada.c). */
#ifndef M17ENTRADA_H
#define M17ENTRADA_H

/* indices do joystick cru do aparelho (i2c-keys; KB 11k, 11z) */
#define M17B_R1 3
#define M17B_Y 4
#define M17B_START 5
#define M17B_A 6
#define M17B_L1 7
#define M17B_L2 8
#define M17B_X 9
#define M17B_R2 10
#define M17B_B 11
#define M17B_SELECT 12
#define M17B_CIMA 13
#define M17B_ESQUERDA 14
#define M17B_DIREITA 15
#define M17B_BAIXO 16

/* que pergunta o jogo esta fazendo (o mapa = NADA) */
enum { M17_NADA, M17_ITEM, M17_DIRECAO, M17_SIMNAO, M17_TEXTO, M17_MAIS, M17_OPCOES };

/* codigos dos botoes (alem das letras de direcao, que saem como 'h'...'n' e maiusculas) */
enum { M17E_A = 0x100, M17E_B, M17E_X, M17E_Y, M17E_L1, M17E_L2, M17E_R2, M17E_SELECT, M17E_START };

typedef struct
{
    int acorde_ms, atraso_ms, repeticao_ms, zona_morta;
} M17E_Config;

typedef struct
{
    unsigned botoes;     /* bit i = botao i do joystick apertado */
    int ax, ay;          /* analogico esquerdo, -32768..32767 */
    unsigned ms;         /* tempo agora */
} M17E_Entrada;

typedef struct
{
    unsigned antes;      /* botoes no passo anterior */
    int segurando;       /* alguma direcao esta valendo */
    unsigned t0, prox;   /* inicio da direcao; proxima repeticao */
    int emitiu;          /* ja saiu a 1a letra desta direcao */
    int b_com_direcao;   /* o B foi usado para correr enquanto segurado (ao soltar, nao vira Esc) */
    int pendente;        /* botao apertado no mesmo passo de uma direcao: sai no passo seguinte */
} M17E_Estado;

void m17e_config_padrao(M17E_Config *c);
/* le chave=valor; o que faltar ou estiver fora da faixa fica no padrao e vira aviso (texto em avisos, uma linha por
 * aviso); devolve o numero de avisos. arq NULL ou ausente = so o padrao, com um aviso. */
int m17e_config_ler(const char *arq, M17E_Config *c, char *avisos, int tam);

/* um passo: devolve uma letra de direcao ('y' 'k' 'u' 'h' 'l' 'b' 'j' 'n', maiuscula = correr), um codigo M17E_* ou
 * 0. Chamar em laco (a cada evento e a cada ~10 ms enquanto algo esta segurado). */
int m17e_passo(M17E_Estado *e, const M17E_Config *c, const M17E_Entrada *in);
/* algo segurado que pede chamadas periodicas (acorde/repeticao/B) */
int m17e_ocupado(const M17E_Estado *e);

/* traduz um codigo do passo para a tecla do jogo, conforme a pergunta (contexto M17_*). extra: no mapa (NADA), 1 se o
 * heroi esta na escada; no MAIS, a tecla que o jogo espera. Devolve a tecla, 0 = nada, -1 = abrir o menu de
 * comandos, -2 = abrir o menu do jogo. */
int m17e_traduzir(int codigo, int contexto, int extra);

#endif
