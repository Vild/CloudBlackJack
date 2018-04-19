module app;

import std.stdio;
import common.sdl;
import common.engine;
import common.network;

class ClientState : IState {
public:
	void init(Engine e) {
		_renderer = e.window.renderer;
		_texture = SDL_CreateTexture(_renderer, SDL_PIXELFORMAT_ARGB8888, SDL_TEXTUREACCESS_STREAMING, windowSize.x, windowSize.y);
		_surface = SDL_CreateRGBSurfaceFrom(null, windowSize.x, windowSize.y, 32, 0, 0x00FF0000, 0x0000FF00, 0x000000FF, 0xFF000000);

		_client = new Client();
	}

	~this() {
		_client.destroy;
		SDL_FreeSurface(_surface);
		SDL_DestroyTexture(_texture);
	}

	void update() {
		static int counter;
		counter++;

		SDL_LockTexture(_texture, null, &_surface.pixels, &_surface.pitch);
		_client.recieve(_surface);
		SDL_UnlockTexture(_texture);

		SDL_Delay(50);
	}

	void render() {
		SDL_SetRenderDrawColor(_renderer, 0, 0, 0, 255);
		SDL_RenderClear(_renderer);
		SDL_RenderCopy(_renderer, _texture, null, null);
		SDL_RenderPresent(_renderer);
	}

	@property bool isDone() {
		return _quit;
	}

private:
	bool _quit;
	SDL_Renderer* _renderer;
	SDL_Texture* _texture;
	SDL_Surface* _surface;

	Client _client;
}

int main(string[] args) {
	Engine e = new Engine(true);
	scope (exit)
		e.destroy;

	e.state = new ClientState();

	return e.run();
}
