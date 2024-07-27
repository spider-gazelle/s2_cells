struct S2Cells::Point
  @point : Tuple(Float64, Float64, Float64)

  def initialize(x : Float64, y : Float64, z : Float64)
    @point = {x, y, z}
  end

  def [](index : Int)
    @point[index]
  end

  def -
    self.class.new(-@point[0], -@point[1], -@point[2])
  end

  def ==(other : Point)
    @point == other.@point
  end

  def hash
    @point.hash
  end

  def to_s
    "Point: #{@point}"
  end

  def +(other : Point)
    self.class.new(@point[0] + other[0],
      @point[1] + other[1],
      @point[2] + other[2])
  end

  def -(other : Point)
    self.class.new(@point[0] - other[0],
      @point[1] - other[1],
      @point[2] - other[2])
  end

  def *(other : Number)
    self.class.new(@point[0] * other,
      @point[1] * other,
      @point[2] * other)
  end

  def x : Float64
    @point[0]
  end

  def y : Float64
    @point[1]
  end

  def z : Float64
    @point[2]
  end

  def abs
    self.class.new(@point[0].abs,
      @point[1].abs,
      @point[2].abs)
  end

  def largest_abs_component
    temp = abs
    if temp[0] > temp[1]
      temp[0] > temp[2] ? 0 : 2
    else
      temp[1] > temp[2] ? 1 : 2
    end
  end

  def angle(other : Point)
    Math.atan2(cross_prod(other).norm, dot_prod(other))
  end

  def cross_prod(other : Point)
    x, y, z = @point
    ox, oy, oz = other.@point
    self.class.new(y * oz - z * oy,
      z * ox - x * oz,
      x * oy - y * ox)
  end

  def dot_prod(other : Point)
    x, y, z = @point
    ox, oy, oz = other.@point
    x * ox + y * oy + z * oz
  end

  def norm2
    x, y, z = @point
    x * x + y * y + z * z
  end

  def norm
    Math.sqrt(norm2)
  end

  def normalize
    n = norm
    n = 1.0 / n if n != 0
    self.class.new(@point[0] * n, @point[1] * n, @point[2] * n)
  end
end

# Define * for Number * Point
struct Number
  def *(point : Point)
    Point.new(self * point[0], self * point[1], self * point[2])
  end
end
