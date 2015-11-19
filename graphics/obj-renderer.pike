#!/usr/bin/env pike

array(array(float)) a_v;
array(array(float)) a_vt;
array(array(float)) a_vn;
array(array(array(int))) a_f;

int listidx;

int main(int argc, array argv) {
	if (argc < 2) {
		werror("Usage: %s <obj-file>\n", basename(argv[0]));
		return 1;
	}

	Stdio.Stat fstat = file_stat(argv[1]);

	if (Stdio.is_file(argv[1] + ".cache")) {
		write("Loading cache for %s...\n", argv[1]);
		Stdio.File f = Stdio.File(argv[1] + ".cache");
		array a = array_sscanf(f->read(4 + 4 + 4), "%4c%4c%4c");
		if (a[0] == fstat->mtime && a[1] == fstat->size) {
			mapping m = decode_value(f->read(a[2]));
			a_v = m->vertices;
			a_vt = m->texcoords;
			a_vn = m->normals;
			a_f = m->faces;
		}
	}

	if (!a_v) {
		write("Reading: %s\n", argv[1]);
		array a = Stdio.read_file(argv[1]) / "\n";

		multiset blah = (< >);

		write("Processing...\n");
		a_v = ({ });
		a_vt = ({ });
		a_vn = ({ });
		a_f = ({ });
		foreach (a, string b) {
			array c = (b / " ") - ({ "" });

			if (glob("v * * *", b)) {
				a_v += ({ ({ (float)c[1], (float)c[2], (float)c[3] }) });
			}
			else if (glob("vt * *", b)) {
				a_vt += ({ ({ (float)c[1], (float)c[2] }) });
			}
			else if (glob("vn * * *", b)) {
				a_vn += ({ ({ (float)c[1], (float)c[2], (float)c[3] }) });
			}
			else if (glob("f * *", b)) {
				array r = ({ });

				foreach (c[1..], string d) {
					array e = d / "/";
					r += ({ map(e, lambda(string n) { return (int)n - 1; }) });
				}

				a_f += ({ r });
			}
			else {
				array c = b / " ";

				if (!blah[c[0]]) {
					blah[c[0]] = 1;
					write("Unhandled: %s\n", b);
				}
			}
		}

		a = ({ });
		gc();

		write("Generating cache data... ");
		string d = encode_value(([
			"vertices": a_v,
			"texcoords": a_vt,
			"normals": a_vn,
			"faces": a_f,
		]));
		write("OK (%s)\n", nicesize(sizeof(d)));

		write("Writing cache file... ");
		Stdio.File f = Stdio.File(argv[1] + ".cache", "crwt");
		f->write("%4c%4c%4c", fstat->mtime, fstat->size, sizeof(d));
		f->write(d);
		f->close();
		write("OK\n");
	}

	write("Vertices: %d - Faces: %d\n", sizeof(a_v), sizeof(a_f));

	write("Initializing OpenGL...\n");

	float aspect = 1280.0 / 720.0;
	mixed err = catch {
		GLUE.init(([
			"driver_names": GLUE.get_drivers(),
			"fullscreen": 0,
			"resolution": ({ 1280, 720 }),
			"aspect": aspect,
			"title": "OBJ-renderer",
			"fast_mipmap": 0,
		]));
	};

	if (err) {
		werror("FATAL: Couldn't initialize OpenGL!\n");
		return 1;
	}

	Pike.DefaultBackend(0.0);
	Pike.DefaultBackend(0.0);
	Pike.DefaultBackend(0.0);
	Pike.DefaultBackend(0.0);
	Pike.DefaultBackend(0.0);

	// Generate display list
	listidx = GL.glGenLists(1);
	if (!listidx) {
		werror("ERROR: Couldn't allocate display list - Error code: %d\n", GL.glGetError());
		return 1;
	}

	write("Compiling display list... ");
	GL.glNewList(listidx, GL.GL_COMPILE);
		foreach (a_f, array b) {
			GL.glBegin(GL.GL_POLYGON);
				foreach (b, array c) {
					if (sizeof(c) >= 3) GL.glNormal(@a_vn[c[2]]);
					GL.glVertex(@a_v[c[0]]);
				}
			GL.glEnd();
		}
	GL.glEndList();
	write("OK\n");

	GL.glEnable(GL.GL_CULL_FACE);
	GL.glEnable(GL.GL_DEPTH_TEST);
	GL.glEnable(GL.GL_COLOR_MATERIAL);
	GL.glEnable(GL.GL_LIGHTING);
	GL.glEnable(GL.GL_LIGHT0);
	GL.glEnable(GL.GL_LIGHT1);
	GL.glEnable(GL.GL_LIGHT2);

	GL.glDepthFunc(GL.GL_LEQUAL);
	GL.glShadeModel(GL.GL_SMOOTH);
	GL.glCullFace(GL.GL_BACK);

	GL.glClearColor(0.0, 0.0, 0.0, 0.0);
	GL.glColorMaterial(GL.GL_FRONT, GL.GL_AMBIENT_AND_DIFFUSE);

	float n = 0.0;
	int t = gethrtime();
	int fps = 0;
	while (true) {
		n++;

		GL.glViewport(0, 0, 1280, 720);
		GL.glClear(GL.GL_DEPTH_BUFFER_BIT | GL.GL_COLOR_BUFFER_BIT);

		GL.glMatrixMode(GL.GL_PROJECTION);
		GL.glLoadIdentity();
		GLU.gluPerspective(90.0, aspect, 0.001, 1000.0);

		GL.glMatrixMode(GL.GL_MODELVIEW);
		GL.glLoadIdentity();
		GLU.gluLookAt(
			cos(n / 200.0) * 4, 4.0, sin(n / 200.0) * 4,
			0.0, 0.0, 0.0,
			0.0, 1.0, 0.0);

		// Set-up lighting
		GL.glLightModel(GL.GL_LIGHT_MODEL_AMBIENT, ({ 0.1, 0.1, 0.1, 1.0 }));

		GL.glLight(GL.GL_LIGHT0, GL.GL_POSITION, ({ cos(n / 400.0) * 10.0, 20.0, sin(n / 400.0) * 10.0, 0.0 }));
		GL.glLight(GL.GL_LIGHT0, GL.GL_SPOT_DIRECTION, ({ 0.0, 0.0, 0.0, 0.0 }));
		GL.glLight(GL.GL_LIGHT0, GL.GL_DIFFUSE, ({ 0.3, 0.1, 0.5, 1.0 }));

		GL.glLight(GL.GL_LIGHT1, GL.GL_POSITION, ({ cos(n / 300.0) * 10.0, 18.0, sin(n / 300.0) * 10.0, 0.0 }));
		GL.glLight(GL.GL_LIGHT1, GL.GL_SPOT_DIRECTION, ({ 0.0, 0.0, 0.0, 0.0 }));
		GL.glLight(GL.GL_LIGHT1, GL.GL_DIFFUSE, ({ 0.5, 0.3, 0.1, 1.0 }));

		GL.glLight(GL.GL_LIGHT2, GL.GL_POSITION, ({ cos(n / 200.0) * 10.0, 16.0, sin(n / 200.0) * 10.0, 0.0 }));
		GL.glLight(GL.GL_LIGHT2, GL.GL_SPOT_DIRECTION, ({ 0.0, 0.0, 0.0, 0.0 }));
		GL.glLight(GL.GL_LIGHT2, GL.GL_DIFFUSE, ({ 0.1, 0.5, 0.3, 1.0 }));

		GL.glPolygonMode(GL.GL_FRONT, GL.GL_FILL);

		// Render objects
		render(n);

		// Swap buffers and stuff
		GL.glFlush();
		GLUE.swap_buffers();

		Pike.DefaultBackend(0.0);

		if (gethrtime() - t >= 1000000) {
			t = gethrtime();
			write("FPS: %d\n", fps);
			fps = 0;
		}

		fps++;
	}
}

