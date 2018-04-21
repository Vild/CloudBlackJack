module server.card;

import common.vector;

struct Card {
	enum Color {
		clubs,
		diamonds,
		hearts,
		spades
	}

	Color color;
	int value;
	bool hidden;
}

enum cardAssetSize = vec2i(90, 125);

/// Return: Will return the max one that is below 22
int calculateSum(Card[] cards) {
	import std.algorithm;
	import std.array;

	int[] calc(int[] input, Card c) {
		if (c.value > 10)
			c.value = 10;

		if (c.value == 1) {
			int[] output;
			output.length = input.length * 2;
			foreach (idx, i; input) {
				output[idx * 2 + 0] = i + 1;
				output[idx * 2 + 1] = i + 11;
			}
			return output;
		} else {
			foreach (ref i; input)
				i += c.value;
			return input;
		}
	}

	int[] sums = [0];

	foreach (card; cards)
		sums = calc(sums, card);

	auto sortSums = sums.sort;

	if (auto values = sortSums.filter!(x => x < 22).array) {
		return values[$ - 1];
	} else
		return sortSums[0];
}
