# Moon - TIC-80 Fluid Simulation Game
# Author: Carl Lange
# Description: Control the moon to manipulate tides in puzzle levels

# Constants
WATER_COLOR = 9   # Blue
POOL_COLOR = 15   # White
MOON_COLOR = 14   # Yellow
GRAVITY = 0.15
MOON_PULL = 0.3             # Increased pull strength for more dramatic effects
MOON_RADIUS = 300           # Even larger gravitational influence radius (covers whole screen)
MOON_SIZE = 18               # Physical collision radius of moon body
# Simple particle physics parameters
PARTICLE_SPACING = 4.0      # Natural spacing between particles
REPEL_STRENGTH = 0.8        # How much particles push apart when too close
ATTRACT_STRENGTH = 0.3      # Light attraction to maintain cohesion
DAMPING = 0.92              # Velocity damping
VISCOSITY = 0.08            # Velocity smoothing between neighbors
MAX_PARTICLES = 800         # Even more particles for better filling
CLUSTER_DISTANCE = 6        # Distance threshold for grouping particles into water bodies

# Game state
game =
  state: "menu" # menu, level_select, playing, won, gameover
  current_level: 1
  selected_level: 1  # For level selection screen
  timer: 0
  moon_enabled: false  # Toggle for moon's gravitational pull (start disabled)
  water_in_target: 0
  total_particles: 0
  # Water source tracking
  water_sources: []  # Copy of current level's water sources
  spawned_particles: []  # Track particles spawned per source

# Moon (player controls this)
moon =
  x: 60
  y: 40
  speed: 1.5

# Water particles system
water_particles = []

# Simple distance-based force functions
# Calculate repulsion force when particles are too close
repulsion_force = (distance, target_distance) ->
  if distance >= target_distance or distance <= 0.1
    return 0
  return REPEL_STRENGTH * (target_distance - distance) / target_distance

# Calculate light attraction to maintain water cohesion
attraction_force = (distance, max_distance) ->
  if distance >= max_distance or distance <= 0.1
    return 0
  return ATTRACT_STRENGTH * (distance / max_distance) * 0.1

# Check collision with moon (circular collider)
check_moon_collision = (particle) ->
  dx = particle.x - moon.x
  dy = particle.y - moon.y
  distance = Math.sqrt(dx * dx + dy * dy)

  if distance <= MOON_SIZE and distance > 0.1
    # Calculate normal (direction away from moon center)
    normal_x = dx / distance
    normal_y = dy / distance

    return {
      collision: true
      normal_x: normal_x
      normal_y: normal_y
      distance: distance
    }

  return { collision: false }

# Check collision between moon (circle) and line colliders
check_moon_line_collision = (collider) ->
  # Moon center and radius
  cx = moon.x
  cy = moon.y
  radius = MOON_SIZE

  # Line endpoints
  x1 = collider.x1
  y1 = collider.y1
  x2 = collider.x2
  y2 = collider.y2

  # Calculate line length squared
  line_length_sq = (x2 - x1) * (x2 - x1) + (y2 - y1) * (y2 - y1)

  if line_length_sq == 0
    # Line is a point
    distance = Math.sqrt((cx - x1) * (cx - x1) + (cy - y1) * (cy - y1))
    if distance <= radius
      # Calculate normal away from line point
      if distance > 0.1
        normal_x = (cx - x1) / distance
        normal_y = (cy - y1) / distance
      else
        normal_x = 0
        normal_y = -1

      return {
        collision: true
        normal_x: normal_x
        normal_y: normal_y
        penetration: radius - distance
      }

  # Calculate projection parameter
  t = Math.max(0, Math.min(1, ((cx - x1) * (x2 - x1) + (cy - y1) * (y2 - y1)) / line_length_sq))

  # Find closest point on line segment
  closest_x = x1 + t * (x2 - x1)
  closest_y = y1 + t * (y2 - y1)

  # Check distance from moon center to closest point
  distance = Math.sqrt((cx - closest_x) * (cx - closest_x) + (cy - closest_y) * (cy - closest_y))

  if distance <= radius
    # Calculate normal vector (away from line toward moon center)
    if distance > 0.1
      normal_x = (cx - closest_x) / distance
      normal_y = (cy - closest_y) / distance
    else
      # If moon center is on line, use line perpendicular
      line_dx = x2 - x1
      line_dy = y2 - y1
      normal_x = -line_dy
      normal_y = line_dx
      normal_length = Math.sqrt(normal_x * normal_x + normal_y * normal_y)
      if normal_length > 0
        normal_x /= normal_length
        normal_y /= normal_length

    return {
      collision: true
      normal_x: normal_x
      normal_y: normal_y
      penetration: radius - distance
    }

  return { collision: false }

