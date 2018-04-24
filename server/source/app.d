module app;

import std.stdio;
import common.sdl;
import common.engine;
import common.network;
import common.vector;

import std.parallelism;

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
		_textRenderer = new TextRenderer();
		_assets = new Assets();

		_resetCards();
	}

	~this() {
		_assets.destroy;
		_textRenderer.destroy;
		_server.destroy;
		_taskPool.stop();
		_taskPool.destroy;
	}

	void update() {
		import std.algorithm;

		auto diff = _server.doLoop();
		_clients = _clients.remove!(x => diff.removeList.canFind(x.id) && { x.destroy; return true; }());

		foreach (newClient; diff.addedList)
			_clients ~= new Client(this, newClient, _textRenderer.dup, _assets.dup);

		bool setCurrent = true;
		foreach (Client client; _clients) {
			if (setCurrent) final switch (client.gameState) with (Client) {
			case ClientGameState.waitingForTurn:
				client.gameState = ClientGameState.playing;
				setCurrent = false;
				break;
			case ClientGameState.playing:
				setCurrent = false;
				break;
			case ClientGameState.doneWithTurn:
				break;
			}
			client.update(_globalCardStack);
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

	@property TextRenderer textRenderer() {
		return _textRenderer;
	}

	@property Card[] houseCards() {
		return _houseCards;
	}

private:
	bool _quit;
	NetworkServer _server;
	Client[] _clients;
	TaskPool _taskPool;
	Assets _assets;
	TextRenderer _textRenderer;

	Card[] _globalCardStack;

	Card[] _houseCards;

	void _resetCards() {
		import std.traits : EnumMembers;
		import std.random : randomShuffle;

		_globalCardStack.length = 0;

		foreach (i; 0 .. 4) // decks
			foreach (color; EnumMembers!(Card.Color))
				foreach (val; 1 .. 14)
					_globalCardStack ~= Card(color, val, true);

		randomShuffle(_globalCardStack);

		_houseCards.length = 0;
		_houseCards ~= _globalCardStack[0];
		_houseCards[0].hidden = false;
		_houseCards ~= _globalCardStack[1];
		_globalCardStack = _globalCardStack[2 .. $];
	}
}

int main(string[] args) {
	Engine e = new Engine(false);
	scope (exit)
		e.destroy;

	e.state = new ServerState(8);

	return e.run();
}
