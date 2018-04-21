module server.client;

import app;
import server.card;
import server.assets;

import common.vector;
import common.network;
import common.sdl;
import common.engine;

import std.experimental.logger;

class Client {
	ServerState serverState;
	NetworkServerClient connection;
	size_t id;
	SDL_Surface* surface;
	TextRenderer textRenderer;
	Assets assets;

	Card[] cards; // = [Card(Card.Color.clubs, 1), Card(Card.Color.diamonds, 2), Card(Card.Color.hearts, 3), Card(Card.Color.spades, 4)];

	@disable this();
	this(ServerState serverState_, NetworkServerClient connection_, TextRenderer textRenderer_, Assets assets_) {
		serverState = serverState_;
		connection = connection_;
		textRenderer = textRenderer_;
		assets = assets_;
		id = connection.id;
		surface = SDL_CreateRGBSurfaceWithFormat(0, windowSize.x, windowSize.y, 32, SDL_PIXELFORMAT_ARGB8888);
		assert(surface);
		assert(surface.format);

		SDL_FillRect(surface, null, SDL_MapRGB(surface.format, 0, 0, 0));
	}

	~this() {
		assets.destroy;
		textRenderer.destroy;
		SDL_FreeSurface(surface);
	}

	size_t counter;

	void render() {
		import std.random;

		enum barSize = 32;
		enum sizeBetweenCards = 8;

		if (cards.length < 6 && uniform!"[]"(0, 8) == 0)
			cards ~= Card(uniform!(Card.Color), uniform!"[]"(1, 13), !!uniform!"[]"(0, 1));

		{ // Background
			SDL_Rect dst = SDL_Rect(0, 0, windowSize.x, barSize);
			SDL_FillRect(surface, &dst, SDL_MapRGB(surface.format, 0x00, 0x00, 0x00));
			dst.y = windowSize.y - barSize;
			SDL_FillRect(surface, &dst, SDL_MapRGB(surface.format, 0x00, 0x00, 0x00));
			dst.h = windowSize.y - 2 * barSize;
			dst.y = barSize;
			SDL_FillRect(surface, &dst, SDL_MapRGB(surface.format, 0x94, 0xFF, 0xFF));
		}

		with (textRenderer) { // Text
			vec2i size = getStringSize(Strings.makeYourMove);
			SDL_Rect dst = SDL_Rect(windowSize.x / 2 - size.x / 2, barSize / 2 - size.y / 2);
			SDL_BlitSurface(getStringSurface(Strings.makeYourMove), null, surface, &dst);
		}

		{ // Players card
			int widthRequired = (cardAssetSize.x + sizeBetweenCards) * cast(int)cards.length - sizeBetweenCards;
			SDL_Rect dst;
			dst.x = windowSize.x / 2 - widthRequired / 2;
			dst.y = 3 * (windowSize.y / 4) - cardAssetSize.y / 2;
			dst.w = cardAssetSize.x;
			dst.h = cardAssetSize.y;

			foreach (Card c; cards) {
				if (c.hidden)
					SDL_BlitSurface(assets.back, null, surface, &dst);
				else {
					SDL_Rect src = SDL_Rect(cardAssetSize.x * (c.value - 1), cardAssetSize.y * cast(int)c.color, cardAssetSize.x, cardAssetSize.y);
					SDL_BlitSurface(assets.cards, &src, surface, &dst);
				}

				dst.x += cardAssetSize.x + sizeBetweenCards;
			}
		}
	}

	void sendFrame() {
		connection.send(surface);
	}
}
