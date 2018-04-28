module common.vector;

// From GFM
import std.traits, std.math, std.conv, std.array, std.string;

/**
 * Generic 1D small vector.
 * Params:
 *    N = number of elements
 *    T = type of elements
 */
struct Vector(T, int N) {
nothrow:
	public {
		static assert(N >= 1);

		// fields definition
		union {
			T[N] v;
			struct {
				static if (N >= 1) {
					T x;
					alias x r;
				}
				static if (N >= 2) {
					T y;
					alias y g;
				}
				static if (N >= 3) {
					T z;
					alias z b;
				}
				static if (N >= 4) {
					T w;
					alias w a;
				}
			}
		}

		@nogc this(Args...)(Args args) pure nothrow {
			static if (args.length == 1) {
				// Construct a Vector from a single value.
				opAssign!(Args[0])(args[0]);
			} else {
				// validate the total argument count across scalars and vectors
				template argCount(T...) {
					static if (T.length == 0)
						enum argCount = 0; // done recursing
					else static if (isVector!(T[0]))
						enum argCount = T[0]._N + argCount!(T[1 .. $]);
					else
						enum argCount = 1 + argCount!(T[1 .. $]);
				}

				static assert(argCount!Args <= N, "Too many arguments in vector constructor");

				int index = 0;
				foreach (arg; args) {
					static if (isAssignable!(T, typeof(arg))) {
						v[index] = arg;
						index++; // has to be on its own line (DMD 2.068)
					} else static if (isVector!(typeof(arg)) && isAssignable!(T, arg._T)) {
						mixin(generateLoopCode!("v[index + @] = arg[@];", arg._N)());
						index += arg._N;
					} else
						static assert(false, "Unrecognized argument in Vector constructor");
				}
				assert(index == N, "Bad arguments in Vector constructor");
			}
		}

		/// Assign a Vector from a compatible type.
		@nogc ref Vector opAssign(U)(U x) pure nothrow if (isAssignable!(T, U)) {
			mixin(generateLoopCode!("v[@] = x;", N)()); // copy to each component
			return this;
		}

		/// Assign a Vector with a static array type.
		@nogc ref Vector opAssign(U)(U arr) pure nothrow 
				if ((isStaticArray!(U) && isAssignable!(T, typeof(arr[0])) && (arr.length == N))) {
			mixin(generateLoopCode!("v[@] = arr[@];", N)());
			return this;
		}

		/// Assign with a dynamic array.
		/// Size is checked in debug-mode.
		@nogc ref Vector opAssign(U)(U arr) pure nothrow if (isDynamicArray!(U) && isAssignable!(T, typeof(arr[0]))) {
			assert(arr.length == N);
			mixin(generateLoopCode!("v[@] = arr[@];", N)());
			return this;
		}

		/// Assign from a samey Vector.
		@nogc ref Vector opAssign(U)(U u) pure nothrow if (is(U : Vector)) {
			v[] = u.v[];
			return this;
		}

		/// Assign from other vectors types (same size, compatible type).
		@nogc ref Vector opAssign(U)(U x) pure nothrow 
				if (isVector!U && isAssignable!(T, U._T) && (!is(U : Vector)) && (U._N == _N)) {
			mixin(generateLoopCode!("v[@] = x.v[@];", N)());
			return this;
		}

		/// Returns: a pointer to content.
		@nogc inout(T)* ptr() pure inout nothrow @property {
			return v.ptr;
		}

		/// Returns a hash that represents this vector
		@nogc ulong toHash() nothrow const @trusted {
			import std.traits : isFloatingPoint;

			enum ulong prime = 23;
			ulong result = 17;
			for (int i = 0; i < N; ++i) {
				static if (isFloatingPoint!T) {
					double tmp = v[i];
					result = result * prime + *cast(ulong*)&tmp;
				} else
					result = result * prime + v[i];
			}

			return result;
		}

		/// Converts to a pretty string.
		string toString() const nothrow {
			try
				return format("%s", v);
			catch (Exception e)
				assert(false); // should not happen since format is right
		}

		@nogc bool opEquals(U)(U other) pure const nothrow if (is(U : Vector)) {
			for (int i = 0; i < N; ++i) {
				if (v[i] != other.v[i]) {
					return false;
				}
			}
			return true;
		}

		@nogc bool opEquals(U)(U other) pure const nothrow if (isConvertible!U) {
			Vector conv = other;
			return opEquals(conv);
		}

		@nogc Vector opUnary(string op)() pure const nothrow if (op == "+" || op == "-" || op == "~" || op == "!") {
			Vector res = void;
			mixin(generateLoopCode!("res.v[@] = " ~ op ~ " v[@];", N)());
			return res;
		}

		@nogc ref Vector opOpAssign(string op, U)(U operand) pure nothrow if (is(U : Vector)) {
			mixin(generateLoopCode!("v[@] " ~ op ~ "= operand.v[@];", N)());
			return this;
		}

		@nogc ref Vector opOpAssign(string op, U)(U operand) pure nothrow if (isConvertible!U) {
			Vector conv = operand;
			return opOpAssign!op(conv);
		}

		@nogc Vector opBinary(string op, U)(U operand) pure const nothrow if (is(U : Vector) || (isConvertible!U)) {
			Vector result = void;
			static if (is(U : T))
				mixin(generateLoopCode!("result.v[@] = cast(T)(v[@] " ~ op ~ " operand);", N)());
			else {
				Vector other = operand;
				mixin(generateLoopCode!("result.v[@] = cast(T)(v[@] " ~ op ~ " other.v[@]);", N)());
			}
			return result;
		}

		@nogc Vector opBinaryRight(string op, U)(U operand) pure const nothrow if (isConvertible!U) {
			Vector result = void;
			static if (is(U : T))
				mixin(generateLoopCode!("result.v[@] = cast(T)(operand " ~ op ~ " v[@]);", N)());
			else {
				Vector other = operand;
				mixin(generateLoopCode!("result.v[@] = cast(T)(other.v[@] " ~ op ~ " v[@]);", N)());
			}
			return result;
		}

		@nogc ref T opIndex(size_t i) pure nothrow {
			return v[i];
		}

		@nogc ref const(T) opIndex(size_t i) pure const nothrow {
			return v[i];
		}

		@nogc T opIndexAssign(U : T)(U x, size_t i) pure nothrow {
			return v[i] = x;
		}

		@nogc @property auto opDispatch(string op, U = void)() pure const nothrow if (isValidSwizzle!(op)) {
			alias Vector!(T, op.length) returnType;
			returnType res = void;
			enum indexTuple = swizzleTuple!op;
			foreach (i, index; indexTuple)
				res.v[i] = v[index];
			return res;
		}

		@nogc @property void opDispatch(string op, U)(U x) pure 
				if ((op.length >= 2) && (isValidSwizzleUnique!op) // v.xyy will be rejected
					 && is(typeof(Vector!(T, op.length)(x)))) // can be converted to a small vector of the right size
					{
			Vector!(T, op.length) conv = x;
			enum indexTuple = swizzleTuple!op;
			foreach (i, index; indexTuple)
				v[index] = conv[i];
		}

		@nogc U opCast(U)() pure const nothrow if (isVector!U && (U._N == _N)) {
			U res = void;
			mixin(generateLoopCode!("res.v[@] = cast(U._T)v[@];", N)());
			return res;
		}

		@nogc int opDollar() pure const nothrow {
			return N;
		}

		@nogc T[] opSlice() pure nothrow {
			return v[];
		}

		@nogc T[] opSlice(int a, int b) pure nothrow {
			return v[a .. b];
		}
	}

