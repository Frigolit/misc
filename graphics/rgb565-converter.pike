#!/usr/bin/env pike

/*
RGB565 Image Converter

Converts images to the RGB565 using a custom format. Supports animated GIFs (however buggy with a few).
This was designed to be used with a ST7735 TFT display and an ARM mbed platform.
*/

int main(int argc, array argv) {
	if (argc < 2) {
		werror("Usage: %s <input file> [output file]\n", basename(argv[0]));
		return 1;
	}

	int sw = (int)Getopt.find_option(argv, "w", "width", UNDEFINED, "0");
	int sh = (int)Getopt.find_option(argv, "h", "height", UNDEFINED, "0");
	int colormode = (int)Getopt.find_option(argv, "p", "palette", UNDEFINED, "3");

	argv = Getopt.get_args(argv);

	string fn = argv[1];
	array frames = ({ });
	int w, h;

	if (glob("*.gif", fn)) {
		array a = Image.GIF._decode(Stdio.read_file(fn));

		w = a[0];
		h = a[1];

		Image.Image img = Image.Image(w, h, 255, 255, 255);

		int n = 0;
		foreach (a[3..], array b) {
			if (b[0] != 1) continue;

			img = Image.Image(w, h, 255, 255, 255);

			if (b[4]) img->paste_mask(b[3], b[4], b[1], b[2]);
			else img->paste(b[3], b[1], b[2]);

			Image.Image ximg = img;

			if (sw || sh) {
				// Scaling
				if (sw && ximg->xsize() > sw) ximg = ximg->scale(sw, 0);
				if (sh && ximg->ysize() > sh) ximg = ximg->scale(0, sh);

				// Fill
				int cx = (sw - ximg->xsize()) / 2;
				int cy = (sh - ximg->ysize()) / 2;

				Image.Image img2 = Image.Image(sw, sh, 255, 255, 255);
				img2->paste(ximg, cx, cy);

				ximg = img2;
			}

			frames += ({ ximg });
		}
	}
	else {
		Image.Image img = Image.ANY.decode(Stdio.read_file(fn));

		if (sw || sh) {
			// Scaling
			if (sw && img->xsize() > sw) img = img->scale(sw, 0);
			if (sh && img->ysize() > sh) img = img->scale(0, sh);

			// Fill
			int cx = (sw - img->xsize()) / 2;
			int cy = (sh - img->ysize()) / 2;

			Image.Image img2 = Image.Image(sw, sh, 255, 255, 255);
			img2->paste(img, cx, cy);

			img = img2;
		}

		frames += ({ img });
	}

	w = sw;
	h = sh;

	Image.Colortable colortable = Image.Colortable();

	if (colormode != 0) {
		multiset s = (< >);
		foreach (frames, Image.Image img) {
			for (int y = 0; y < h; y++) {
				for (int x = 0; x < w; x++) {
					img->setpixel(x, y, @rgb565r(@img->getpixel(x, y)));
				}
			}

			colortable->add(img);
		}
	}
	else {
		colortable->add(({
			({ 0, 0, 0 }),
			({ 255, 255, 255 }),
		}));
	}

	if (colormode == 0) {
		colortable = colortable->reduce(2);
	}
	else if (colormode == 1) {
		colortable = colortable->reduce(4);
	}
	else if (colormode == 2) {
		colortable = colortable->reduce(16);
	}
	else if (colormode == 3) {
		colortable = colortable->reduce(256);
	}

	colortable->nodither();
	Image.Image ct = colortable->image();
	mapping ctmap = ([ ]);

	// 0 = 1-bit global RGB565 palette (2 colors)
	// 1 = 2-bit global RGB565 palette (4 colors)
	// 2 = 4-bit global RGB565 palette (16 colors)
	// 3 = 8-bit global RGB565 palette (256 colors)
	// 4 = 1-bit local RGB565 palette (2 colors)
	// 5 = 2-bit local RGB565 palette (4 colors)
	// 6 = 4-bit local RGB565 palette (16 colors)
	// 7 = 8-bit local RGB565 palette (256 colors)
	// 255 = per-frame settings

	string res = sprintf("%c%c%c%c", sizeof(frames), w, h, colormode);

	for (int i = 0; i < ct->xsize(); i++) {
		ctmap[(string)ct->getpixel(i, 0)] = i;
		int c = rgb565(@ct->getpixel(i, 0));
		res += sprintf("%-2c", c);
	}

	int f = 0;
	foreach (frames, Image.Image img) {
		img = colortable->map(img);

		int n = 0;
		int m = 0;

		for (int y = 0; y < h; y++) {
			for (int x = 0; x < w; x++) {
				int c = ctmap[(string)img->getpixel(x, y)];

				if (colormode == 0) {
					m |= (c & 0b00000001) << n;
					n++;
				}
				else if (colormode == 1) {
					m |= (c & 0b00000011) << n;
					n += 2;
				}
				else if (colormode == 2) {
					m |= (c & 0b00001111) << n;
					n += 4;
				}
				else if (colormode == 3) {
					m |= (c & 0b11111111) << n;
					n += 8;
				}

				if (n == 8) {
					res += sprintf("%c", m);

					n = 0;
					m = 0;
				}
			}
		}
	}

	Stdio.write_file(argv[2], res);
}

array(int(8bit)) rgb565r(int(8bit) r, int(8bit) g, int(8bit) b) {
	return ({ r & 0xF8, g & 0xFC, b & 0xF8 });
}

int(16bit) rgb565(int(8bit) r, int(8bit) g, int(8bit) b) {
	return ((b & 0xF8) << 8) | ((g & 0xFC) << 3) | (r >> 3);
}
