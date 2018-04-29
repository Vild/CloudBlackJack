module common.network;

import common.sdl;
import derelict.sdl2.net;

import std.string;
import std.zlib;
import std.typecons;
import std.experimental.logger;

immutable ushort port = 21212;

private bool /* isDead */ readTCP(T)(ref TCPsocket socket, ref T[] data) {
	return readTCP(socket, cast(ubyte*)data.ptr, cast(int)(data.length * T.sizeof));
}

private bool /* isDead */ readTCP(T)(ref TCPsocket socket, ref T data) if (!is(T : E[], E)) {
	return readTCP(socket, cast(ubyte*)&data, cast(int)T.sizeof);
}

private bool /* isDead */ readTCP(ref TCPsocket socket, ubyte* data, int length) {
	int res;
	do {
		res = SDLNet_TCP_Recv(socket, data, length);
		if (res == 0)
			return true;
		length -= res;
		data += res;
	}
	while (length > 0);
	return false;
}

private bool /* isDead */ sendTCP(T)(ref TCPsocket socket, ref inout(T[]) data) {
	return sendTCP(socket, cast(inout(ubyte)*)data.ptr, cast(int)(data.length * T.sizeof));
}

private bool /* isDead */ sendTCP(T)(ref TCPsocket socket, ref T data) if (!is(T : E[], E)) {
	return sendTCP(socket, cast(ubyte*)&data, cast(int)T.sizeof);
}

private bool /* isDead */ sendTCP(ref TCPsocket socket, const ubyte* data, int length) {
	return SDLNet_TCP_Send(socket, data, length) != length;
}

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
			if (readTCP(_socket, dataLength)) {
				_isDead = true;
				log(LogLevel.error, "isDead = true");
				return;
			}

			int originalLength;
			if (readTCP(_socket, originalLength)) {
				_isDead = true;
				log(LogLevel.error, "isDead = true");
				return;
			}

			static ubyte[] data;
			data.length = dataLength;
			if (readTCP(_socket, data)) {
				_isDead = true;
				log(LogLevel.error, "isDead = true");
				return;
			}

			size_t size = surface.pitch * surface.h;
			auto netData = data.uncompress(originalLength);
			scope (exit)
				netData.destroy;
			(cast(ubyte*)surface.pixels)[0 .. size] = (cast(ubyte[])netData)[];
		}
	}

	void send(const SDL_Keycode[] keys) {
		if (_isDead)
			return;

		size_t length = keys.length;
		if (sendTCP(_socket, length)) {
			_isDead = true;
			log(LogLevel.error, "isDead = true");
			return;
		}
		if (sendTCP(_socket, keys)) {
			_isDead = true;
			log(LogLevel.error, "isDead = true");
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
	size_t sentBytes;

	this(NetworkServer server, TCPsocket socket) {
		_id = _idCounter++;
		_server = server;
		_socket = socket;
		SDLNet_AddSocket(server._socketSet, cast(SDLNet_GenericSocket)socket);
	}

	~this() {
		_sendBuffer.destroy;
		SDLNet_DelSocket(_server._socketSet, cast(SDLNet_GenericSocket)_socket);
		SDLNet_TCP_Close(_socket);
	}

	void send(SDL_Surface* surface) {
		if (_isDead)
			return;

		int size = surface.pitch * surface.h;
		ubyte[] data = compress((cast(ubyte*)surface.pixels)[0 .. size]);
		scope (exit)
			data.destroy;
		_sendBuffer.length = data.length + int.sizeof * 2;

		(cast(int*)_sendBuffer.ptr)[0] = cast(int)data.length;
		(cast(int*)_sendBuffer.ptr)[1] = size;
		_sendBuffer[int.sizeof * 2 .. $] = data[0 .. $];

		if (sendTCP(_socket, _sendBuffer)) {
			_isDead = true;
			log(LogLevel.error, "isDead = true");
			return;
		}

		//import std.format : format;

		//log(LogLevel.info, "\trealSize: ", (size * 8) / 1000, "Kbit, compressSize: ", (data.length * 8) / 1000, " Kbit.\t ", format("%.2f", (data.length * 100.0f) / size), "% of the original size");
		sentBytes = data.length + int.sizeof * 2;
	}

	void receive() {
		if (_isDead)
			return;

		size_t length;
		if (readTCP(_socket, length)) {
			_isDead = true;
			log(LogLevel.error, "isDead = true");
			return;
		}
		_keys.length = length;

		int size = cast(int)(length * SDL_Keycode.sizeof);
		if (readTCP(_socket, _keys)) {
			_isDead = true;
			log(LogLevel.error, "isDead = true");
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

	ubyte[] _sendBuffer;
}
