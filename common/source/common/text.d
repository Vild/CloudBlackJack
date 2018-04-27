module common.text;

import common.sdl;
import common.engine;
import common.vector;

import std.array;
import std.string;
import std.algorithm;
import std.typecons;

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

class TextRenderer {
public:
	this() {
		_font = IMG_Load("assets/font.png");
		assert(_font);
		//SDL_SetColorKey(_font, SDL_TRUE, (cast(uint*)_font.pixels)[0]);

		_maxWidth = windowSize.x;
		_scale = 2;

		_color = SDL_Color(255, 255, 255, 255);
		_shadow = SDL_Color(255, 255, 255, 0);
	}

	~this() {
		SDL_FreeSurface(_font);
	}

	void render(Strings str, SDL_Surface* surface, SDL_Rect dst) {
		auto info = &text[str];

		_color = info.color;

		render(info.str, surface, dst);
	}

	void render(string text, SDL_Surface* surface, SDL_Rect dst) {
		if (_shadow.a) {
			dst.x += 1 * _scale;
			dst.y -= 1 * _scale;
			_textRender(text, surface, dst, _shadow);
		}
		dst.x -= 1 * _scale;
		dst.y += 1 * _scale;
		_textRender(text, surface, dst, _color);
	}

	@property ref int scale() {
		return _scale;
	}

	vec2i getSize(Strings str) {
		return getSize(text[str].str);
	}

	vec2i getSize(string text) {
		import std.algorithm : min, max;

		string[] tmptext = _textSpliter(text.replace("å", "\xFC").replace("ä", "\xFD").replace("ö", "\xFE"));
		ulong m = 0;
		foreach (x; tmptext)
			m = max(m, x.length);
		return vec2i(min((_font.w * _scale * m) / 16, _maxWidth), (_font.h * _scale) / 16);
	}

	@property ref SDL_Color color() {
		return _color;
	}

	@property ref SDL_Color shadow() {
		return _shadow;
	}

private:
	SDL_Surface* _font;
	int _maxWidth;
	int _scale;
	SDL_Color _color, _shadow;

	void _textRender(string text, SDL_Surface* surface, SDL_Rect dst, SDL_Color color) {
		SDL_Rect src;
		src.w = _font.w / 16;
		src.h = _font.h / 16;
		dst.w = src.w * _scale;
		dst.h = src.h * _scale;
		string[] tmptext = _textSpliter(text.replace("å", "\xFC").replace("ä", "\xFD").replace("ö", "\xFE"));

		SDL_SetSurfaceColorMod(_font, color.r, color.g, color.b);
		foreach (string line; tmptext) {
			foreach (char c; line) {
				//_Font image is a grid of 16x16=256
				src.x = (c % 16) * src.w;
				src.y = (c / 16) * src.h;

				import std.stdio;
				writeln("SDL_BlitScaled(_font, ",src,", surface, ", dst, ");");
				SDL_BlitScaled(_font, &src, surface, &dst);

				dst.x += dst.w;
			}
			dst.y += dst.h + (src.w / 2) * _scale;
			dst.x -= line.length * dst.w;
		}
	}

	string[] _textSpliter(string text) {
		auto ret = appender!(string[])();

		float w = _font.w / 16 * _scale;

		while (text.length) {
			long max = text.indexOf('\n');
			long index;
			if (max != -1) {
				index = max = min(max, min(cast(int)(_maxWidth / w) - 1, text.length - 1));

				char c = text[index];
				while (c != ' ' && c != '\r' && c != '\n' && c != '\t' && index > 0)
					c = text[--index];
			} else {
				if (text.length < cast(int)(_maxWidth / w)) {
					index = max = text.length - 1;
				} else {
					index = max = cast(int)(_maxWidth / w) - 1;

					char c = text[index];
					while (c != ' ' && c != '\r' && c != '\n' && c != '\t' && index > 0)
						c = text[--index];
				}
			}

			if (index <= 0)
				index = max;

			string tmp = text[0 .. index + 1].replace("\r", " ").replace("\n", " ").replace("\t", " ");
			if (tmp[tmp.length - 1] == ' ')
				tmp = tmp[0 .. $ - 1];
			ret.put(tmp);
			text = text[index + 1 .. $];
		}

		return ret.data;
	}
}
