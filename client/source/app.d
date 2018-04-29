module app;

import std.stdio;
import common.sdl;
import common.engine;
import common.network;
import std.experimental.logger;

class ClientState : IState {
public:
	this(string ip) {
		_ip = ip;
	}

	void init(Engine e) {
		this.e = e;
		if (e.window) {
			_renderer = e.window.renderer;
			_texture = SDL_CreateTexture(_renderer, SDL_PIXELFORMAT_RGB332, SDL_TEXTUREACCESS_STREAMING, windowSize.x, windowSize.y);
		}

		// Surface is always needed to the recieve function
		_surface = SDL_CreateRGBSurfaceWithFormat(0, windowSize.x, windowSize.y, 32, SDL_PIXELFORMAT_RGB332);

		_client = new NetworkClient(_ip);
	}

	~this() {
		_client.destroy;

		SDL_FreeSurface(_surface);
	}

	void update() {
		if (e.keys)
			_client.send(e.keys);

		if (_renderer)
			SDL_LockTexture(_texture, null, &_surface.pixels, &_surface.pitch);
		_client.recieve(_surface);
		if (_renderer)
			SDL_UnlockTexture(_texture);

		_quit = _client.isDead;
		if (_quit)
			log(LogLevel.warning, "Lost connection!!");
	}

	void render() {
		if (_renderer) {
			SDL_SetRenderDrawColor(_renderer, 0, 0, 0, 255);
			SDL_RenderClear(_renderer);
			SDL_RenderCopy(_renderer, _texture, null, null);
			SDL_RenderPresent(_renderer);
		}
	}

	@property bool isDone() {
		return _quit;
	}

	@property size_t clientCount() {
		return 0;
	}

private:
	bool _quit;
	Engine e;
	SDL_Renderer* _renderer;
	SDL_Texture* _texture;
	SDL_Surface* _surface;

	string _ip;
	NetworkClient _client;
}

int main(string[] args) {
	bool displayGUI = true;
	string ip = "localhost";

	foreach (arg; args[1 .. $])
		if (arg == "nogui")
			displayGUI = false;
		else
			ip = arg;

	Engine e = new Engine(displayGUI, 30, false);
	scope (exit)
		e.destroy;

	e.state = new ClientState(ip);

	return e.run();
}
