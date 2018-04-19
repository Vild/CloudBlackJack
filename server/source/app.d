module app;

import std.stdio;
import common.sdl;
import common.engine;
import common.network;

class ServerState : IState {
public:
	void init(Engine e) {
		auto tmpSur = SDL_LoadBMP("testGrab.bmp");
		assert(tmpSur);
		scope (exit)
			SDL_FreeSurface(tmpSur);
		_surface = SDL_ConvertSurfaceFormat(tmpSur, SDL_PIXELFORMAT_ARGB8888, 0);
		assert(_surface);
		_server = new Server();
	}

	~this() {
		_server.destroy;
		SDL_FreeSurface(_surface);
	}

	void update() {
		_server.doLoop();
	}

	void render() {
		// TODO: render game

		foreach (ServerClient client; _server.clients)
			client.send(_surface);

		SDL_Delay(100);
	}

	@property bool isDone() {
		return _quit;
	}

private:
	bool _quit;
	SDL_Surface* _surface;
	Server _server;
}

int main(string[] args) {
	Engine e = new Engine(false);
	scope (exit)
		e.destroy;

	e.state = new ServerState();

	return e.run();
}
