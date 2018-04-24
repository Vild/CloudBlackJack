module common.sdl;

public import derelict.sdl2.sdl;
public import derelict.sdl2.image;
public import derelict.sdl2.net;
public import derelict.sdl2.ttf;

import std.stdio;

import common.vector;

shared static this() {
	DerelictSDL2.load();
	DerelictSDL2Image.load();
	DerelictSDL2Net.load();
	DerelictSDL2ttf.load();
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
		sdlAssert(!SDL_Init(SDL_INIT_EVERYTHING), "SDL could not initialize!");
		sdlAssert(IMG_Init(IMG_INIT_PNG), "SDL_image could not initialize!");
		sdlAssert(!SDLNet_Init(), "SDLNet could not initialize!");
		sdlAssert(!TTF_Init(), "SDL_ttf could not initialize!");
	}

	~this() {
		TTF_Quit();
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

class TextRenderer {
public:
	import std.typecons;
	import std.traits;

	enum Strings {
		none,
		waitingForTurn,
		makeYourMove,
		waitingForOther,

		//bankWon,
		//youWin,
		//blackjack

		keyActions,
		keyActions_maxCards
	}

	alias StrCol = Tuple!(string, "str", SDL_Color, "color");
	static immutable StrCol[Strings] text;

	shared static this() {
		// dfmt off
		text = [
			Strings.none: StrCol(" ", SDL_Color()),
			Strings.waitingForTurn: StrCol("Waiting for your turn", SDL_Color(0xFF, 0xFF, 0xFF)),
			Strings.makeYourMove: StrCol("Make your move", SDL_Color(0xFF, 0xFF, 0xFF)),
			Strings.waitingForOther: StrCol("Waiting for other players", SDL_Color(0xFF, 0xFF, 0xFF)),

			//Strings.bankWon: StrCol("Bank won", SDL_Color(0xFF, 0xFF, 0xFF)),
			//Strings.youWin: StrCol("You won!", SDL_Color(0xFF, 0xFF, 0xFF)),
			//Strings.blackjack: StrCol("BLACKJACK!!!!", SDL_Color(0xFF, 0xFF, 0xFF)),

			Strings.keyActions: StrCol("Press <F> to hit, <J> to stand", SDL_Color(0x00, 0xFF, 0xFF)),
			Strings.keyActions_maxCards: StrCol("<J> to stand", SDL_Color(0x00, 0xFF, 0xFF)),
		];
		// dfmt on
	}

	__gshared static TTF_Font* font;
	bool ownsFont;

	SDL_Surface*[Strings] renderedStrings;
	vec2i[Strings] stringSize;

	this() {
		font = TTF_OpenFont("assets/PxPlus_IBM_EGA8.ttf", 32);
		assert(font);
		ownsFont = true;
		foreach (strCol; EnumMembers!Strings) {
			renderedStrings[strCol] = renderText(text[strCol].str, text[strCol].color);
			stringSize[strCol] = getSize(text[strCol].str);
		}
	}

	this(SDL_Surface*[Strings] renderedStrings_, vec2i[Strings] stringSize_) {
		renderedStrings = renderedStrings_;
		stringSize = stringSize_;
	}

	TextRenderer dup() {
		SDL_Surface*[Strings] renderedStringsDup;
		foreach (strCol; EnumMembers!Strings)
			renderedStringsDup[strCol] = SDL_DuplicateSurface(renderedStrings[strCol]);
		return new TextRenderer(renderedStringsDup, stringSize.dup);
	}

	~this() {
		foreach (strCol; EnumMembers!Strings)
			SDL_FreeSurface(renderedStrings[strCol]);
		renderedStrings = null;

		if (ownsFont) {
			TTF_CloseFont(font);
			font = null;
		}
	}

	SDL_Surface* getStringSurface(Strings str) {
		return renderedStrings[str];
	}

	vec2i getStringSize(Strings str) {
		return stringSize[str];
	}

	SDL_Surface* renderText(string str, SDL_Color color) {
		import std.string;
		import std.experimental.logger;

		auto surface = TTF_RenderUTF8_Solid(font, str.toStringz, color);
		assert(surface, "String: " ~ str);
		return surface;
	}

	vec2i getSize(string str) {
		import std.string;

		int w, h;
		auto a = font;
		TTF_SizeUTF8(a, str.toStringz, &w, &h);
		return vec2i(w, h);
	}
}
