# Godot 4 2D Platformer Character Controller
A ready-to-use script for a platformer character controller using GDScript in Godot 4; All functionalities and abilities are adjustable and/or toggleable within the `PlayerMovement.gd` script.

## Controls:
- Move Left: `A`
- Move Right: `D`
- Jump: `Space`
- Crouch: `S`
- Dash and Roll: `Shift`
  
## Horizontal Movement
- **Crouching**: make your hitbox smaller and fit under small spaces
- **Acceleration**: it takes some time to reach your max speed
- **Deceleration**: it takes some time to slow to a stop
- **Dash**: when in the air or on the ground, perform a short, but fast dash forwards
- **Roll**: when crouching on the ground, roll forwards

## Vertical Movement
- **Variable Jump**: jump higher or lower depending on how long you press the jump button
- **Fall Multiplier**: stronger gravity when falling
- **Low Jump Multiplier**: stronger gravity when the jump button is released
- **Coyote Time**: there is a short time after leaving the ground that the player can still jump
- **Jump Buffering**: if the player presses the jump button shortly before touching the ground they will still be able to jump

## Wall Movement
- **Wall Slide**: hold a direction into a wall to slowly slide down it
- **Wall Jump**: while wall sliding, press the jump button to jump off of the wall

