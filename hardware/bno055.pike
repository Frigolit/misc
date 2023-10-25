#!/usr/bin/env pike

// ======================================================================
// BNO055 data dumper (Linux sysfs)
// Licensed under the MIT license - See LICENSE for more information
// ======================================================================
// This is a fairly quickly hacked together program to dump and visualise
// data from a BNO055 sensor.
// It applies a 3-sample median filter on all channels.
// This has mainly been tested on a Raspberry Pi 4 with the I2C bus
// running at 10MHz.
//
// Example for mapping a BNO055 chip via I2C (address 0x28):
// # echo "bno055 0x28" > /sys/bus/i2c/devices/i2c-1/new_device
// ======================================================================

#define STREAM_LENGTH 128

int main() {
	string device_path;

	if (!Stdio.is_dir("/sys/bus/iio/devices")) {
		werror("ERROR: Industrial I/O sysfs interface not available.\n");
		return 1;
	}

	array a = get_dir("/sys/bus/iio/devices");
	foreach (a, string b) {
		string p = combine_path("/sys/bus/iio/devices", b);
		if (String.trim_all_whites(Stdio.read_file(combine_path(p, "name"))) == "bno055") {
			device_path = p;
			break;
		}
	}

	if (!device_path) {
		werror("ERROR: Couldn't find a BNO055 chip mapped in IIO.\n");
		return 1;
	}

	string cal_data = Stdio.read_file(combine_path(device_path, "calibration_data"));
	int b_cal_accel = (int)Stdio.read_file(combine_path(device_path, "in_accel_calibration_auto_status"));
	int b_cal_gyro = (int)Stdio.read_file(combine_path(device_path, "in_gyro_calibration_auto_status"));
	int b_cal_magn = (int)Stdio.read_file(combine_path(device_path, "in_magn_calibration_auto_status"));
	int ts_cal_data = time();

	bool first = true;

	mapping cal_colour_map = ([
		1: 31,
		2: 33,
		3: 33,
		4: 32,
	]);

	array sensornames = ({
		"accel_linear_x", "accel_linear_y", "accel_linear_z",
		"accel_x", "accel_y", "accel_z",
		"anglvel_x", "anglvel_y", "anglvel_z",
		"gravity_x", "gravity_y", "gravity_z",
		"magn_x", "magn_y", "magn_z",
		"rot_pitch", "rot_yaw", "rot_roll",
	});

	mapping vectors = ([
		"accel_linear": ([
			"caption": "Linear acceleration",
			"sensor_prefix": "accel_linear_",
		]),
		"accel": ([
			"caption": "Accelerometer",
			"sensor_prefix": "accel_",
		]),
		"anglvel": ([
			"caption": "Angular velocity",
			"sensor_prefix": "anglvel_"
		]),
		"gravity": ([
			"caption": "Gravity",
			"sensor_prefix": "gravity_",
		]),
		"magn": ([
			"caption": "Magnetometer",
			"sensor_prefix": "magn_",
		]),
		"rot": ([
			"caption": "Rotation",
			"sensors": ({ "rot_pitch", "rot_yaw", "rot_roll" }),
		]),
	]);

	mapping sensors = ([ ]);

	foreach (sensornames, string n) {
		string scale_path = combine_path(device_path, "in_" + n + "_scale");
		if (!Stdio.is_file(scale_path)) {
			scale_path = combine_path(device_path, "in_" + ((n / "_")[0..<1] * "_") + "_scale");
		}

		sensors[n] = ([
			"scale": Stdio.is_file(scale_path) ? (float)Stdio.read_file(scale_path) : 1.0,
		]);
	}

	foreach (values(vectors), mapping v) {
		if (v->sensor_prefix) {
			v->x = sensors[v->sensor_prefix + "x"];
			v->y = sensors[v->sensor_prefix + "y"];
			v->z = sensors[v->sensor_prefix + "z"];
		}
		else {
			v->x = sensors[v->sensors[0]];
			v->y = sensors[v->sensors[1]];
			v->z = sensors[v->sensors[2]];
		}
	}

	write("\e[2J\e[1;1H\e[?25l");

	int ts, ts2;

	while (true) {
		// Read data
		foreach (sensors; string n; mapping s) {
			s->buffer = ({ });
		}

		array(int) a_t_data_inner_ms = ({ });

		ts = System.Time(1)->usec_full;
		for (int i = 0; i < 3; i++) {
			foreach (sensors; string n; mapping s) {
				ts2 = System.Time(1)->usec_full;
				s->buffer += ({ (float)Stdio.read_file(combine_path(device_path, "in_" + n + "_raw")) });
				a_t_data_inner_ms += ({ (System.Time(1)->usec_full - ts2) / 1000.0 });
			}

			sleep(0.002);
		}

		float t_data_ms = (System.Time(1)->usec_full - ts) / 1000.0;
		float t_data_inner_ms = Array.sum(a_t_data_inner_ms) / (float)sizeof(a_t_data_inner_ms);

		if (first) {
			first = false;

			foreach (values(sensors), mapping s) {
				s->stream = allocate(STREAM_LENGTH, s->value);
			}
		}

		foreach (values(sensors), mapping s) {
			sort(s->buffer);
			s->value = (int)s->buffer[1];
			s->stream = s->stream[1..] + ({ s->value });

			s->buffer = UNDEFINED;
		}

		if (time() - ts_cal_data > 5) {
			cal_data = Stdio.read_file(combine_path(device_path, "calibration_data"));
			b_cal_accel = (int)Stdio.read_file(combine_path(device_path, "in_accel_calibration_auto_status"));
			b_cal_gyro = (int)Stdio.read_file(combine_path(device_path, "in_gyro_calibration_auto_status"));
			b_cal_magn = (int)Stdio.read_file(combine_path(device_path, "in_magn_calibration_auto_status"));

			ts_cal_data = time();
		}

		// Print
		write("\e[1;1H");
		foreach (sort(indices(vectors)), string n) {
			mapping vec = vectors[n];
			write(
				"%-20s    \e[34;1m%7.1f\e[0m %s    \e[34;1m%7.1f\e[0m %s    \e[34;1m%7.1f\e[0m %s\n",
				vec->caption,
				vec->x->value * vec->x->scale, drawmetric(vec->x->value * vec->x->scale),
				vec->y->value * vec->y->scale, drawmetric(vec->y->value * vec->y->scale),
				vec->z->value * vec->z->scale, drawmetric(vec->z->value * vec->z->scale),
			);
		}
		write("\n");

		draw_metric_array("Linear X", sensors["accel_linear_x"]->stream, 32.0, true);
		draw_metric_array("Linear Y", sensors["accel_linear_y"]->stream, 32.0, true);
		draw_metric_array("Linear Z", sensors["accel_linear_z"]->stream, 32.0, true);
		write("\n");

		draw_metric_array("Accel X ", sensors["accel_x"]->stream, 16.0, true);
		draw_metric_array("Accel Y ", sensors["accel_y"]->stream, 16.0, true);
		draw_metric_array("Accel Z ", sensors["accel_z"]->stream, 16.0, true);
		write("\n");

		write("Calibration data:   \e[34;1m%s\e[0m\n", (String.string2hex(cal_data) / 2) * " ");
		write(
			"Calibration status: [\e[%d;1mAccelerometer\e[0m] [\e[%d;1mGyroscope\e[0m] [\e[%d;1mMagnetometer\e[0m]\n",
			cal_colour_map[b_cal_accel],
			cal_colour_map[b_cal_gyro],
			cal_colour_map[b_cal_magn]
		);
		write("\n");

		write("Data acquisition:   \e[34;1m%6.1fms    %6.1fms\e[0m\n", t_data_ms, t_data_inner_ms);

		sleep(0.01);
	}
}