# Physics colliders system
colliders = []

# Game constants
win_threshold = 0.85  # Need 85% of water in target area
# Water volume constants (each particle represents ~0.1L)
LITRES_PER_PARTICLE = 0.1
TARGET_LITRES = 10.0  # Target amount of water needed in the target area (will be set per level)

# Target area - will be set by level loading
target_area = {
  points: []
}

# Load level data and set up game objects
load_level = (level_number) ->
  level = LEVELS[level_number]
  if not level
    trace "Error: Level #{level_number} not found"
    return false

  # Update global objects with level data
  target_area := level.target_area
  TARGET_LITRES := level.target_area.target_litres

  # Set up water sources
  game.water_sources = level.water_sources or []
  game.spawned_particles = []
  for i from 0 to game.water_sources.length - 1
    game.spawned_particles.push 0  # Track particles spawned per source

  # Set moon starting position
  moon.x = level.moon_start.x
  moon.y = level.moon_start.y

  # Initialize colliders for this level
  init_level_colliders level

  # Initialize water for this level
  init_level_water level

  trace "Loaded level #{level_number}: #{level.name}"
  return true

# Initialize colliders based on level data
init_level_colliders = (level) ->
  colliders := []

  # Add level-specific obstacles
  for obstacle in level.obstacles
    add_line_collider obstacle.x1, obstacle.y1, obstacle.x2, obstacle.y2, obstacle.bounce

# No more cup-related helper functions - all colliders are defined in level obstacles

# Helper function to add custom colliders
add_line_collider = (x1, y1, x2, y2, bounce = 0.5) ->
  colliders.push {
    type: "line"
    x1: x1
    y1: y1
    x2: x2
    y2: y2
    bounce: bounce
  }

# Generic collision detection for different collider types
check_collision = (particle, collider) ->
  switch collider.type
  | "line" =>
    # Point-to-line distance collision detection
    x1 = collider.x1
    y1 = collider.y1
    x2 = collider.x2
    y2 = collider.y2
    px = particle.x
    py = particle.y

    # Calculate line length squared
    line_length_sq = (x2 - x1) * (x2 - x1) + (y2 - y1) * (y2 - y1)

    if line_length_sq == 0
      # Line is a point
      distance_sq = (px - x1) * (px - x1) + (py - y1) * (py - y1)
      return if Math.sqrt(distance_sq) <= 1 then { collision: true, normal_x: 0, normal_y: 1 } else { collision: false }

    # Calculate projection parameter
    t = Math.max(0, Math.min(1, ((px - x1) * (x2 - x1) + (py - y1) * (y2 - y1)) / line_length_sq))

    # Find closest point on line segment
    closest_x = x1 + t * (x2 - x1)
    closest_y = y1 + t * (y2 - y1)

    # Check distance
    distance_sq = (px - closest_x) * (px - closest_x) + (py - closest_y) * (py - closest_y)

    if Math.sqrt(distance_sq) <= 2  # 2 pixel collision threshold for better detection
      # Calculate normal vector (perpendicular to line)
      line_dx = x2 - x1
      line_dy = y2 - y1
      normal_x = -line_dy
      normal_y = line_dx
      # Normalize
      normal_length = Math.sqrt(normal_x * normal_x + normal_y * normal_y)
      if normal_length > 0
        normal_x /= normal_length
        normal_y /= normal_length

      # Ensure normal points away from particle
      to_particle_x = px - closest_x
      to_particle_y = py - closest_y
      if normal_x * to_particle_x + normal_y * to_particle_y < 0
        normal_x = -normal_x
        normal_y = -normal_y

      return { collision: true, normal_x: normal_x, normal_y: normal_y, closest_x: closest_x, closest_y: closest_y }

    return { collision: false }

# Initialize water system for level (starts empty, water spawns from sources)
init_level_water = (level) ->
  water_particles := []
  game.total_particles = 0

  # Water will spawn from sources during gameplay
  # Calculate total particles that will eventually spawn
  total_to_spawn = 0
  if level.water_sources
    for source in level.water_sources
      total_to_spawn += source.total_amount

  # All levels now use source points
  game.total_particles = total_to_spawn

