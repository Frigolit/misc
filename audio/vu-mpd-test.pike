#!/usr/bin/env pike

/*
VU meter test using FIFO output from Music Player Daemon (MPD).

Licensed under the MIT license - See LICENSE for more information
Copyright (C) 2015 Pontus Rodling - http://frigolit.net/
*/

#define SAMPLES 735

string mpd_fifo_path = "/tmp/mpd.fifo";

int main(int argc, array argv) {
	int n_maxval = pow(2, 16) - 1;

	array dbrange = ({ 0.0, -1.0, -2.0, -3.0, -4.0, -8.0, -12.0, -20.0 });

	Stdio.File f = Stdio.File(mpd_fifo_path, "r");

	write("\e[2J\e[1;1H\e[?25l");
	write("\e[1;34m         Impact linear                    Impact log TPPM log   TPPM ~log");

	int t = gethrtime();

	int n;
	int p;
	int tppm_left = 0;
	int tppm_left_last = -1;
	int tppm_right = 0;
	int tppm_right_last = -1;
	int power_left = 0;
	int power_right = 0;

	int last_sample_left = 0;
	int last_sample_right = 0;

	while (true) {
		string d = f->read(SAMPLES * 4);		// x4 = 16-bit * 2 channels

		for (int i = 0; i < SAMPLES; i++) {
			// Left
			p = i * 4;
			sscanf(d[p..p+1], "%-+2c", n);

			int x = abs(n - last_sample_left);
			if (x > power_left) {
				power_left = x;
				t = gethrtime();
			}
			last_sample_left = n;

			n = abs(n) * 2;

			if (n > tppm_left) {
				tppm_left = n;
				t = gethrtime();
			}

			// Right
			sscanf(d[p+2..p+3], "%-+2c", n);

			x = abs(n - last_sample_right);
			if (x > power_right) {
				power_right = x;
				t = gethrtime();
			}
			last_sample_right = n;

			n = abs(n) * 2;

			if (n > tppm_right) {
				tppm_right = n;
				t = gethrtime();
			}
		}

		if (gethrtime() - t > 1000) {
			tppm_left = (int)floor(tppm_left / 1.05);
			tppm_right = (int)floor(tppm_right / 1.05);
			power_left = (int)floor(power_left / 1.2);
			power_right = (int)floor(power_right / 1.2);
		}

		//if (tppm_left != tppm_left_last || tppm_right != tppm_right_last) {
			write("\e[3;1H\e[1;37m");

			if (/*tppm_left*/power_left) {
				int p_left = (int)(30 * ((float)/*tppm_left*/power_left / 65535.0));
				float db_left = 10 * Math.log10((float)/*tppm_left*/power_left / 65535.0);
				string uv_left_log = build_log_uv(tppm_left);
				string uv_left_ilog = build_ilog_uv(tppm_left);

				string p_left_str = "\u25aa" * p_left;
				//string pwr_left = "\u25aa" * (int)(8 * ((float)power_left / 65536.0));
				string pwr_left = build_log_uv(power_left);

				write(string_to_utf8(sprintf("%6.1fdB [\e[32m%-20s\e[31m%-10s\e[37m] [\e[32m%-8s\e[37m] [\e[32m%-8s\e[37m] [\e[32m%-8s\e[37m]\n", db_left, p_left_str[0..19], p_left_str[20..29], pwr_left, uv_left_log, uv_left_ilog)));
			}
			else write(" -Inf dB [                              ] [        ] [        ] [        ]\n");

			if (/*tppm_right*/power_right) {
				int p_right = (int)(30 * ((float)/*tppm_right*/power_right / 65535.0));
				float db_right = 10 * Math.log10((float)/*tppm_right*/power_right / 65535.0);
				string uv_right_log = build_log_uv(tppm_right);
				string uv_right_ilog = build_ilog_uv(tppm_right);

				string p_right_str = "\u25aa" * p_right;
				//string pwr_right = "\u25aa" * (int)(8 * ((float)power_right / 65536.0));
				string pwr_right = build_log_uv(power_right);

				write(string_to_utf8(sprintf("%6.1fdB [\e[32m%-20s\e[31m%-10s\e[37m] [\e[32m%-8s\e[37m] [\e[32m%-8s\e[37m] [\e[32m%-8s\e[37m]\n", db_right, p_right_str[0..19], p_right_str[20..29], pwr_right, uv_right_log, uv_right_ilog)));
			}
			else write(" -Inf dB [                              ] [        ] [        ] [        ]\n");

			tppm_left_last = tppm_left;
			tppm_right_last = tppm_right;
		//}
	}
}

string build_log_uv(int v) {
	string c = "\u25aa";
	string uv = "";
	if (v >=   655) uv += c;
	if (v >=  4134) uv += c;
	if (v >= 10386) uv += c;
	if (v >= 26089) uv += c;
	if (v >= 32845) uv += c;
	if (v >= 41349) uv += c;
	if (v >= 52056) uv += c;
	if (v >= 64500) uv += c;
	return uv;
}

string build_ilog_uv(int v) {
	string c = "\u25aa";
	string uv = "";
	if (v >= 16384) uv += c;
	if (v >= 32768) uv += c;
	if (v >= 49152) uv += c;
	if (v >= 57344) uv += c;
	if (v >= 61440) uv += c;
	if (v >= 63488) uv += c;
	if (v >= 64512) uv += c;
	if (v >= 65024) uv += c;
	return uv;
}

/*
  0dB    1.000        16777215    ||||||||||||||||||||||||||||||||||||||||||||||||||||||||||||||||||||||||||||||||||||||||||||||||||||||||||||||||||||||||||||||||||||||||||||||||||||||||||||||||||||||||||||||||||||||||||||||||||||||||
 -1dB    0.794        13326615    ||||||||||||||||||||||||||||||||||||||||||||||||||||||||||||||||||||||||||||||||||||||||||||||||||||||||||||||||||||||||||||||||||||||||||||||||||||||||||||||
 -2dB    0.631        10585707    ||||||||||||||||||||||||||||||||||||||||||||||||||||||||||||||||||||||||||||||||||||||||||||||||||||||||||||||||||||||||||||||
 -3dB    0.501         8408525    ||||||||||||||||||||||||||||||||||||||||||||||||||||||||||||||||||||||||||||||||||||||||||||||||||||
 -4dB    0.398         6679129    |||||||||||||||||||||||||||||||||||||||||||||||||||||||||||||||||||||||||||||||
 -8dB    0.158         2659009    |||||||||||||||||||||||||||||||
-12dB    0.063         1058570    ||||||||||||
-20dB    0.010          167772    ||
*/
