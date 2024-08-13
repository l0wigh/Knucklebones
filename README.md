# Knucklebones Online

This game is a recreation of the famous mini game from the game Cult of the Lamb.

The program serves as a server and client.

## How it's made ?

The game is coded in V language and uses TCP for online communication.

There is no GUI and it only works in a Terminal.

It can be compiled for Linux, Windows, MacOS using the V compiler.

## How to use ?

The host of the game, will need to open the port 1145 in it's router settings.

He will then launch the game using the command : `./knucklebones -u HostUsername -h`

The game will give him it's current IP address that he will need to send to the other player.

The client will use this command : `./knucklebones -u ClientUsername -c <IP Address>`

## Cheating issues

Yes, if a player modify the code, he can cheat easily in the game. Both the player are generating their own dices then send it by themselves.

The point here wasn't to do something secure, but something that works and is easy to modify.

## Hacking the source code

You can easily modify and tweak the game as you want.

The UI doesn't fit your needs -> Change it !

You want it to works inside a webbrowser -> Check how to create webpages using V !

You want to create a GUI for your friend that isn't a Terminal user -> V can do this !

You don't know how to code in V -> It's easy to understand how data are formatted and sent. You can make another client with any language that support TCP !

## Updates ?

If anything is broken, I'll fix it. But no updates will drop without this condition.