# Legacy function for compatibility
init_water = ->
  init_level_water LEVELS[game.current_level]

# Check if a particle is inside the target area polygon
particle_in_target_area = (particle) ->
  return point_in_polygon(particle.x, particle.y, target_area.points)

# Spawn water from sources
update_water_sources = ->
  if not game.water_sources or game.water_sources.length == 0
    return

  for i from 0 to game.water_sources.length - 1
    source = game.water_sources[i]
    spawned = game.spawned_particles[i]

    # Check if this source still has particles to spawn
    if spawned < source.total_amount
      # Spawn particles based on spawn rate
      particles_to_spawn = Math.min(source.spawn_rate, source.total_amount - spawned)

      for j from 0 to particles_to_spawn - 1
        # Convert angle to radians
        angle_rad = (source.spawn_angle * Math.PI) / 180

        # Calculate initial velocity components
        vx = Math.sin(angle_rad) * source.spawn_velocity
        vy = Math.cos(angle_rad) * source.spawn_velocity

        # Add small random variation
        random_angle = (Math.random! - 0.5) * 0.3  # ±0.15 radians variance
        vx += Math.sin(angle_rad + random_angle) * source.spawn_velocity * 0.2
        vy += Math.cos(angle_rad + random_angle) * source.spawn_velocity * 0.2

        water_particles.push {
          x: source.x + Math.random! * 2 - 1  # Small positional variance
          y: source.y + Math.random! * 2 - 1
          vx: vx
          vy: vy
        }

        game.spawned_particles[i]++

# Update water distribution tracking
update_water_tracking = ->
  # Count particles in target area
  game.water_in_target = 0

  for particle in water_particles
    if particle_in_target_area(particle)
      game.water_in_target++

  # Check win condition - need target amount of litres in target area
  target_litres = game.water_in_target * LITRES_PER_PARTICLE
  if target_litres >= TARGET_LITRES
    game.state = "won"

