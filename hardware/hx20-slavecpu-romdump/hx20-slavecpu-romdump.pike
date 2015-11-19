#!/usr/bin/env pike

/*
Epson HX-20 Slave CPU ROM dumping utility

This injects a payload into the slave CPUs memory and executes it. This was more fun (and faster) than using the read command in the slave CPU to extract the ROM.
If "payload.bin" is unavailable it will be assembled using AS02.

Usage:
1. Remove the Master CPU from the motherboard.
2. Hook up the serial pins in the socket to a serial port (currently hardcoded to ttyUSB0).
3. Run this program and it'll attempt to inject the payload, extract the slave CPU Mask ROM and save it to "rom.bin".
*/

Stdio.File serial;

int main(int argc, array argv) {
	serial = Stdio.File("/dev/ttyUSB0", "rw");
	serial->tcsetattr(([
		"ICANON": 0,
		"ECHO": 0,
		"ECHOE": 0,
		"IEXTEN": 0,
		"ISIG": 0,
		"VTIME": 0,
		"VINTR": 0,
		"VMIN": 0,
		"BRKINT": 0,
		"INPCK": 0,
		"ISTRIP": 0,
		"IXON": 0,
		"IUCLC": 0,
		"IXANY": 0,
		"ICRNL": 0,
		"INLCR": 0,
		"IPOST": 0,
		"OPOST": 0,
		"OLCUC": 0,
		"ONLCR": 0,
		"OCRNL": 0,
		"ONLRET": 0,
		"OFDEL": 0,
		"ispeed": 38400,
		"ospeed": 38400,
		"csize": 8,
	]));

	// Assemble payload
	if (!Stdio.is_file("payload.bin") || file_stat("payload.s")->mtime > file_stat("payload.bin")->mtime) {
		write("Assembling \"payload.s\"... ");
		mapping m = Process.run("as02 -opayload.bin payload.s");
		if (m->exitcode) {
			write("FAILED\n");
			werror(m->stderr);
			exit(1);
		}

		write("OK\n");
	}

	// Load payload
	write("Reading \"payload.bin\"... ");
	string payload = Stdio.read_file("payload.bin");
	write("%d byte(s)\n", sizeof(payload));
	if (sizeof(payload) > 64) {
		werror("ERROR: Payload is larger than 64 bytes\n");
		return 1;
	}

	// Initialize CPU
	while (serial->read(32) != "") { }

	write("Initializing slave CPU... ");
	serial->write("\x00");
	wait_for_ack();
	serial->write("\x02");
	wait_for_ack();
	serial->write("\x01");
	wait_for_ack();
	serial->write("\x00");
	wait_for_ack();
	write("OK\n");

	// Open command mask
	write("Enabling special commands... ");
	serial->write("\x03");
	wait_for_ack();
	serial->write("\xAA");
	wait_for_ack();
	write("OK\n");

	// Upload payload
	for (int i = 0; i < sizeof(payload); i++) {
		write("\rWriting payload to RAM... %.0f%%", ((float)i / (sizeof(payload) - 1)) * 100.0);
		write_memory(0x00B8 + i, payload[i]);
	}
	write("\n");

	// Execute payload
	write("Jumping to payload (0x00B8)... ");
	set_pc(0x00B8);
	write("OK\n");

	string rom = "";
	while (sizeof(rom) < 4096) {
		write("\rReceiving ROM... %.1f%%", (sizeof(rom) / 4096.0) * 100.0);

		rom += read_byte();
		int c = read_byte()[0];

		if ((rom[-1] ^ 0xFF) != c) {
			werror("\nERROR: Checksum failed at 0x%04X - %02X ^ FF (= %02X) != %02X\n", sizeof(rom) - 1, rom[-1], rom[-1] ^ 0xFF, c);
			exit(1);
		}
	}
	write("\n");

	if (read_byte() + read_byte() != "OK") {
		werror("ERROR: Incorrect trailer\n");
		exit(1);
	}

	if (serial->peek(1)) serial->read(32);

	write("Waiting for reset... ");
	serial->write("\x00");
	wait_for_ack();
	serial->write("\x03");
	wait_for_ack();
	serial->write("\xAA");
	wait_for_ack();
	write("OK\n");
	write("\n");

	write("ROM dump successful!\n");
	Stdio.write_file("rom.bin", rom);
	return 0;
}

void set_pc(int addr) {
	if (addr < 0 || addr > 65535) throw(({ "Address is out of range\n", backtrace() }));

	serial->write("\x0B");
	wait_for_ack();

	serial->write("%c", addr >> 8);
	wait_for_ack();

	serial->write("%c", addr & 0xFF);
	wait_for_ack();
}

string read_memory(int addr) {
	if (addr < 0 || addr > 65535) throw(({ "Address is out of range\n", backtrace() }));

	serial->write("\x05");
	wait_for_ack();

	serial->write("%c", addr >> 8);
	wait_for_ack();

	serial->write("%c", addr & 0xFF);
	return read_byte(1);
}

void write_memory(int addr, int c) {
	if (addr < 0 || addr > 65535) throw(({ "Address is out of range\n", backtrace() }));
	if (c < 0 || c > 255) throw(({ "Data is out of range\n", backtrace() }));

	serial->write("\x06");
	wait_for_ack();

	serial->write("%c", addr >> 8);
	wait_for_ack();

	serial->write("%c", addr & 0xFF);
	wait_for_ack();

	serial->write("%c", c);
	wait_for_ack();
}

string read_byte(int|void timeout) {
	if (!serial->peek(timeout || 3)) {
		werror("Timeout\n");
		exit(1);
	}

	string r = serial->read(1);
	if (r == "") throw(({ "Read an empty string\n", backtrace() }));
	return r;
}

void wait_for_ack() {
	string d = read_byte();

	if (d == "\x01") return;
	else if (d == "") {
		werror("ERROR: Received empty string\n");
		exit(1);
	}
	else {
		werror("ERROR: Unexpected result: %02X\n", d[0]);
		exit(1);
	}
}
