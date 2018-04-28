module common.network;

import common.sdl;
import derelict.sdl2.net;

import std.string;
import std.zlib;
import std.typecons;
import std.experimental.logger;

immutable ushort port = 21212;

class NetworkClient {
public:
	this(string ip) {
		IPaddress ipaddress;
		SDLNet_ResolveHost(&ipaddress, ip.toStringz, port);

		_socket = SDLNet_TCP_Open(&ipaddress);
		assert(_socket);
		_socketSet = SDLNet_AllocSocketSet(1);
		assert(_socketSet);
		SDLNet_AddSocket(_socketSet, cast(SDLNet_GenericSocket)_socket);
	}

	~this() {
		SDLNet_FreeSocketSet(_socketSet);
		SDLNet_TCP_Close(_socket);
	}

	void recieve(SDL_Surface* surface) {
		while (!_isDead && SDLNet_CheckSockets(_socketSet, 0) > 0 && SDLNet_SocketReady(_socket)) {
			//TODO: Zlib compress
			int dataLength;
			int res = SDLNet_TCP_Recv(_socket, &dataLength, cast(int)int.sizeof);
			if (res < int.sizeof) {
				_isDead = true;
				return;
			}

			int originalLength;
			res = SDLNet_TCP_Recv(_socket, &originalLength, cast(int)int.sizeof);
			if (res < int.sizeof) {
				_isDead = true;
				return;
			}

			static ubyte[] data;
			data.length = dataLength;

			res = SDLNet_TCP_Recv(_socket, data.ptr, dataLength);
			if (res < dataLength) {
				_isDead = true;
				return;
			}

			size_t size = surface.pitch * surface.h;
			(cast(ubyte*)surface.pixels)[0 .. size] = (cast(ubyte[])data.uncompress(originalLength))[];
		}
	}

	void send(const SDL_Keycode[] keys) {
		if (_isDead)
			return;

		size_t length = keys.length;
		int res = SDLNet_TCP_Send(_socket, &length, size_t.sizeof);
		if (res < size_t.sizeof) {
			_isDead = true;
			return;
		}

		int size = cast(int)(keys.length * SDL_Keycode.sizeof);
		res = SDLNet_TCP_Send(_socket, keys.ptr, size);
		if (res < size) {
			_isDead = true;
			return;
		}
	}

	@property bool isDead() {
		return _isDead;
	}

private:
	TCPsocket _socket;
	SDLNet_SocketSet _socketSet;
	bool _isDead;
}

class NetworkServer {
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

	/// Returns: The clients that are removed!
	Tuple!(size_t[], "removeList", NetworkServerClient[], "addedList") doLoop() {
		import std.algorithm : remove;

		size_t[] removeList;
		NetworkServerClient[] addedList;

		_clients = _clients.remove!((client) {
			if (!client._isDead)
				return false;
			removeList ~= client.id;
			client.destroy;
			return true;
		});

		while (SDLNet_CheckSockets(_serverSocketSet, 0) && SDLNet_SocketReady(_socket)) {
			TCPsocket client = SDLNet_TCP_Accept(_socket);
			if (!client)
				break;

			_clients ~= new NetworkServerClient(this, client);
			addedList ~= _clients[$ - 1];
		}

		if (SDLNet_CheckSockets(_socketSet, 0) > 0) {
			foreach (NetworkServerClient client; _clients)
				if (SDLNet_SocketReady(client._socket))
					client.receive();
		}
		return typeof(return)(removeList, addedList);
	}

	@property NetworkServerClient[] clients() {
		return _clients;
	}

private:
	TCPsocket _socket;
	SDLNet_SocketSet _serverSocketSet;
	SDLNet_SocketSet _socketSet;
	NetworkServerClient[] _clients;
}

class NetworkServerClient {
public:
	this(NetworkServer server, TCPsocket socket) {
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

		int size = surface.pitch * surface.h;
		ubyte[] data = compress((cast(ubyte*)surface.pixels)[0 .. size]);
		int dataLength = cast(int)data.length;

		int res = SDLNet_TCP_Send(_socket, &dataLength, int.sizeof);
		if (res < int.sizeof) {
			_isDead = true;
			return;
		}

		res = SDLNet_TCP_Send(_socket, &size, int.sizeof);
		if (res < int.sizeof) {
			_isDead = true;
			return;
		}

		res = SDLNet_TCP_Send(_socket, data.ptr, dataLength);
		if (res < dataLength) {
			_isDead = true;
			return;
		}

		import std.format : format;

		// log(LogLevel.info, "\trealSize: ", (size * 8) / 1000, "Kbit, compressSize: ", (data.length * 8) / 1000, " Kbit.\t ", format("%.2f", (data.length * 100.0f) / size), "% of the original size");
	}

	void receive() {
		if (_isDead)
			return;

		size_t length;
		int res = SDLNet_TCP_Recv(_socket, &length, length.sizeof);
		if (res < length.sizeof) {
			_isDead = true;
			return;
		}
		_keys.length = length;

		int size = cast(int)(length * SDL_Keycode.sizeof);
		res = SDLNet_TCP_Recv(_socket, _keys.ptr, size);
		if (res < size) {
			_isDead = true;
			return;
		}
	}

	@property size_t id() {
		return _id;
	}

	@property ref SDL_Keycode[] keys() {
		return _keys;
	}

	@property bool isDead() {
		return _isDead;
	}

private:
	static size_t _idCounter;
	size_t _id;
	NetworkServer _server;
	TCPsocket _socket;
	bool _isDead;
	SDL_Keycode[] _keys;
}