void render(float n) {
	// Render ground
	GL.glColor(0.2, 0.7, 0.2, 1.0);
	GL.glPushMatrix();
		GL.glBegin(GL.GL_QUADS);
			GL.glNormal(0.0, 1.0, 0.0);
			GL.glTexCoord(0.0, 0.0);
			GL.glVertex(-20.0, 0.0, -20.0);
			GL.glTexCoord(4.0, 0.0);
			GL.glVertex(-20.0, 0.0,  20.0);
			GL.glTexCoord(4.0, 4.0);
			GL.glVertex( 20.0, 0.0,  20.0);
			GL.glTexCoord(0.0, 4.0);
			GL.glVertex( 20.0, 0.0, -20.0);
		GL.glEnd();
	GL.glPopMatrix();

	// Render model
	GL.glColor(0.025, 0.025, 0.025, 1.0);
	GL.glPushMatrix();
		GL.glScale(0.025, 0.025, 0.025);
		GL.glCallList(listidx);
	GL.glPopMatrix();
}

string nicesize(int s) {
	if (s >= 1024 * 1024 * 1000) return sprintf("%.1f GiB", s / 1024.0 / 1024.0 / 1024.0);
	else if (s >= 1024 * 1000) return sprintf("%.1f MiB", s / 1024.0 / 1024.0);
	else return sprintf("%.1f KiB", s / 1024.0);
}