# Update water physics - simple stable particle system
update_water = ->
  # Apply forces to each particle
  for i from 0 to water_particles.length - 1
    particle = water_particles[i]

    # Apply gravity
    particle.vy += GRAVITY

    # Apply moon's gravitational pull (only if enabled)
    if game.moon_enabled
      moon_dx = moon.x - particle.x
      moon_dy = moon.y - particle.y
      moon_distance = Math.sqrt(moon_dx * moon_dx + moon_dy * moon_dy)

      if moon_distance < MOON_RADIUS and moon_distance > 0
        # Gravitational force with much stronger distance falloff (inverse square-like)
        distance_factor = (1 - moon_distance / MOON_RADIUS)
        moon_force = MOON_PULL * distance_factor * distance_factor * distance_factor  # Cubic falloff for very gentle pull
        particle.vx += (moon_dx / moon_distance) * moon_force
        particle.vy += (moon_dy / moon_distance) * moon_force

    # Inter-particle forces for natural spacing
    for j from 0 to water_particles.length - 1
      if i != j
        other = water_particles[j]
        dx = particle.x - other.x
        dy = particle.y - other.y
        distance = Math.sqrt(dx * dx + dy * dy)

        if distance > 0.1 and distance < PARTICLE_SPACING * 3
          # Normalize direction
          norm_dx = dx / distance
          norm_dy = dy / distance

          # Repulsion when too close (maintain spacing)
          if distance < PARTICLE_SPACING
            repel = repulsion_force(distance, PARTICLE_SPACING)
            particle.vx += norm_dx * repel
            particle.vy += norm_dy * repel

          # Light attraction for cohesion when not too far
          else if distance < PARTICLE_SPACING * 2
            attract = attraction_force(distance, PARTICLE_SPACING * 2)
            particle.vx -= norm_dx * attract
            particle.vy -= norm_dy * attract

          # Viscosity - smooth out velocity differences
          if distance < PARTICLE_SPACING * 1.5
            vel_diff_x = other.vx - particle.vx
            vel_diff_y = other.vy - particle.vy
            particle.vx += vel_diff_x * VISCOSITY
            particle.vy += vel_diff_y * VISCOSITY

    # Apply damping
    particle.vx *= DAMPING
    particle.vy *= DAMPING

    # Update position
    particle.x += particle.vx
    particle.y += particle.vy

    # Store position before collision check
    old_x = particle.x
    old_y = particle.y

    # Check collisions with all colliders
    for collider in colliders
      collision_result = check_collision(particle, collider)
      if collision_result.collision
        # Move particle back to safe position first
        particle.x = collision_result.closest_x + collision_result.normal_x * 3
        particle.y = collision_result.closest_y + collision_result.normal_y * 3

        # Reflect velocity if moving towards wall
        dot_product = particle.vx * collision_result.normal_x + particle.vy * collision_result.normal_y

        if dot_product < 0
          # Reflect velocity with bounce factor
          particle.vx -= dot_product * collision_result.normal_x * (1 + collider.bounce)
          particle.vy -= dot_product * collision_result.normal_y * (1 + collider.bounce)

          # Add friction
          particle.vx *= 0.6
          particle.vy *= 0.7
        else
          # If not moving towards wall, just stop the velocity component
          particle.vx *= 0.8
          particle.vy *= 0.8

    # Check collision with moon (always acts as solid object)
    moon_collision = check_moon_collision(particle)
    if moon_collision.collision
      # Push particle away from moon center
      push_distance = MOON_SIZE - moon_collision.distance + 1
      particle.x += moon_collision.normal_x * push_distance
      particle.y += moon_collision.normal_y * push_distance

      # Reflect velocity away from moon
      dot_product = particle.vx * moon_collision.normal_x + particle.vy * moon_collision.normal_y
      if dot_product < 0
        if game.moon_enabled
          # When gravity is on, gentler collision (particles can "orbit")
          particle.vx -= dot_product * moon_collision.normal_x * 0.8
          particle.vy -= dot_product * moon_collision.normal_y * 0.8
          particle.vx *= 0.9
          particle.vy *= 0.9
        else
          # When gravity is off, stronger collision (solid object)
          particle.vx -= dot_product * moon_collision.normal_x * 1.5
          particle.vy -= dot_product * moon_collision.normal_y * 1.5
          particle.vx *= 0.7
          particle.vy *= 0.7

    # Keep particles within screen bounds
    if particle.x < 2
      particle.x = 2
      particle.vx = Math.abs(particle.vx) * 0.5
    if particle.x > 237
      particle.x = 237
      particle.vx = -Math.abs(particle.vx) * 0.5
    if particle.y < 2
      particle.y = 2
      particle.vy = Math.abs(particle.vy) * 0.5
    if particle.y > 133
      particle.y = 133
      particle.vy = -Math.abs(particle.vy) * 0.5

# Draw level background elements (water sources and target area)
draw_level_background = ->
  # Calculate current water amount in target area only
  target_litres_current = Math.floor(game.water_in_target * LITRES_PER_PARTICLE * 10) / 10

  # Draw water sources
  draw_water_sources!

  # Draw target area (arbitrary polygon)
  draw_target_area target_litres_current

# Draw level colliders (obstacles and walls)
draw_level_colliders = ->
  # Draw obstacles (colliders above water)
  draw_obstacles!

# Draw level obstacles
draw_obstacles = ->
  for collider in colliders
    if collider.type == "line"
      # Draw all colliders (obstacles and walls)
      line collider.x1, collider.y1, collider.x2, collider.y2, 15
      line collider.x1 + 1, collider.y1, collider.x2 + 1, collider.y2, 15  # Thicker line

# No more cup drawing functions - all areas are polygonal

# Draw water sources
draw_water_sources = ->
  if not game.water_sources
    return

  for i from 0 to game.water_sources.length - 1
    source = game.water_sources[i]
    spawned = game.spawned_particles[i] or 0

    # Draw source point
    if spawned < source.total_amount
      # Active source - pulsing blue
      color = if (game.timer % 30) < 15 then 9 else 12
      circ source.x, source.y, 4, color
      circb source.x, source.y, 4, 15
    else
      # Depleted source - grey
      circ source.x, source.y, 4, 5
      circb source.x, source.y, 4, 6

    # Draw direction indicator
    angle_rad = (source.spawn_angle * Math.PI) / 180
    end_x = source.x + Math.sin(angle_rad) * 8
    end_y = source.y + Math.cos(angle_rad) * 8
    line source.x, source.y, end_x, end_y, 15

    # Show remaining water count (small text)
    remaining = source.total_amount - spawned
    if remaining > 0
      print "#{remaining}", source.x - 6, source.y - 15, 15, false, 1, true

