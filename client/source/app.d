module app;

import std.stdio;
import common.sdl;
import common.engine;
import common.network;
import std.experimental.logger;

class ClientState : IState {
public:
	void init(Engine e) {
		if (e.window) {
			_renderer = e.window.renderer;
			_texture = SDL_CreateTexture(_renderer, SDL_PIXELFORMAT_ARGB8888, SDL_TEXTUREACCESS_STREAMING, windowSize.x, windowSize.y);
		}

		// Surface is always needed to the recieve function
		_surface = SDL_CreateRGBSurfaceWithFormat(0, windowSize.x, windowSize.y, 32, SDL_PIXELFORMAT_ARGB8888);

		_client = new NetworkClient();
	}

	~this() {
		_client.destroy;

		SDL_FreeSurface(_surface);
		if (_renderer)
			SDL_DestroyTexture(_texture);
	}

	void update() {
		if (_renderer)
			SDL_LockTexture(_texture, null, &_surface.pixels, &_surface.pitch);
		_client.recieve(_surface);
		if (_renderer)
			SDL_UnlockTexture(_texture);

		_quit = _client.isDead;
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

private:
	bool _quit;
	SDL_Renderer* _renderer;
	SDL_Texture* _texture;
	SDL_Surface* _surface;

	NetworkClient _client;
}

int main(string[] args) {
	Engine e = new Engine(false, 30, false);
	scope (exit)
		e.destroy;

	e.state = new ClientState();

	return e.run();
}
