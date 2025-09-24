# Level 01 - Basic Transfer
# Define level data as global variables that will be concatenated

LEVELS = LEVELS || {}

LEVELS[1] = {
  name: "Basic Transfer"
  water_sources: [
    {
      x: 45           # Source point X position
      y: 85           # Source point Y position
      total_amount: 80  # Total particles to spawn
      spawn_rate: 2   # Particles per frame when spawning
      spawn_angle: 90 # Degrees (90 = straight down)
      spawn_velocity: 1.5  # Initial velocity
    }
  ]
  target_area: {
    target_litres: 10.0
    points: [
      { x: 182, y: 90 },
      { x: 208, y: 90 },
      { x: 208, y: 128 },
      { x: 182, y: 128 }
    ]
  }
  obstacles: [
    { x1: 100, y1: 70, x2: 140, y2: 70, bounce: 0.5 }
    { x1: 120, y1: 50, x2: 120, y2: 80, bounce: 0.4 }
    # Target area walls (3-sided container)
    { x1: 180, y1: 130, x2: 210, y2: 130, bounce: 0.3 }  # Bottom wall
    { x1: 180, y1: 90, x2: 180, y2: 130, bounce: 0.4 }   # Left wall
    { x1: 210, y1: 90, x2: 210, y2: 130, bounce: 0.4 }   # Right wall
  ]
  moon_start: { x: 60, y: 40 }
}