class_name Nicknames
## Nicknames for players under 13 in online play: picked from these lists, never typed,
## so a name can't carry a real name or contact details. The servers check the same lists
## (server/functions/*/kid.ts): keep them identical.

const ADJECTIVES := ["Sneaky", "Lucky", "Sparkly", "Brave", "Clever", "Speedy", "Jolly", "Mighty",
	"Sunny", "Cosmic", "Daring", "Fuzzy", "Golden", "Happy", "Silly", "Quiet", "Bouncy", "Swift",
	"Witty", "Zippy"]
const ANIMALS := ["Fox", "Panda", "Otter", "Tiger", "Koala", "Falcon", "Turtle", "Rabbit", "Dragon",
	"Penguin", "Badger", "Dolphin", "Owl", "Gecko", "Lynx", "Moose", "Raccoon", "Parrot", "Llama",
	"Hedgehog"]


static func random() -> String:
	return "%s %s" % [ADJECTIVES.pick_random(), ANIMALS.pick_random()]


static func valid(n: String) -> bool:
	var parts := n.split(" ")
	return parts.size() == 2 and parts[0] in ADJECTIVES and parts[1] in ANIMALS