# Draw target area polygon with labels
draw_target_area = (current_litres) ->
  # Draw polygon outline
  points = target_area.points
  for i from 0 to points.length - 1
    p1 = points[i]
    p2 = points[(i + 1) % points.length]
    line p1.x, p1.y, p2.x, p2.y, 11  # Light green
    line p1.x + 1, p1.y, p2.x + 1, p2.y, 11  # Thicker line

  # Fill area lightly to show it's a target
  fill_convex_polygon points, 3  # Dark green fill

  # Calculate center point for labels
  center_x = 0
  center_y = 0
  for point in points
    center_x += point.x
    center_y += point.y
  center_x = Math.floor(center_x / points.length)
  center_y = Math.floor(center_y / points.length)

  # Display target info at center (using smaller text)
  print "TARGET", center_x - 15, center_y - 10, 15, false, 1, true  # smallfont=true
  print "Need: #{TARGET_LITRES}L", center_x - 20, center_y - 2, 11, false, 1, true
  print "#{current_litres}L", center_x - 8, center_y + 6, if current_litres >= TARGET_LITRES then 11 else 6, false, 1, true

# Convex hull using Graham scan
convex_hull = (points) ->
  if points.length < 3
    return points

  # Find the bottom-most point (and leftmost in case of tie)
  start = points[0]
  for point in points
    if point.y > start.y or (point.y == start.y and point.x < start.x)
      start = point

  # Sort points by polar angle with respect to start point
  polar_angle = (p1, p2) ->
    dx1 = p1.x - start.x
    dy1 = p1.y - start.y
    dx2 = p2.x - start.x
    dy2 = p2.y - start.y
    cross = dx1 * dy2 - dy1 * dx2
    if cross == 0
      # If collinear, sort by distance
      return (dx1 * dx1 + dy1 * dy1) - (dx2 * dx2 + dy2 * dy2)
    return -cross

  sorted_points = points.slice!
  sorted_points.sort polar_angle

  # Graham scan
  hull = []
  for point in sorted_points
    # Remove points that make right turn
    while hull.length >= 2
      p1 = hull[hull.length - 2]
      p2 = hull[hull.length - 1]
      cross = (p2.x - p1.x) * (point.y - p1.y) - (p2.y - p1.y) * (point.x - p1.x)
      if cross <= 0
        hull.pop!
      else
        break
    hull.push point

  return hull

# Clip polygon against a line using Sutherland-Hodgman algorithm
clip_polygon_against_line = (polygon, x1, y1, x2, y2) ->
  if polygon.length == 0
    return []

  # Calculate line normal (pointing to the "inside" half-space)
  line_dx = x2 - x1
  line_dy = y2 - y1
  # Normal pointing to the right of the line direction (for proper cup containment)
  normal_x = -line_dy
  normal_y = line_dx

  # Normalize the normal
  normal_length = Math.sqrt(normal_x * normal_x + normal_y * normal_y)
  if normal_length > 0
    normal_x /= normal_length
    normal_y /= normal_length

  clipped = []

  for i from 0 to polygon.length - 1
    current = polygon[i]
    next_point = polygon[(i + 1) % polygon.length]

    # Calculate distances from line (positive = inside, negative = outside)
    current_dist = (current.x - x1) * normal_x + (current.y - y1) * normal_y
    next_dist = (next_point.x - x1) * normal_x + (next_point.y - y1) * normal_y

    if current_dist >= 0 # Current point is inside
      if next_dist >= 0 # Next point is also inside
        clipped.push next_point
      else # Next point is outside - need intersection
        # Calculate intersection
        total_dist = current_dist - next_dist
        if Math.abs(total_dist) > 0.001
          t = current_dist / total_dist
          intersection_x = current.x + t * (next_point.x - current.x)
          intersection_y = current.y + t * (next_point.y - current.y)
          clipped.push { x: intersection_x, y: intersection_y }
    else # Current point is outside
      if next_dist >= 0 # Next point is inside
        # Calculate intersection and add it plus next point
        total_dist = current_dist - next_dist
        if Math.abs(total_dist) > 0.001
          t = current_dist / total_dist
          intersection_x = current.x + t * (next_point.x - current.x)
          intersection_y = current.y + t * (next_point.y - current.y)
          clipped.push { x: intersection_x, y: intersection_y }
        clipped.push next_point

  return clipped

