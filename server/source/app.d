module app;

import std.stdio;
import common.sdl;
import common.engine;
import common.network;
import common.vector;

import std.parallelism;

import server.client;
import server.assets;

class ServerState : IState {
public:
	this(size_t workers) {
		_taskPool = new TaskPool(workers);
	}

	void init(Engine e) {
		_server = new NetworkServer();
		_textRenderer = new TextRenderer();
		_assets = new Assets();
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

private:
	bool _quit;
	NetworkServer _server;
	Client[] _clients;
	TaskPool _taskPool;
	Assets _assets;
	TextRenderer _textRenderer;
}

int main(string[] args) {
	Engine e = new Engine(false);
	scope (exit)
		e.destroy;

	e.state = new ServerState(8);

	return e.run();
}
