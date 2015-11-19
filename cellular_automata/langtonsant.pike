/*
Rules: https://secure.wikimedia.org/wikipedia/en/wiki/Langton%27s_ant

NOTE: This is using a modified version of Langton's Ant with more states.
*/

#define WIDTH  512
#define HEIGHT 512
//#define RANDOM_GRID

SDL.Surface rootsurf;

array steps = ({ });
array grid;
int antx;
int anty;
int antrot = 1;

int frame;

int main() {
	int n = random(14892374923);

	random_seed(n);
	write("Seed = %d\n", n);

	for (int i = 0; i < 32; i++) {
		steps += ({ random(4) });
	}

	grid = allocate(WIDTH, allocate(HEIGHT, 0));
	antx = WIDTH/2;
	anty = HEIGHT/2;

	SDL.init(SDL.INIT_VIDEO);
	rootsurf = SDL.set_video_mode(WIDTH, HEIGHT, 24, SDL.HWACCEL | SDL.DOUBLEBUF | SDL.HWSURFACE | SDL.PREALLOC);
	rootsurf->lock();

	#ifdef RANDOM_GRID
		int s = sizeof(steps);
		for (int x = 0; x < WIDTH; x++) {
			for (int y = 0; y < HEIGHT; y++) {
				grid[x][y] = random(s);
				rootsurf->set_pixel(x, y, rootsurf->format->map_rgb(0, 0, grid[x][y]));
			}
		}
	#endif

	while (1) {
		for (int i = 0; i < 10000; i++) {
			step();
		}

		eventhandler();
		SDL.flip();
		Pike.DefaultBackend(0.0);
	}
}

void eventhandler() {
	SDL.Event e = SDL.Event();
	while (e->get()) {
		if (e->type == SDL.QUIT) exit(0);
	}
}

void step() {
	int n = steps[grid[antx][anty]];
	if (++grid[antx][anty] == sizeof(steps)) {
		grid[antx][anty] = 0;
	}

	int c = grid[antx][anty] * 8;
	rootsurf->set_pixel(antx, anty, rootsurf->format->map_rgb(c, c, c));

	if (n == 0) antrot = (antrot - 1) % 4;
	else antrot = (antrot + 1) % 4;

	if (antrot == 0) antx = (antx - 1) % WIDTH;
	else if (antrot == 1) anty = (anty - 1) % HEIGHT;
	else if (antrot == 2) antx = (antx + 1) % WIDTH;
	else anty = (anty + 1) % HEIGHT;
}
