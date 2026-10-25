/* m17_ponte.c — o que a camada do M17 precisa saber do jogo (spec 035, plano D-06). Compilado com os cabecalhos do
 * Rogue; so le o estado do jogo (nenhuma regra muda). */
#include <curses.h>
#include <string.h>
#include "rogue.h"
#include "m17.h"

/* o A no mapa: na escada desce ('>'), senao pega (',') */
bool m17_heroi_na_escada(void)
{
    return chat(hero.y, hero.x) == STAIRS;
}

/* a mochila filtrada como o inventory() do pack.c faz para o get_item */
int m17_itens(int tipo, char *letras, char nomes[][64], int max)
{
    int n = 0;
    for (THING *o = pack; o != NULL && n < max; o = next(o))
    {
        if (tipo && tipo != o->o_type && !(tipo == CALLABLE && o->o_type != FOOD && o->o_type != AMULET) &&
            !(tipo == R_OR_S && (o->o_type == RING || o->o_type == STICK)))
            continue;
        letras[n] = o->o_packch;
        snprintf(nomes[n], 64, "%s", inv_name(o, FALSE));
        n++;
    }
    return n;
}

/* START -> "Salvar e sair" e o SDL_QUIT: o mesmo save automatico do SIGTERM (patch rogue-m17-01) */
void m17_salvar_e_sair(void)
{
    auto_save(0);
}