# Clip convex hull against all colliders - simple approach
clip_hull_against_colliders = (hull) ->
  clipped_hull = hull

  for collider in colliders
    if collider.type == "line" and clipped_hull.length > 2
      # Simple clipping - let the algorithm determine normals automatically
      clipped_hull = clip_polygon_against_line(clipped_hull, collider.x1, collider.y1, collider.x2, collider.y2)

      # Safety check - if clipping removes too much, skip this collider
      if clipped_hull.length < 3
        break

  return clipped_hull

# Fill polygon using scanline algorithm (simplified)
fill_convex_polygon = (hull, color) ->
  if hull.length < 3
    return

  # Find y bounds
  min_y = hull[0].y
  max_y = hull[0].y
  for point in hull
    min_y = Math.min(min_y, point.y)
    max_y = Math.max(max_y, point.y)

  # For each scanline
  for y from Math.floor(min_y) to Math.floor(max_y)
    intersections = []

    # Find intersections with polygon edges
    for i from 0 to hull.length - 1
      j = (i + 1) % hull.length
      p1 = hull[i]
      p2 = hull[j]

      if (p1.y <= y and p2.y > y) or (p2.y <= y and p1.y > y)
        # Calculate intersection x
        if p2.y != p1.y
          x = p1.x + (y - p1.y) * (p2.x - p1.x) / (p2.y - p1.y)
          intersections.push Math.floor(x)

    # Sort intersections and fill between pairs
    intersections.sort (a, b) -> a - b
    for i from 0 to intersections.length - 1 by 2
      if i + 1 < intersections.length
        x1 = Math.max(0, intersections[i])
        x2 = Math.min(239, intersections[i + 1])
        for x from x1 to x2
          pix x, y, color

# Check if line segment between two points crosses any collider
line_crosses_collider = (x1, y1, x2, y2) ->
  for collider in colliders
    if collider.type == "line"
      # Line-line intersection test
      cx1 = collider.x1
      cy1 = collider.y1
      cx2 = collider.x2
      cy2 = collider.y2

      # Calculate intersection using parametric form
      denom = (x1 - x2) * (cy1 - cy2) - (y1 - y2) * (cx1 - cx2)
      if Math.abs(denom) > 0.001  # Lines are not parallel
        t = ((x1 - cx1) * (cy1 - cy2) - (y1 - cy1) * (cx1 - cx2)) / denom
        u = -((x1 - x2) * (y1 - cy1) - (y1 - y2) * (x1 - cx1)) / denom

        # Check if intersection point lies on both line segments
        if t >= 0 and t <= 1 and u >= 0 and u <= 1
          return true

  return false

# Cluster particles by distance, but split at walls
cluster_particles = (particles, max_distance = 15) ->
  clusters = []
  visited = new Array(particles.length).fill(false)

  for i from 0 to particles.length - 1
    if not visited[i]
      cluster = [particles[i]]
      visited[i] = true

      # Find all connected particles (but don't cross walls)
      queue = [i]
      while queue.length > 0
        current_idx = queue.shift!
        current = particles[current_idx]

        for j from 0 to particles.length - 1
          if not visited[j]
            other = particles[j]
            dx = current.x - other.x
            dy = current.y - other.y
            distance = Math.sqrt(dx * dx + dy * dy)

            # Only connect if within distance AND no wall between them
            if distance <= max_distance and not line_crosses_collider(current.x, current.y, other.x, other.y)
              cluster.push(other)
              visited[j] = true
              queue.push(j)

      clusters.push(cluster)

  return clusters

# Check if a point is inside any polygon using ray casting
point_in_polygon = (px, py, polygon) ->
  if polygon.length < 3
    return false

  inside = false
  j = polygon.length - 1

  for i from 0 to polygon.length - 1
    xi = polygon[i].x
    yi = polygon[i].y
    xj = polygon[j].x
    yj = polygon[j].y

    if ((yi > py) != (yj > py)) and (px < (xj - xi) * (py - yi) / (yj - yi) + xi)
      inside = not inside

    j = i

  return inside

