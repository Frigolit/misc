array(float) HSVtoRGB(float h, float s, float v) {
	int i;
	float f, p, q, t;
	if (!s) {
		return ({ v, v, v });
	}

	h /= 60;
	i = (int)h;
	f = h - i;    // factorial part of h
	p = v * (1 - s);
	q = v * (1 - s * f);
	t = v * (1 - s * (1 - f));

	switch (i) {
		case 0:
			return ({ v, t, p });
		case 1:
			return ({ q, v, p });
		case 2:
			return ({ p, v, t });
		case 3:
			return ({ p, q, v });
		case 4:
			return ({ t, p, v });
		default:
			return ({ v, p, q });
	}
}