string nicesize(int|float s) {
	if (s >= 1024 * 1024 * 1000) {
		return sprintf("%.1f GiB", s / 1024.0 / 1024.0 / 1024.0);
	}
	else if (s >= 1024 * 1000) {
		return sprintf("%.1f MiB", s / 1024.0 / 1024.0);
	}
	else if (s >= 1000) {
		return sprintf("%.1f KiB", s / 1024.0);
	}
	else {
		return sprintf("%d B", (int)s);
	}
}

string drawmetric(int|float n) {
	int x = (int)(((n / 360.0) / 2.0 + 0.5) * 32.0);
	if (x < 0) { x = 0; }
	else if (x > 31) { x = 31; }

	return "[\e[30;1m" + ("-" * (x)) + "\e[32;1m|\e[0m\e[30;1m" + ("-" * (32 - x)) + "\e[0m]";
}

void draw_metric_array(string caption, array(int) data, float scale, bool|void autocenter) {
	int sz = sizeof(data);
	int lv = 0;

	float center = 0.0;
	if (autocenter) {
		array a = copy_value(data);
		sort(a);
		center = (float)Array.sum(a[sz / 2 - 2..sz / 2 + 2]) / 5.0;
	}

	write("\e[0m%s [\e[48:5:0m", caption);
	for (int x = 0; x < sz; x++) {
		int v = (int)(((data[x] - center) / scale) * 255.0);

		if (v < -255) { v = -255; }
		else if (v > 255) { v = 255; }

		if (v != lv) {
			if (v > 0) {
				write("\e[48;2;%d;0;0m", v);
			}
			else if (v < 0) {
				write("\e[48;2;0;0;%dm", -v);
			}
			else {
				write("\e[48:5:0m");
			}

			lv = v;
		}

		write(" ");
	}
	write("\e[0m] %8.1f\n", center);
}