# Expand hull outward by a given radius and round corners
expand_and_round_hull = (hull, radius) ->
  if hull.length < 3
    return hull

  expanded_points = []

  for i from 0 to hull.length - 1
    current = hull[i]
    prev = hull[(i - 1 + hull.length) % hull.length]
    next = hull[(i + 1) % hull.length]

    # Calculate edge vectors
    edge1_x = current.x - prev.x
    edge1_y = current.y - prev.y
    edge2_x = next.x - current.x
    edge2_y = next.y - current.y

    # Normalize edge vectors
    edge1_len = Math.sqrt(edge1_x * edge1_x + edge1_y * edge1_y)
    edge2_len = Math.sqrt(edge2_x * edge2_x + edge2_y * edge2_y)

    if edge1_len > 0
      edge1_x /= edge1_len
      edge1_y /= edge1_len
    if edge2_len > 0
      edge2_x /= edge2_len
      edge2_y /= edge2_len

    # Calculate inward normals
    normal1_x = edge1_y
    normal1_y = -edge1_x
    normal2_x = edge2_y
    normal2_y = -edge2_x

    # Average the normals for corner direction
    avg_normal_x = (normal1_x + normal2_x) * 0.5
    avg_normal_y = (normal1_y + normal2_y) * 0.5

    # Normalize average normal
    avg_len = Math.sqrt(avg_normal_x * avg_normal_x + avg_normal_y * avg_normal_y)
    if avg_len > 0.01
      avg_normal_x /= avg_len
      avg_normal_y /= avg_len

      # Calculate expansion distance (account for corner angle)
      dot_product = normal1_x * normal2_x + normal1_y * normal2_y
      angle_factor = Math.max(0.5, Math.min(2.0, 1.0 / Math.max(0.1, Math.abs(dot_product))))
      expansion_distance = radius * angle_factor

      # Expand point outward
      expanded_points.push {
        x: current.x + avg_normal_x * expansion_distance
        y: current.y + avg_normal_y * expansion_distance
      }
    else
      # Fallback if normal calculation fails
      expanded_points.push { x: current.x, y: current.y }

  return expanded_points

# Draw water particles with smooth hull rendering
draw_water = ->
  hulls = []

  if water_particles.length > 2
    # Cluster particles by proximity for hulls
    clusters = cluster_particles(water_particles, CLUSTER_DISTANCE)

    # Draw convex hull for each cluster and store hulls
    for cluster in clusters
      if cluster.length >= 3  # Need at least 3 points for hull
        points = []
        for particle in cluster
          points.push { x: particle.x, y: particle.y }

        hull = convex_hull(points)
        # Expand hull by circle radius for better coverage
        expanded_hull = expand_and_round_hull(hull, 1.5)
        hulls.push(expanded_hull)
        # Draw expanded hull in same color as particles for seamless look
        fill_convex_polygon(expanded_hull, WATER_COLOR)

  # Draw individual particles only if they're NOT inside any hull
  for particle in water_particles
    x = Math.floor(particle.x)
    y = Math.floor(particle.y)

    # Check if particle is inside any hull
    particle_in_hull = false
    for hull in hulls
      if point_in_polygon(particle.x, particle.y, hull)
        particle_in_hull = true
        break

    # Only draw particle if it's not covered by a hull
    if not particle_in_hull
      # Draw particle as a small circle
      circ particle.x, particle.y, 2, WATER_COLOR

# Draw moon with gravitational field visualization
draw_moon = ->
  if game.moon_enabled
    # Draw moon with gravitational field
    circ moon.x, moon.y, MOON_SIZE, MOON_COLOR
    circb moon.x, moon.y, MOON_SIZE, 12  # Lighter border

    # Draw gravitational field (subtle, less frequent updates)
    if game.timer % 30 < 15  # Slower pulsing for performance
      circb moon.x, moon.y, 30, 1  # Inner field ring
      circb moon.x, moon.y, 60, 1  # Middle field ring
      circb moon.x, moon.y, 90, 1  # Outer field ring
  else
    # Draw moon as solid physical object (no field)
    circ moon.x, moon.y, MOON_SIZE, 6   # Grey solid moon
    circb moon.x, moon.y, MOON_SIZE, 5  # Darker grey border

# Initialize function
init = ->
  trace "Moon fluid simulation initialized"
  # Load default level (Level 1) for menu display
  load_level 1

