// Players under 13 play online with a nickname picked from these lists, never typed.
// Keep identical to scripts/nicknames.gd in the app.
export const ADJECTIVES = ["Sneaky", "Lucky", "Sparkly", "Brave", "Clever", "Speedy", "Jolly", "Mighty", "Sunny", "Cosmic", "Daring", "Fuzzy", "Golden", "Happy", "Silly", "Quiet", "Bouncy", "Swift", "Witty", "Zippy"];
export const ANIMALS = ["Fox", "Panda", "Otter", "Tiger", "Koala", "Falcon", "Turtle", "Rabbit", "Dragon", "Penguin", "Badger", "Dolphin", "Owl", "Gecko", "Lynx", "Moose", "Raccoon", "Parrot", "Llama", "Hedgehog"];

export function validNickname(raw: unknown): boolean {
  const parts = String(raw ?? "").split(" ");
  return parts.length === 2 && ADJECTIVES.includes(parts[0]) && ANIMALS.includes(parts[1]);
}
