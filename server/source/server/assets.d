module server.assets;

import common.sdl;

class Assets {
	SDL_Surface* back;
	SDL_Surface* cards;

	this() {
		back = _load("assets/cards/back.png");
		cards = _load("assets/cards/cards.png");
	}

	this(SDL_Surface* back_, SDL_Surface* cards_) {
		back = back_;
		cards = cards_;
	}

	Assets dup() {
		return new Assets(SDL_DuplicateSurface(back), SDL_DuplicateSurface(cards));
	}

	~this() {
		SDL_FreeSurface(cards);
		SDL_FreeSurface(back);
	}

	private SDL_Surface* _load(string str) {
		import std.string;

		SDL_Surface* tmp = IMG_Load(str.toStringz);
		assert(tmp);
		scope (exit)
			SDL_FreeSurface(tmp);
		SDL_Surface* sur = SDL_ConvertSurfaceFormat(tmp, SDL_PIXELFORMAT_RGB332, 0);
		assert(sur);
		return sur;
	}
}