# Main game loop
export TIC = ->
  if game.timer == 0
    init!

  game.timer++

  # Clear screen
  cls 0

  # Draw based on game state
  switch game.state
  | "menu" =>
    print "MOON TIDES", 85, 50, 15
    print "Control the moon to move water!", 50, 70, 7
    print "Arrow keys = Move moon", 65, 85, 6
    print "B = Toggle gravity on/off", 60, 95, 6
    print "Press A to select level", 70, 110, 7
    if btnp 4 # A button
      game.state = "level_select"

  | "level_select" =>
    print "SELECT LEVEL", 80, 30, 15
    print "Use UP/DOWN to choose", 60, 45, 7

    # Get available levels
    max_level = Math.max(...Object.keys(LEVELS).map(Number))

    # Handle navigation
    if btnp 0 # UP
      game.selected_level = Math.max(1, game.selected_level - 1)
    if btnp 1 # DOWN
      game.selected_level = Math.min(max_level, game.selected_level + 1)

    # Display level options
    for i from 1 to max_level
      level = LEVELS[i]
      if level
        y_pos = 65 + (i - 1) * 15
        color = if i == game.selected_level then 11 else 7
        cursor = if i == game.selected_level then "> " else "  "
        print "#{cursor}Level #{i}: #{level.name}", 50, y_pos, color
        if i == game.selected_level
          print "Target: #{level.target_area.target_litres}L", 60, y_pos + 8, 6

    # Confirm selection
    if btnp 4 # A button
      game.current_level = game.selected_level
      game.state = "playing"
      load_level game.current_level

    # Back to menu
    if btnp 5 # B button
      game.state = "menu"

  | "playing" =>
    # Handle moon movement
    if btn 0 then moon.y -= moon.speed # UP
    if btn 1 then moon.y += moon.speed # DOWN
    if btn 2 then moon.x -= moon.speed # LEFT
    if btn 3 then moon.x += moon.speed # RIGHT

    # Toggle moon gravity
    if btnp 5 # B button
      game.moon_enabled = not game.moon_enabled

    # Check moon collision with all colliders
    for collider in colliders
      if collider.type == "line"
        collision_result = check_moon_line_collision(collider)
        if collision_result.collision
          # Move moon out of collision
          moon.x += collision_result.normal_x * collision_result.penetration
          moon.y += collision_result.normal_y * collision_result.penetration

    # Keep moon on screen
    moon.x = Math.max(10, Math.min(230, moon.x))
    moon.y = Math.max(10, Math.min(126, moon.y))

    # Update physics
    update_water_sources!  # Spawn new water particles
    update_water!
    update_water_tracking!

    # Draw everything in proper order (back to front)
    draw_level_background!  # Draw cups and target area without colliders
    draw_water!             # Draw water above background but below colliders
    draw_level_colliders!   # Draw colliders above water
    draw_moon!              # Always draw moon (function handles enabled/disabled state)

    # Game UI
    print "Move moon to transfer water", 10, 10, 15
    print "B: Toggle gravity #{if game.moon_enabled then 'ON' else 'OFF'}", 10, 20, 7

    # Show total available water
    total_litres = Math.floor(game.total_particles * LITRES_PER_PARTICLE * 10) / 10
    print "Total water: #{total_litres}L", 10, 35, 7

  | "won" =>
    # Calculate final water amounts for win screen
    final_target_litres = Math.floor(game.water_in_target * LITRES_PER_PARTICLE * 10) / 10
    level = LEVELS[game.current_level]
    print "SUCCESS!", 90, 50, 11
    print "Level #{game.current_level}: #{level.name}", 45, 70, 7
    print "#{final_target_litres}L in target area", 55, 85, 15
    print "Press A to continue", 70, 105, 7
    print "Press B for level select", 60, 115, 6
    if btnp 4 # A button
      # Go to next level or back to level select
      max_level = Math.max(...Object.keys(LEVELS).map(Number))
      if game.current_level < max_level
        game.current_level++
        game.selected_level = game.current_level
        game.state = "playing"
        load_level game.current_level
      else
        game.state = "level_select"
    if btnp 5 # B button
      game.state = "level_select"

  | "gameover" =>
    print "GAME OVER", 80, 60, 15
    print "Press A to restart", 60, 100, 7
    if btnp 4 # A button
      # Reset game
      game.state = "menu"
      moon.x = 60
      moon.y = 40
