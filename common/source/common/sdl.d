module common.sdl;

public import derelict.sdl2.sdl;
public import derelict.sdl2.image;
public import derelict.sdl2.net;

import std.stdio;

import common.vector;

shared static this() {
	DerelictSDL2.load();
	DerelictSDL2Image.load();
	DerelictSDL2Net.load();
}

void sdlAssert(T, Args...)(T cond, Args args) {
	import std.string : fromStringz;

	if (!!cond)
		return;
	stderr.writeln(args);
	stderr.writeln("SDL_ERROR: ", SDL_GetError().fromStringz);
	assert(0);
}

SDL_Surface* SDL_DuplicateSurface(SDL_Surface* surface) {
	return SDL_ConvertSurface(surface, surface.format, surface.flags);
}

class SDL {
public:
	this() {
		sdlAssert(!SDL_Init(SDL_INIT_EVENTS | SDL_INIT_VIDEO), "SDL could not initialize!");
		sdlAssert(IMG_Init(IMG_INIT_PNG), "SDL_image could not initialize!");
		sdlAssert(!SDLNet_Init(), "SDLNet could not initialize!");
	}

	~this() {
		SDLNet_Quit();
		IMG_Quit();
		SDL_Quit();
	}

	bool doEvent(ref SDL_Keycode[] keys) {
		keys.length = 0;
		SDL_Event event;
		bool quit = false;
		while (SDL_PollEvent(&event)) {
			switch (event.type) {
			case SDL_QUIT:
				quit = true;
				break;

			case SDL_KEYDOWN:
				if (event.key.keysym.sym == SDLK_ESCAPE)
					quit = true;
				else
					keys ~= event.key.keysym.sym;
				break;

			default:
				break;
			}
		}

		return !quit;
	}
}

class Window {
public:
	SDL_Window* window;
	SDL_Renderer* renderer;
	vec2i size;

	this(vec2i size) {
		this.size = size;
		sdlAssert(!SDL_CreateWindowAndRenderer(size.x, size.y, 0, &window, &renderer), "Failed to create window and renderer");
	}

	~this() {
		if (renderer)
			SDL_DestroyRenderer(renderer);
		renderer = null;
		SDL_DestroyWindow(window);
		window = null;
	}

	void reset() {
		SDL_SetRenderTarget(renderer, null);
	}
}
