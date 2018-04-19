module common.sdl;

public import derelict.sdl2.sdl;
public import derelict.sdl2.image;

import std.stdio;

import common.vector;

shared static this() {
	DerelictSDL2.load();
	DerelictSDL2Image.load();
}

void sdlAssert(T, Args...)(T cond, Args args) {
	import std.string : fromStringz;

	if (!!cond)
		return;
	stderr.writeln(args);
	stderr.writeln("SDL_ERROR: ", SDL_GetError().fromStringz);
	assert(0);
}

class SDL {
public:
	this() {
		sdlAssert(!SDL_Init(SDL_INIT_EVERYTHING), "SDL could not initialize!");
		sdlAssert(IMG_Init(IMG_INIT_PNG), "SDL_image could not initialize!");
	}

	~this() {
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
		SDL_DestroyRenderer(renderer);
		SDL_DestroyWindow(window);
	}

	void reset() {
		SDL_SetRenderTarget(renderer, null);
	}
}
