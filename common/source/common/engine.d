module common.engine;

import common.sdl;
import common.vector;

interface IState {
	void init(Engine e);
	void update();
	void render();
	@property bool isDone();
}

immutable vec2i windowSize = vec2i(640, 480);

class Engine {
public:
	this(bool needWindow, int targetHZ = 30, bool killOnSlow = true) {
		_sdl = new SDL;
		if (needWindow)
			_window = new Window(windowSize);
		_targetHZ = targetHZ;
		_killOnSlow = killOnSlow;
	}

	~this() {
		_window.destroy;
		_sdl.destroy;
	}

	int run() {
		import std.experimental.logger;
		import std.datetime.stopwatch;

		StopWatch watch;
		int bottlenecks;
		while (!_state.isDone() && _sdl.doEvent(_keys)) {
			watch.reset();
			watch.start();
			_state.update();
			_state.render();
			watch.stop();
			auto msec = watch.peek().total!"msecs";
			if (_targetHZ) {
				if (msec > 1000 / _targetHZ) {
					log(LogLevel.info, "Update took: ", watch.peek());
					if (_killOnSlow && ++bottlenecks >= 16) {
						log(LogLevel.error, "\tBreaking code is bottlenecking");
						break;
					}
				} else {
					bottlenecks = 0;
					log(LogLevel.warning, "Sleeping for: ", cast(int)(1000 / _targetHZ - msec), " msecs");
					SDL_Delay(cast(int)(1000 / _targetHZ - msec));
				}
			}
		}
		_state.destroy;
		_state = null;
		return 0;

	}

	@property IState state() {
		return _state;
	}

	@property IState state(IState state) {
		_state = state;
		_state.init(this);
		return _state;
	}

	@property Window window() {
		return _window;
	}

	@property SDL_Keycode[] keys() {
		return _keys;
	}

private:
	SDL _sdl;
	int _targetHZ;
	bool _killOnSlow;
	Window _window;
	IState _state;
	SDL_Keycode[] _keys;
}
