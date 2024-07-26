# Tic-Tac-Toe on the Atari 2600

![Screenshot 1](https://github.com/lawrencecandilas/atari-2600/blob/main/Tic%20Tac%20Toe/Screenshot-01.png?raw=true)

![Screenshot 2](https://github.com/lawrencecandilas/atari-2600/blob/main/Tic%20Tac%20Toe/Screenshot-02.png?raw=true)

## History

Most of this stems from initial code written in 2004 when I first found
that PDF of the Stella Programmer's Manual.  I then sought to fulfill a
long-time childhood dream - making an Atari 2600 game.

I published that code in the AtariAge forum under a different moniker.  As
the game code doesn't occupy much space, I decided to be silly and include a
"Set Up" screen (something most Atari games didn't have) which allowed
setting the screen colors, selecting the CPU strategy routine, and turning
the sound on and off.

Well, it's 2024 now.  I've streamlined and taken all that out.  This is just
the game - well, it does have a BRK handler and a ROM checksum routine. :P

Sound is now working.

## Development

In 2004 I was using DASM, and assembling with this command:

`dasm ttt.asm -f3 -ottt.bin`

and then using z26 to test.  Not too bad.

But...

Recently, while finding out Javascript/WASM is now powerful enough that
there are things like Emscripten, I ran into 8bitworkshop
(https://8bitworkshop.com/) and saw that it included a rather nice IDE for
the 2600, including the Javatari emulator.

I was *especially pleased* to see that I could paste my old code right in
the IDE window and immediately see the game running.

So I decided to clean it up and finish it.

Not yet tested on a real Atari 2600.  Well tested in Javatari and somewhat
in Z26.

## How To Play

Just in case you don't know how to play Tic-Tac-Toe: 

- You are either X or O, X always moves first.
- You and the other player take turns placing your symbol in one of 9 squares on a 3x3 grid.  
- If you get 3 in a row, you win a point and get to be X the next round.
- If all 9 squares get full with neither player getting 3 in a row, the match is a draw and is replayed until someone does get 3 in a row.
- First player to get 10 or more points wins the game.

Press GAME SELECT to choose from one of four variations:

-  P1  vs. CPU
-  P1  vs.  P2
- CPU  vs.  P2
- CPU  vs. CPU

P1 is always the LEFT joystick, and P2 is always the RIGHT joystick.

First player to win 10 matches wins the game.

You can interrupt the current game at any time by pressing GAME SELECT or GAME RESET.

Ties cause the current match to be replayed, until someone wins.

## Controls

Tic-Tac-Toe uses the joystick controller.  

Paddles and other controllers other than the standard joystick are not supported.  

When it is your turn, a blinking cursor will display.  Move by moving the joystick in the desired direction.  Press the joystick button to choose your space.  You can't move in a space where an X or O already exists.

The CPU vs. CPU variation is non-interactive.  You can interrupt the CPU playing itself by pressing GAME SELECT or GAME START.

The COLOR/B-W switch is supported.

The LEFT difficulty will change who is X and O to start.  If a game is in progress, changes to this switch take effect after the current game ends, or is interrupted with GAME SELECT or GAME START switches.

The RIGHT difficulty does nothing.

### ROM Checksum Screen

If you hold down GAME SELECT and GAME START together while turning the power on, the game will enter a blue "C" ROM checksum screen.  If you see an E, it means the computed checksum (shown on the screen) doesn't match the internally stored good value.  

Power cycle the Atari 2600 without holding the switches down to resume normal play.

## Strategy

At the beginning of each match, currently the CPU "intelligence" is chosen randomly.  

Sometimes the CPU will be really stupid and sometimes the CPU will be really smart.

Taking the center square if open is typically a good move.

## Blue Screen

If you run into a blue "E" screen during play, check your emulator settings.  If you are playing on real hardware, check your cartridge connection for dirt, debris or other issues, or make sure any "mapper detection" is disabled.  

You may also see this if you "fry" the cartridge and the game executes a BRK opcode or a data integrity error prevents the CPU from finding an open square after 10 tries.  Power cycle the Atari 2600 to recover.

## License

Released under GPLv3.
