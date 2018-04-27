module server.client;

import app;
import server.card;
import server.assets;

import common.vector;
import common.network;
import common.sdl;
import common.engine;
import common.text;

import std.experimental.logger;

class Client {
	enum ClientGameState {
		waitingForNextGame,
		settingUpGame,
		waitingForTurn,
		playing,
		doneWithTurn,
		bankIsPlaying,
		won,
		lost,
		blackjack
	}

	ClientGameState gameState;

	ServerState serverState;
	NetworkServerClient connection;
	size_t id;
	SDL_Surface* surface;
	TextRenderer textRenderer;
	Assets assets;

	private enum _maxCards = 6;
	Card[] cards;

	@disable this();
	this(ServerState serverState_, NetworkServerClient connection_, Assets assets_) {
		serverState = serverState_;
		connection = connection_;
		textRenderer = new TextRenderer();
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

		if (cards.length < _maxCards && calculateSum(cards).sum < 21 && connection.keys.canFind(SDLK_f)) {
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
			case ClientGameState.waitingForNextGame:
				topString = Strings.waitForNextGame;
				break;
			case ClientGameState.settingUpGame:
				topString = Strings.settingUpGame;
				break;
			case ClientGameState.waitingForTurn:
				topString = Strings.waitingForTurn;
				break;
			case ClientGameState.playing:
				topString = Strings.makeYourMove;
				bottomStr = (cards.length < _maxCards && calculateSum(cards).sum < 21) ? Strings.keyActions : Strings.keyActions_maxCards;
				break;
			case ClientGameState.doneWithTurn:
				topString = Strings.waitingForOther;
				break;

			case ClientGameState.bankIsPlaying:
				topString = Strings.bankIsPlaying;
				break;
			case ClientGameState.won:
				topString = Strings.youWin;
				break;
			case ClientGameState.lost:
				topString = Strings.bankWon;
				break;
			case ClientGameState.blackjack:
				topString = Strings.blackjack;
				break;
			}

			vec2i textSize = getSize(topString);
			SDL_Rect dst = SDL_Rect(windowSize.x / 2 - textSize.x / 2, barSize / 2 - textSize.y / 2);
			render(topString, surface, dst);

			textSize = getSize(bottomStr);
			dst = SDL_Rect(windowSize.x / 2 - textSize.x / 2, windowSize.y - barSize + (barSize / 2 - textSize.y / 2));
			render(bottomStr, surface, dst);

			import std.format : format;

			{
				auto houseSum = calculateSum(serverState.houseCards);
				string valueStr = format("Bank have: %s%d", houseSum.exact ? "" : "~", houseSum.sum);
				auto sumtextSize = getSize(valueStr);
				dst = SDL_Rect(windowSize.x / 2 - sumtextSize.x / 2, windowSize.y / 2 - sumtextSize.y / 2 - 16);
				color = SDL_Color(0xFF, 0x00, 0xFF);
				render(valueStr, surface, dst);
			}

			{
				string valueStr = format("You have: %d", calculateSum(cards).sum);
				auto sumtextSize = getSize(valueStr);
				dst = SDL_Rect(windowSize.x / 2 - sumtextSize.x / 2, windowSize.y / 2 - sumtextSize.y / 2 + 16);
				color = SDL_Color(0xFF, 0x00, 0xFF);
				render(valueStr, surface, dst);
			}
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
