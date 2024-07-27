struct S2Cells::Cap
  ROUND_UP = 1.0 + 1.0 / (1_u64 << 52)

  def initialize(@axis : Point = Point.new(1.0, 0.0, 0.0), @height : Float64 = -1.0)
  end

  def self.from_axis_height(axis : Point, height : Float64) : Cap
    raise "axis must be unit length" unless S2Cells.is_unit_length(axis)
    Cap.new(axis, height)
  end

  def self.from_axis_angle(axis : Point, angle : Angle) : Cap
    raise "axis must be unit length" unless S2Cells.is_unit_length(axis)
    raise "angle must be non-negative" unless angle.radians >= 0
    Cap.new(axis, get_height_for_angle(angle.radians))
  end

  def self.get_height_for_angle(radians : Float64) : Float64
    raise "radians must be non-negative" unless radians >= 0
    return 2.0 if radians >= Math::PI

    d = Math.sin(0.5 * radians)
    2 * d * d
  end

  def self.from_axis_area(axis : Point, area : Float64) : Cap
    raise "axis must be unit length" unless S2Cells.is_unit_length(axis)
    Cap.new(axis, area / (2 * Math::PI))
  end

  def self.empty : Cap
    Cap.new
  end

  def self.full : Cap
    Cap.new(Point.new(1.0, 0.0, 0.0), 2.0)
  end

  def height : Float64
    @height
  end

  def axis : Point
    @axis
  end

  def area : Float64
    2 * Math::PI * (@height > 0 ? @height : 0)
  end

  def angle : Angle
    return Angle.from_radians(-1) if is_empty?
    Angle.from_radians(2 * Math.asin(Math.sqrt(0.5 * @height)))
  end

  def is_valid? : Bool
    S2Cells.is_unit_length(@axis) && @height <= 2.0
  end

  def is_empty? : Bool
    @height < 0
  end

  def is_full? : Bool
    @height >= 2.0
  end

  def get_cap_bound : Cap
    self
  end

  def add_point(point : Point)
    raise "point must be unit length" unless S2Cells.is_unit_length(point)
    if is_empty?
      @axis = point
      @height = 0.0
    else
      dist2 = (@axis - point).norm2
      @height = {@height, ROUND_UP * 0.5 * dist2}.max
    end
  end

  def complement : Cap
    height = is_full? ? -1.0 : 2.0 - {@height, 0.0}.max
    Cap.from_axis_height(-@axis, height)
  end

  def contains(other : Cap | Point | Cell) : Bool
    case other
    in Cap
      return true if is_full? || other.is_empty?
      angle.radians >= @axis.angle(other.axis).radians + other.angle.radians
    in Point
      raise "point must be unit length" unless S2Cells.is_unit_length(other)
      (@axis - other).norm2 <= 2 * @height
    in Cell
      vertices = Array(Point).new(4)
      (0..3).each do |k|
        vertices[k] = other.get_vertex(k)
        return false unless contains(vertices[k])
      end
      !complement.intersects(other, vertices)
    end
  end

  def interior_contains(other : Point) : Bool
    raise "point must be unit length" unless S2Cells.is_unit_length(other)
    is_full? || (@axis - other).norm2 < 2 * @height
  end

  def intersects(other : Cap | Cell, vertices = Array(Point).new(4)) : Bool
    case other
    in Cap
      return false if is_empty? || other.is_empty?
      angle.radians + other.angle.radians >= @axis.angle(other.axis).radians
    in Cell
      return false if @height >= 1 || is_empty?
      return true if other.contains(@axis)
      sin2_angle = @height * (2 - @height)
      (0..3).each do |k|
        edge = other.get_edge_raw(k)
        dot = @axis.dot_prod(edge)
        next if dot > 0
        return false if dot * dot > sin2_angle * edge.norm2
        dir = edge.cross_prod(@axis)
        return true if dir.dot_prod(vertices[k]) < 0 && dir.dot_prod(vertices[(k + 1) & 3]) > 0
      end
      false
    end
  end

  def may_intersect(other : Cell) : Bool
    vertices = Array(Point).new(4)
    (0..3).each do |k|
      vertices[k] = other.get_vertex(k)
      return true if contains(vertices[k])
    end
    intersects(other, vertices)
  end

  def interior_intersects(other : Cap) : Bool
    return false if @height <= 0 || other.is_empty?
    angle.radians + other.angle.radians > @axis.angle(other.axis).radians
  end

  def get_rect_bound : LatLngRect
    return LatLngRect.empty if is_empty?

    axis_ll = LatLng.from_point(@axis)
    cap_angle = angle.radians

    all_longitudes = false
    lat, lng = [] of Float64, [] of Float64
    lng << -Math::PI
    lng << Math::PI

    lat << axis_ll.lat.radians - cap_angle
    if lat[0] <= -Math::PI / 2.0
      lat[0] = -Math::PI / 2.0
      all_longitudes = true
    end

    lat << axis_ll.lat.radians + cap_angle
    if lat[1] >= Math::PI / 2.0
      lat[1] = Math::PI / 2.0
      all_longitudes = true
    end

    unless all_longitudes
      sin_a = Math.sqrt(@height * (2 - @height))
      sin_c = Math.cos(axis_ll.lat.radians)
      if sin_a <= sin_c
        angle_a = Math.asin(sin_a / sin_c)
        lng[0] = drem(axis_ll.lng.radians - angle_a, 2 * Math::PI)
        lng[1] = drem(axis_ll.lng.radians + angle_a, 2 * Math::PI)
      end
    end

    LatLngRect.new(LineInterval.new(*lat), SphereInterval.new(*lng))
  end

  def approx_equals(other : Cap, max_error = 1e-14) : Bool
    (@axis.angle(other.axis).radians <= max_error && (@height - other.height).abs <= max_error) ||
      (is_empty? && other.height <= max_error) ||
      (other.is_empty? && @height <= max_error) ||
      (is_full? && other.height >= 2 - max_error) ||
      (other.is_full? && @height >= 2 - max_error)
  end

  def expanded(distance : Angle) : Cap
    raise "distance must be non-negative" unless distance.radians >= 0
    return Cap.empty if is_empty?
    Cap.from_axis_angle(@axis, angle + distance)
  end

  private def is_unit_length(point : Point) : Bool
    S2Cells.is_unit_length point
  end
end
