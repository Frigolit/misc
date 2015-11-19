mapping parse_response(string d) {
	string pkt_type = d[0..3];

	if (pkt_type == "\xFF\xFF\xFF\xFF") {
		if (d[4] != 'I') return UNDEFINED;
		int protocol_version = d[5];
		d = d[6..];

		Stdio.FakeFile f = Stdio.FakeFile(d);

		string name = read_null_string(f);
		string map = read_null_string(f);
		string folder = read_null_string(f);
		string game = read_null_string(f);
		int appid = f->read(1)[0] | (f->read(1)[0] << 8);
		int players = f->read(1)[0];
		int maxplayers = f->read(1)[0];

		return ([
			"name": name,
			"map": map,
			"folder": folder,
			"game": game,
			"appid": appid,
			"players": players,
			"maxplayers": maxplayers,
		]);
	}
	else {
		werror("Unhandled packet type: %s\n", String.string2hex(pkt_type));
	}
}

string read_null_string(Stdio.File f) {
	string r = "";
	string c;
	while ((c = f->read(1)) != "\0") r += c;
	return r;
}

/*
Header 	byte 	Always equal to 'I' (0x49.)
Protocol 	byte 	Protocol version used by the server.
Name 	string 	Name of the server.
Map 	string 	Map the server has currently loaded.
Folder 	string 	Name of the folder containing the game files.
Game 	string 	Full name of the game.
ID 	short 	Steam Application ID of game.
Players 	byte 	Number of players on the server.
Max. Players 	byte 	Maximum number of players the server reports it can hold.
Bots 	byte 	Number of bots on the server.
Server type 	byte 	Indicates the type of server:

    'd' for a dedicated server
    'l' for a non-dedicated server
    'p' for a SourceTV relay (proxy)

Environment 	byte 	Indicates the operating system of the server:

    'l' for Linux
    'w' for Windows
    'm' or 'o' for Mac (the code changed after L4D1)

Visibility 	byte 	Indicates whether the server requires a password:

    0 for public
    1 for private

VAC 	byte 	Specifies whether the server uses VAC:

    0 for unsecured
    1 for secured

These fields only exist in a response if the server is running The Ship:
Data 	Type 	Comment
Mode 	byte 	Indicates the game mode:

    0 for Hunt
    1 for Elimination
    2 for Duel
    3 for Deathmatch
    4 for VIP Team
    5 for Team Elimination

Witnesses 	byte 	The number of witnesses necessary to have a player arrested.
Duration 	byte 	Time (in seconds) before a player is arrested while being witnessed.
Version 	string 	Version of the game installed on the server.
Extra Data Flag (EDF) 	byte 	If present, this specifies which additional data fields will be included.
Only if if ( EDF & 0x80 ) proves true:
Data 	Type 	Comment
Port 	short 	The server's game port number.
Only if if ( EDF & 0x10 ) proves true:
Data 	Type 	Comment
SteamID 	long long 	Server's SteamID.
Only if if ( EDF & 0x40 ) proves true:
Data 	Type 	Comment
Port 	short 	Spectator port number for SourceTV.
Name 	string 	Name of the spectator server for SourceTV.
Only if if ( EDF & 0x20 ) proves true:
Data 	Type 	Comment
Keywords 	string 	Tags that describe the game according to the server (for future use.)
Only if if ( EDF & 0x01 ) proves true:
Data 	Type 	Comment
GameID 	long long 	The server's 64-bit GameID. If this is present, a more accurate AppID is present in the low 24 bits. The earlier AppID could have been truncated as it was forced into 16-bit storage. 
*/
