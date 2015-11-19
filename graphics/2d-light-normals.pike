#!/usr/bin/env pike

int main() {
	int frame = 0;

	SDL.init(SDL.INIT_VIDEO);
	SDL.Surface screen = SDL.set_video_mode(1280, 720, 24, SDL.HWSURFACE | SDL.DOUBLEBUF | SDL.HWACCEL);

	float m = 0.01;
	float t = 0.0;

	SDL.Event ev = SDL.Event();

	array lights = ({
		({ 128.0, 32.0, 0.75, 0.0, 1.0 }),
	});

	for (int i = 1; i < 16; i++) {
		lights += ({ ({ random(1280), 0.0, random(1.35), random(1.35), random(1.35), random(Math.pi * 2.0), 1 + random(3), 0.1 + random(1.0) }) });
	}

	while (true) {
		Image.Image img = Image.Image(1280, 720, 0, 0, 0);

		for (int i = 1; i < sizeof(lights); i++) {
			array l = lights[i];
			l[0] -= l[6];
			if (l[0] < -256) l[0] = 1280 + 256;

			l[1] = cos(l[5] + t * l[7]) * 120.0 + 120.0;
		}

		array verts = ({ });
		array normals = ({ });

		for (int n = 0; n < 1280; n++) {
			float x = (float)n;
			float y = 360.0 + sin(t + n * m) * 32.0 + cos(t * 1.5 + n * 0.1) * 4.0;

			float x2 = (float)(n + 1);
			float y2 = 360.0 + sin(t + (n + 1) * m) * 32.0 + cos(t * 1.5 + (n + 1) * 0.1) * 4.0;

			float dx = x2 - x;
			float dy = y2 - y;

			float nx = dy;
			float ny = -dx;

			float ix = -dy;
			float iy = dx;

			float l = Math.Matrix(({ nx, ny }))->norm();
			nx /= l;
			ny /= l;
			ix /= l;
			iy /= l;

			verts += ({ ({ x, y }) });
			normals += ({ ({ ix, iy }) });

			float mx = x + (x2 - x) / 2.0;
			float my = y + (y2 - y) / 2.0;
		}

		for (int n = 0; n < sizeof(normals) - 1; n++) {
			float x0 = verts[n][0];
			float y0 = verts[n][1];
			float x1 = verts[n + 1][0];
			float y1 = verts[n + 1][1];

			float ix0 = normals[n][0];
			float iy0 = normals[n][1];
			float ix1 = normals[n + 1][0];
			float iy1 = normals[n + 1][1];

			float pr = 0.0;
			float pg = 0.0;
			float pb = 0.0;

			foreach (lights, array light) {
				array l = ({ x0 - light[0], y0 - light[1] });
				float ln = Math.Matrix(l)->norm();
				l[0] /= ln;
				l[1] /= ln;

				float ip = l[0] * ix0 + l[1] * iy0;
				if (ip < 0.0) ip = 0.0;

				float d = dist(x0, y0, light[0], light[1]);
				float dn = 1.0 / pow(d / 64.0, 2);

				pr += ip * light[2] * dn;
				pg += ip * light[3] * dn;
				pb += ip * light[4] * dn;
			}

			int px0 = (int)(round(x0) + ix0);
			int py0 = (int)(round(y0) + iy0);

			int px1 = (int)(round(x1) + ix1);
			int py1 = (int)(round(y1) + iy1);

			if (pr > 1.0) pr = 1.0;
			if (pg > 1.0) pg = 1.0;
			if (pb > 1.0) pb = 1.0;

			float cr = pr;
			float cg = pg;
			float cb = pb;

			int n = 0;
			while (cr + cg + cb > 0.0) {
				int px0 = (int)(round(x0) + ix0);
				int py0 = (int)(round(y0) + iy0 + n);

				int px1 = (int)(round(x1) + ix1);
				int py1 = (int)(round(y1) + iy1 + n);

				img->line(px0, py0, px1, py1, (int)(cr * 255), (int)(cg * 255), (int)(cb * 255));
				n++;

				cr -= 0.01;
				cg -= 0.01;
				cb -= 0.01;
				if (cr < 0.0) cr = 0.0;
				if (cg < 0.0) cg = 0.0;
				if (cb < 0.0) cb = 0.0;
			}
		}

		foreach (lights, array light) {
			float cr = max(light[2], 1.0);
			float cg = max(light[3], 1.0);
			float cb = max(light[4], 1.0);

			img->circle((int)round(light[0]), (int)round(light[1]), 4, 4, (int)(cr * 255), (int)(cg * 255), (int)(cb * 255));
		}

		SDL.Surface()->set_image(img, SDL.HWSURFACE)->display_format()->blit(screen);
		SDL.flip();
		Pike.DefaultBackend(0.0);

		while (ev->get()) {
			if (ev->type == SDL.QUIT) exit(0);
			else if (ev->type == SDL.MOUSEMOTION) {
				lights[0][0] = ev->x;
				lights[0][1] = ev->y;
			}
		}

		frame++;
		t += 0.025;
	}
}

float dist(int|float x0, int|float y0, int|float x1, int|float y1) {
	return sqrt(pow((float)x1 - (float)x0, 2) + pow((float)y1 - (float)y0, 2));
}

float max(float n, float m) {
	if (n > m) return m;
	else return n;
}
