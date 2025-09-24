# Moon - TIC-80 Game
# Author: Carl Lange
# Description: A space adventure on the moon

# Game state
game =
  state: "menu" # menu, playing, gameover
  level: 1
  score: 0
  lives: 3
  timer: 0

# Player
player =
  x: 120
  y: 100
  speed: 2

# Game objects
objects = []

# Initialize function
init = ->
  trace "Moon game initialized"

# Main game loop
export TIC = ->
  if game.timer == 0
    init!

  game.timer++

  # Handle input
  if btn 0 then player.y -= player.speed # UP
  if btn 1 then player.y += player.speed # DOWN
  if btn 2 then player.x -= player.speed # LEFT
  if btn 3 then player.x += player.speed # RIGHT

  # Keep player on screen
  player.x = Math.max 0, Math.min 232, player.x
  player.y = Math.max 0, Math.min 128, player.y

  # Clear screen
  cls 0

  # Draw based on game state
  switch game.state
  | "menu" =>
    print "MOON", 100, 60, 15
    print "Press A to start", 70, 80, 7
    if btnp 4 # A button
      game.state = "playing"

  | "playing" =>
    # Draw player
    rect player.x, player.y, 8, 8, 15

    # Draw UI
    print "Score: #{game.score}", 10, 10, 15
    print "Lives: #{game.lives}", 10, 20, 15

  | "gameover" =>
    print "GAME OVER", 80, 60, 15
    print "Final Score: #{game.score}", 60, 80, 7
    print "Press A to restart", 60, 100, 7
    if btnp 4 # A button
      # Reset game
      game.state = "menu"
      game.score = 0
      game.lives = 3
      player.x = 120
      player.y = 100