	private {
		enum _N = N;
		alias T _T;

		// define types that can be converted to this, but are not the same type
		template isConvertible(T) {
			enum bool isConvertible = (!is(T : Vector)) && is(typeof({ T x; Vector v = x; }()));
		}

		// define types that can't be converted to this
		template isForeign(T) {
			enum bool isForeign = (!isConvertible!T) && (!is(T : Vector));
		}

		template isValidSwizzle(string op, int lastSwizzleClass = -1) {
			static if (op.length == 0)
				enum bool isValidSwizzle = true;
			else {
				enum len = op.length;
				enum int swizzleClass = swizzleClassify!(op[0]);
				enum bool swizzleClassValid = (lastSwizzleClass == -1 || (swizzleClass == lastSwizzleClass));
				enum bool isValidSwizzle = (swizzleIndex!(op[0]) != -1) && swizzleClassValid && isValidSwizzle!(op[1 .. len], swizzleClass);
			}
		}

		template searchElement(char c, string s) {
			static if (s.length == 0) {
				enum bool result = false;
			} else {
				enum string tail = s[1 .. s.length];
				enum bool result = (s[0] == c) || searchElement!(c, tail).result;
			}
		}

		template hasNoDuplicates(string s) {
			static if (s.length == 1) {
				enum bool result = true;
			} else {
				enum tail = s[1 .. s.length];
				enum bool result = !(searchElement!(s[0], tail).result) && hasNoDuplicates!(tail).result;
			}
		}

		// true if the swizzle has at the maximum one time each letter
		template isValidSwizzleUnique(string op) {
			static if (isValidSwizzle!op)
				enum isValidSwizzleUnique = hasNoDuplicates!op.result;
			else
				enum bool isValidSwizzleUnique = false;
		}

		template swizzleIndex(char c) {
			static if ((c == 'x' || c == 'r') && N >= 1)
				enum swizzleIndex = 0;
			else static if ((c == 'y' || c == 'g') && N >= 2)
				enum swizzleIndex = 1;
			else static if ((c == 'z' || c == 'b') && N >= 3)
				enum swizzleIndex = 2;
			else static if ((c == 'w' || c == 'a') && N >= 4)
				enum swizzleIndex = 3;
			else
				enum swizzleIndex = -1;
		}

		template swizzleClassify(char c) {
			static if (c == 'x' || c == 'y' || c == 'z' || c == 'w')
				enum swizzleClassify = 0;
			else static if (c == 'r' || c == 'g' || c == 'b' || c == 'a')
				enum swizzleClassify = 1;
			else
				enum swizzleClassify = -1;
		}

		template swizzleTuple(string op) {
			enum opLength = op.length;
			static if (op.length == 0)
				enum swizzleTuple = [];
			else
				enum swizzleTuple = [swizzleIndex!(op[0])] ~ swizzleTuple!(op[1 .. op.length]);
		}
	}
}

