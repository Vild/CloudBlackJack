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
	enum ClientGameState {
		waitingForTurn,
		playing,
		doneWithTurn
	}

	ClientGameState gameState;

	ServerState serverState;
	NetworkServerClient connection;
	size_t id;
	SDL_Surface* surface;
	TextRenderer textRenderer;
	Assets assets;

	private enum _maxCards = 6;
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

	void update(ref Card[] globalCards) {
		import std.algorithm : canFind;
		import std.random;

		if (gameState != ClientGameState.playing)
			return;

		if (cards.length < _maxCards && connection.keys.canFind(SDLK_f)) {
			cards ~= globalCards[0];
			cards[$ - 1].hidden = false;
			globalCards = globalCards[1 .. $];
		} else if (connection.keys.canFind(SDLK_j))
			gameState = ClientGameState.doneWithTurn;
	}

	void render() {
		enum barSize = 32;
		enum sizeBetweenCards = 8;

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
			Strings topString;
			Strings bottomStr;
			final switch (gameState) {
			case ClientGameState.waitingForTurn:
				topString = Strings.waitingForTurn;
				break;
			case ClientGameState.playing:
				topString = Strings.makeYourMove;
				bottomStr = cards.length < _maxCards ? Strings.keyActions : Strings.keyActions_maxCards;
				break;
			case ClientGameState.doneWithTurn:
				topString = Strings.waitingForOther;
				break;
			}

			vec2i size = getStringSize(topString);
			SDL_Rect dst = SDL_Rect(windowSize.x / 2 - size.x / 2, barSize / 2 - size.y / 2);
			SDL_BlitSurface(getStringSurface(topString), null, surface, &dst);

			size = getStringSize(bottomStr);
			dst = SDL_Rect(windowSize.x / 2 - size.x / 2, windowSize.y - barSize + (barSize / 2 - size.y / 2));
			SDL_BlitSurface(getStringSurface(bottomStr), null, surface, &dst);

			import std.format : format;

			string valueStr = format("You have: %d", calculateSum(cards));
			size = getSize(valueStr);
			dst = SDL_Rect(windowSize.x / 2 - size.x / 2, windowSize.y / 2 - size.y / 2);
			auto sur = renderText(valueStr, SDL_Color(0xFF, 0x00, 0xFF));
			scope (exit)
				SDL_FreeSurface(sur);
			SDL_BlitSurface(sur, null, surface, &dst);
		}

		{ // House card
			int widthRequired = (cardAssetSize.x + sizeBetweenCards) * cast(int)serverState.houseCards.length - sizeBetweenCards;
			SDL_Rect dst;
			dst.x = windowSize.x / 2 - widthRequired / 2;
			dst.y = 1 * (windowSize.y / 4) - cardAssetSize.y / 2;
			dst.w = cardAssetSize.x;
			dst.h = cardAssetSize.y;

			foreach (Card c; serverState.houseCards) {
				if (c.hidden)
					SDL_BlitSurface(assets.back, null, surface, &dst);
				else {
					SDL_Rect src = SDL_Rect(cardAssetSize.x * (c.value - 1), cardAssetSize.y * cast(int)c.color, cardAssetSize.x, cardAssetSize.y);
					SDL_BlitSurface(assets.cards, &src, surface, &dst);
				}

				dst.x += cardAssetSize.x + sizeBetweenCards;
			}
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
