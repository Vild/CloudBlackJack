module common.network;

import common.sdl;
import derelict.sdl2.net;

import std.string;

import std.experimental.logger;

import std.zlib;

immutable string ip = "localhost";
immutable ushort port = 21_21_2;

shared static this() {
	DerelictSDL2Net.load();
}

class Client {
public:
	this() {
		SDLNet_Init();
		IPaddress ipaddress;
		SDLNet_ResolveHost(&ipaddress, ip.toStringz, port);

		_socket = SDLNet_TCP_Open(&ipaddress);
		_socketSet = SDLNet_AllocSocketSet(1);
		SDLNet_AddSocket(_socketSet, cast(SDLNet_GenericSocket)_socket);
	}

	~this() {
		SDLNet_FreeSocketSet(_socketSet);
		SDLNet_TCP_Close(_socket);
		SDLNet_Quit();
	}

	void recieve(SDL_Surface* surface) {
		while (!_isDead && SDLNet_CheckSockets(_socketSet, 0) > 0 && SDLNet_SocketReady(_socket)) {
			log(LogLevel.warning, "Reading frame!");
			//TODO: Zlib compress
			int length;
			int res = SDLNet_TCP_Recv(_socket, &length, cast(int)int.sizeof);
			if (res < int.sizeof) {
				_isDead = true;
				log(LogLevel.error, "isDead = true");
				return;
			}

			static ubyte[] data;
			data.length = length;

			res = SDLNet_TCP_Recv(_socket, data.ptr, length);
			if (res < length) {
				_isDead = true;
				log(LogLevel.error, "isDead = true");
				return;
			}

			size_t size = surface.pitch * surface.h;
			(cast(ubyte*)surface.pixels)[0 .. size] = (cast(ubyte[])data.uncompress())[];
		}
	}

	void send(const ref SDL_Keycode[] keys) {
		if (_isDead)
			return;

		log(LogLevel.warning, "Sending input...");

		size_t length = keys.length;
		int res = SDLNet_TCP_Send(_socket, &length, size_t.sizeof);
		if (res < size_t.sizeof) {
			_isDead = true;
			log(LogLevel.error, "isDead = true");
			return;
		}

		int size = cast(int)(keys.length * SDL_Keycode.sizeof);
		res = SDLNet_TCP_Send(_socket, keys.ptr, size);
		if (res < size) {
			_isDead = true;
			log(LogLevel.error, "isDead = true");
			return;
		}
	}

private:
	TCPsocket _socket;
	SDLNet_SocketSet _socketSet;
	bool _isDead;
}

class Server {
public:
	this() {
		SDLNet_Init();
		IPaddress ipaddress;
		SDLNet_ResolveHost(&ipaddress, null, port);
		_socket = SDLNet_TCP_Open(&ipaddress);
		assert(_socket);

		_serverSocketSet = SDLNet_AllocSocketSet(1);
		assert(_serverSocketSet);
		SDLNet_AddSocket(_serverSocketSet, cast(SDLNet_GenericSocket)_socket);
		_socketSet = SDLNet_AllocSocketSet(256);
		assert(_socketSet);
	}

	~this() {
		foreach (client; _clients)
			client.destroy;
		_clients.length = 0;

		SDLNet_FreeSocketSet(_socketSet);
		SDLNet_FreeSocketSet(_serverSocketSet);
		SDLNet_TCP_Close(_socket);
		SDLNet_Quit();
	}

	void doLoop() {
		import std.algorithm : remove;

		_clients = _clients.remove!((client) {
			if (!client._isDead)
				return false;
			client.destroy;
			return true;
		});

		log(LogLevel.warning, "doLoop...");
		while (SDLNet_CheckSockets(_serverSocketSet, 0) && SDLNet_SocketReady(_socket)) {
			log(LogLevel.warning, "\taccept()...");
			TCPsocket client = SDLNet_TCP_Accept(_socket);
			if (!client)
				break;

			_clients ~= new ServerClient(this, client);
		}

		if (SDLNet_CheckSockets(_socketSet, 0) > 0) {
			foreach (ServerClient client; _clients)
				if (SDLNet_SocketReady(client._socket)) {
					log(LogLevel.warning, "\t(", client._id, ").receive()...");
					client.receive();
				}
		}
	}

	@property ServerClient[] clients() {
		return _clients;
	}

private:
	TCPsocket _socket;
	SDLNet_SocketSet _serverSocketSet;
	SDLNet_SocketSet _socketSet;
	ServerClient[] _clients;
}

class ServerClient {
public:
	this(Server server, TCPsocket socket) {
		_id = _idCounter++;
		_server = server;
		_socket = socket;
		SDLNet_AddSocket(server._socketSet, cast(SDLNet_GenericSocket)socket);
	}

	~this() {
		SDLNet_DelSocket(_server._socketSet, cast(SDLNet_GenericSocket)_socket);
		SDLNet_TCP_Close(_socket);
	}

	void send(SDL_Surface* surface) {
		if (_isDead)
			return;

		log(LogLevel.warning, "Sending frame...");

		int size = surface.pitch * surface.h;
		ubyte[] data = compress((cast(ubyte*)surface.pixels)[0 .. size]);
		int length = cast(int)data.length;

		int res = SDLNet_TCP_Send(_socket, &length, int.sizeof);
		if (res < int.sizeof) {
			_isDead = true;
			log(LogLevel.error, _id, ": isDead = true");
			return;
		}

		res = SDLNet_TCP_Send(_socket, data.ptr, length);
		if (res < length) {
			_isDead = true;
			log(LogLevel.error, _id, ": isDead = true");
			return;
		}

		log(LogLevel.info, "\tdata.length: ", (data.length * 8) / 1000, " Kb");
	}

	void receive() {
		if (_isDead)
			return;

		log(LogLevel.warning, "Receiveing input...");
		size_t length;
		int res = SDLNet_TCP_Recv(_socket, &length, length.sizeof);
		if (res < length.sizeof) {
			_isDead = true;
			log(LogLevel.error, _id, ": isDead = true");
			return;
		}
		_keys.length = length;

		int size = cast(int)(length * SDL_Keycode.sizeof);
		res = SDLNet_TCP_Recv(_socket, _keys.ptr, size);
		if (res < size) {
			_isDead = true;
			log(LogLevel.error, _id, ": isDead = true");
			return;
		}
	}

	@property size_t id() {
		return _id;
	}

	@property ref SDL_Keycode[] keys() {
		return _keys;
	}

private:
	static size_t _idCounter;
	size_t _id;
	Server _server;
	TCPsocket _socket;
	bool _isDead;
	SDL_Keycode[] _keys;
}
