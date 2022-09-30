# Cyberpunk2077RPC

## About

**This is a Cyberpunk 2077 mod which adds Discord Rich Presence to the game \[1].**

\[1] This mod **saves Discord Rich Presence data to *a file*** that then **needs to be sent to
Discord** to update the Presence, to do that you'll need to **download [FSDiscordRPC](https://github.com/Marco4413/FSDiscordRPC)**
(which is also done by me) and **drag the data file onto the exe**.

### Requirements

 - CET 1.20+
 - [FSDiscordRPC](https://github.com/Marco4413/FSDiscordRPC) (needed to actually update Discord)

### Why is it so complicated to use?

It's complicated because **I didn't want to make a DLL** and try to do weird stuff in C++.
This also **improves the stability of the mod** (it won't randomly crash your game).

**If you don't like that you can check out [Willi-JL's Discord RPC](https://github.com/Willy-JL/CP77-Discord-RPC)
mod** but be warned that **the reason I made this mod is because the one I linked didn't work properly for me**,
it caused **random game crashes** (probably because of I/O errors on the C++ part).

## Development

To improve your dev experience follow the README in [libs/cet](libs/cet).
