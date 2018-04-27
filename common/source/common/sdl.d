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

/*class TextRenderer {
public:
	import std.typecons;
	import std.traits;

	enum Strings {
		none,
		waitForNextGame,
		settingUpGame,

		waitingForTurn,
		makeYourMove,
		waitingForOther,

		bankIsPlaying,

		bankWon,
		youWin,
		blackjack,

		keyActions,
		keyActions_maxCards
	}

	alias StrCol = Tuple!(string, "str", SDL_Color, "color");
	static immutable StrCol[Strings] text;

	shared static this() {
		enum white = SDL_Color(0xFF, 0xFF, 0xFF);
		enum cyan = SDL_Color(0x00, 0xFF, 0xFF);
		enum magenta = SDL_Color(0xFF, 0x00, 0xFF);

		text[Strings.none] = StrCol(" ", SDL_Color());

		text[Strings.waitForNextGame] = StrCol("Waiting for next game", magenta);
		text[Strings.settingUpGame] = StrCol("Setting up game", magenta);

		text[Strings.waitingForTurn] = StrCol("Waiting for your turn", white);
		text[Strings.makeYourMove] = StrCol("Make your move", white);
		text[Strings.waitingForOther] = StrCol("Waiting for other players", white);
		text[Strings.bankIsPlaying] = StrCol("Bank is playing", white);

		text[Strings.bankWon] = StrCol("Bank won", white);
		text[Strings.youWin] = StrCol("You won!", white);
		text[Strings.blackjack] = StrCol("BLACKJACK!!!!", white);

		text[Strings.keyActions] = StrCol("Press <F> to hit, <J> to stand", cyan);
		text[Strings.keyActions_maxCards] = StrCol("<J> to stand", cyan);
	}

	__gshared static TTF_Font* font;
	bool ownsFont;

	alias TextSurface = Tuple!(SDL_Surface*, "surface", vec2i, "size");

	TextSurface[Strings] renderedStrings;

	this() {
		font = TTF_OpenFont("assets/PxPlus_IBM_EGA8.ttf", 32);
		assert(font);
		ownsFont = true;
		foreach (strCol; EnumMembers!Strings)
			renderedStrings[strCol] = renderText(text[strCol].str, text[strCol].color);
	}

	this(TextSurface[Strings] renderedStrings_) {
		renderedStrings = renderedStrings_;
	}

	TextRenderer dup() {
		TextSurface[Strings] renderedStringsDup;
		foreach (strCol; EnumMembers!Strings)
			renderedStringsDup[strCol] = TextSurface(SDL_DuplicateSurface(renderedStrings[strCol].surface), renderedStrings[strCol].size);
		return new TextRenderer(renderedStringsDup);
	}

	~this() {
		foreach (strCol; EnumMembers!Strings)
			SDL_FreeSurface(renderedStrings[strCol].surface);
		renderedStrings = null;

		if (ownsFont) {
			TTF_CloseFont(font);
			font = null;
		}
	}

	TextSurface* getStringSurface(Strings str) {
		return &renderedStrings[str];
	}

	TextSurface renderText(string str, SDL_Color color) {
		import std.string;
		import std.experimental.logger;

		auto surface = TTF_RenderUTF8_Solid(font, str.toStringz, color);
		if (!surface) {
			stderr.writeln("Failed to render string \"", str, "\"");
			surface = TTF_RenderUTF8_Solid(font, "<FAILED TO RENDER>", color);
		}
		return TextSurface(surface, vec2i(surface.w, surface.h));
	}
}*/