/// True if `T` is some kind of `Vector`
enum isVector(T) = is(T : Vector!U, U...);

// Previous name, but the alias doesn't seem to show deprecation messages
deprecated("Use isVector instead") alias isVectorInstantiation(T) = isVector!T;

///
unittest {
	static assert(isVector!vec2f);
	static assert(isVector!vec3d);
	static assert(isVector!(vec4!real));
	static assert(!isVector!float);
}

/// Get the numeric type used to measure a vectors's coordinates.
alias DimensionType(T : Vector!U, U...) = U[0];

///
unittest {
	static assert(is(DimensionType!vec2f == float));
	static assert(is(DimensionType!vec3d == double));
}

template vec2(T) {
	alias Vector!(T, 2) vec2;
}

template vec4(T) {
	alias Vector!(T, 4) vec4;
}

alias vec2!int vec2i;
alias vec4!int vec4i;

private {
	static string generateLoopCode(string formatString, int N)() pure nothrow {
		string result;
		for (int i = 0; i < N; ++i) {
			string index = ctIntToString(i);
			// replace all @ by indices
			result ~= formatString.replace("@", index);
		}
		return result;
	}

	// Speed-up CTFE conversions
	static string ctIntToString(int n) pure nothrow {
		static immutable string[16] table = ["0", "1", "2", "3", "4", "5", "6", "7", "8", "9"];
		if (n < 10)
			return table[n];
		else
			return to!string(n);
	}
}
