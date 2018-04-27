module app;

import std.stdio;
import common.sdl;
import common.engine;
import common.network;
import common.vector;

import std.parallelism;
import std.random : uniform;

import server.client;
import server.assets;
import server.card;

class ServerState : IState {
public:
	this(size_t workers) {
		_taskPool = new TaskPool(workers);
	}

	void init(Engine e) {
		_server = new NetworkServer();
		_assets = new Assets();

		_restartGame();
	}

	~this() {
		_assets.destroy;
		_server.destroy;
		_taskPool.stop();
		_taskPool.destroy;
	}

	void update() {
		import std.algorithm;

		auto diff = _server.doLoop();
		_clients = _clients.remove!(x => diff.removeList.canFind(x.id) && { x.destroy; return true; }());

		foreach (newClient; diff.addedList)
			_clients ~= new Client(this, newClient, _assets.dup);

		outerSwitch: final switch (_gameState) {
		case GameState.settingUp:
			if (!_clients.length) // Can't set up without clients :)
				break;

			if (!_houseCards.length)
				foreach (Client c; _clients)
					c.gameState = Client.ClientGameState.settingUpGame;

			static int dealingCard = 1;
			if (!_houseCards.length)
				dealingCard = 1;

			if (_houseCards.length == 2) {
				_gameState = GameState.playing;

				foreach (Client c; _clients) {
					if (c.gameState == Client.ClientGameState.waitingForNextGame)
						continue;
					c.gameState = Client.ClientGameState.waitingForTurn;
				}
				break;
			}

			foreach (Client c; _clients)
				if (c.gameState == Client.ClientGameState.settingUpGame && c.cards.length == dealingCard - 1) {
					if (uniform!"[]"(0, 4) != 0)
						break outerSwitch;
					c.cards ~= _getCard();
					c.cards[$ - 1].hidden = false;
					break outerSwitch;
				}

			if (_houseCards.length < 2) {
				if (uniform!"[]"(0, 4) != 0)
					break;
				_houseCards ~= _getCard();
				_houseCards[$ - 1].hidden = _houseCards.length == 2;
			}
			dealingCard++;
			break;
		case GameState.playing:
			bool setCurrent = true;
			foreach (Client client; _clients) {
				if (client.gameState == Client.ClientGameState.waitingForNextGame)
					continue;
				if (setCurrent) final switch (client.gameState) with (Client) {
				case ClientGameState.waitingForNextGame:
					break;
				case ClientGameState.settingUpGame:
				case ClientGameState.waitingForTurn:
					if (setCurrent) {
						client.gameState = ClientGameState.playing;
						setCurrent = false;
					}
					break;
				case ClientGameState.playing:
					setCurrent = false;
					break;
				case ClientGameState.doneWithTurn:
				case ClientGameState.bankIsPlaying:
				case ClientGameState.won:
				case ClientGameState.lost:
				case ClientGameState.blackjack:
					break;
				}
				client.update(_globalCardStack);
			}
			if (setCurrent)
				_gameState = GameState.bankPlay;
			break;
		case GameState.bankPlay:
			foreach (Client c; _clients) {
				if (c.gameState == Client.ClientGameState.waitingForNextGame)
					continue;
				c.gameState = Client.ClientGameState.bankIsPlaying;
			}

			_houseCards[1].hidden = false;
			auto houseSum = calculateSum(_houseCards).sum;
			if (houseSum >= 17) {
				_gameState = GameState.cooldown;
				_cooldownStart = SDL_GetTicks();

				foreach (Client c; _clients) {
					if (c.gameState == Client.ClientGameState.waitingForNextGame)
						continue;
					auto sum = calculateSum(c.cards).sum;

					if (houseSum > 21)
						c.gameState = Client.ClientGameState.won;
					else if (sum > 21)
						c.gameState = Client.ClientGameState.lost;
					else if (houseSum == 21)
						c.gameState = Client.ClientGameState.lost;
					else if (sum == 21)
						c.gameState = Client.ClientGameState.blackjack;
					else if (sum > houseSum)
						c.gameState = Client.ClientGameState.won;
					else
						c.gameState = Client.ClientGameState.lost;
				}

				break;
			}

			if (uniform!"[]"(0, 16) == 0) {
				_houseCards ~= _getCard();
				_houseCards[$ - 1].hidden = false;
			}
			break;
		case GameState.cooldown:
			if (SDL_GetTicks() <= _cooldownStart + _cooldownLength)
				break;

			_gameState = GameState.settingUp;
			_restartGame();
			break;
		}
	}

	void render() {
		foreach (Client client; _taskPool.parallel(_clients)) {
			client.render();
			client.sendFrame();
		}
	}

	@property bool isDone() {
		return _quit;
	}

	@property Card[] houseCards() {
		return _houseCards;
	}

private:
	enum GameState {
		settingUp,
		playing,
		bankPlay,
		cooldown
	}

	enum _cooldownLength = 4 * 1000;
	uint _cooldownStart;
	GameState _gameState;

	bool _quit;
	NetworkServer _server;
	Client[] _clients;
	TaskPool _taskPool;
	Assets _assets;

	Card[] _globalCardStack;

	Card[] _houseCards;

	void _restartGame() {
		_houseCards.length = 0;
		foreach (Client client; _clients)
			client.cards.length = 0;
	}

	Card _getCard() {
		import std.range : front, popFront;

		if (!_globalCardStack.length) {
			import std.traits : EnumMembers;
			import std.random : randomShuffle;

			_globalCardStack.length = 0;

			foreach (i; 0 .. 4) // decks
				foreach (color; EnumMembers!(Card.Color))
					foreach (val; 1 .. 14)
						_globalCardStack ~= Card(color, val, true);

			randomShuffle(_globalCardStack);
		}

		Card c = _globalCardStack.front;
		_globalCardStack.popFront;
		return c;
	}
}

int main(string[] args) {
	Engine e = new Engine(false);
	scope (exit)
		e.destroy;

	e.state = new ServerState(8);

	return e.run();
}
