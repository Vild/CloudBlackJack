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
	this(bool needWindow) {
		_sdl = new SDL;
		if (needWindow)
			_window = new Window(windowSize);
	}

	~this() {
		_window.destroy;
		_sdl.destroy;
	}

	int run() {
		while (!_state.isDone() && _sdl.doEvent(_keys)) {
			_state.update();
			_state.render();
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
	Window _window;
	IState _state;
	SDL_Keycode[] _keys;
}
