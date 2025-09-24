# Level 02 - Steep Challenge
# Define level data as global variables that will be concatenated

LEVELS = LEVELS || {}

LEVELS[2] = {
  name: "Steep Challenge"
  water_sources: [
    {
      x: 35           # High up on the left
      y: 20
      total_amount: 100  # Smaller amount for this level
      spawn_rate: 1   # Slower spawn rate
      spawn_angle: 0
      spawn_velocity: 0.0  # Higher initial velocity
    }
  ]
  # No target_cup - using V-shaped walls instead
  target_area: {
    target_litres: 7.0
    # Triangular target area
    points: [
      { x: 172, y: 100 },
      { x: 208, y: 100 },
      { x: 190, y: 128 }
    ]
  }
  obstacles: [
    # Ramp from source to target
    { x1: 80, y1: 65, x2: 130, y2: 85, bounce: 0.3 }
    # Barrier in middle
    { x1: 110, y1: 30, x2: 130, y2: 60, bounce: 0.5 }
    # Lower platform
    { x1: 140, y1: 95, x2: 165, y2: 95, bounce: 0.4 }
    # V-shaped target area walls
    { x1: 172, y1: 100, x2: 190, y2: 128, bounce: 0.4 }  # Left wall of V
    { x1: 208, y1: 100, x2: 190, y2: 128, bounce: 0.4 }  # Right wall of V
  ]
  moon_start: { x: 80, y: 30 }
}
