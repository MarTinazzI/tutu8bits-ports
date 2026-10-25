// Programa de teste do teclado virtual (spec 036, T02): abre uma janela e um renderer como um jogo (tamanho logico
// 320x240, de proposito diferente do teclado), chama o m17_teclado() com o texto e o maximo dados e imprime o
// resultado e o tamanho logico depois (o teclado tem de restaurar o do jogo).
// Uso: prog_teclado <titulo> <texto inicial> <max>     (texto "@lista": um nome da lista M17_NOMES)
#include "teclado.h"

#include <stdio.h>
#include <stdlib.h>
#include <string.h>

int main(int argc, char **argv)
{
	if (argc < 4)
		return 2;
	if (SDL_Init(SDL_INIT_VIDEO | SDL_INIT_JOYSTICK) != 0)
	{
		fprintf(stderr, "SDL_Init: %s\n", SDL_GetError());
		return 1;
	}
	SDL_Window *w = SDL_CreateWindow("teclado", SDL_WINDOWPOS_CENTERED, SDL_WINDOWPOS_CENTERED, 480, 272, 0);
	SDL_Renderer *r = w ? SDL_CreateRenderer(w, -1, 0) : NULL;
	if (r == NULL)
	{
		fprintf(stderr, "renderer: %s\n", SDL_GetError());
		return 1;
	}
	SDL_RenderSetLogicalSize(r, 320, 240);
	char buf[256];
	snprintf(buf, sizeof(buf), "%s", argv[2]);
	if (strcmp(argv[2], "@lista") == 0)   // spec 042: o texto inicial vem da lista M17_NOMES (m17_teclado_nome)
		printf("lista=%d\n", m17_teclado_nome(buf, atoi(argv[3]) + 1));
	int ok = m17_teclado(r, argv[1], buf, atoi(argv[3]));
	int lw, lh;
	SDL_RenderGetLogicalSize(r, &lw, &lh);
	printf("resultado=%d texto=[%s] logico=%dx%d\n", ok, buf, lw, lh);
	SDL_DestroyRenderer(r);
	SDL_DestroyWindow(w);
	SDL_Quit();
	return 0;
}
