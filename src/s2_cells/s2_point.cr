class S2Cells::S2Point
  getter x : Float64
  getter y : Float64
  getter z : Float64

  def initialize(@x, @y, @z)
  end

  def abs
    {@x.abs, @y.abs, @z.abs}
  end

  def largest_abs_component : UInt64
    temp = abs

    if temp[0] > temp[1]
      temp[0] > temp[2] ? 0_u64 : 2_u64
    else
      temp[1] > temp[2] ? 1_u64 : 2_u64
    end
  end

  def dot_prod(o : S2Point)
    @x * o.x + @y * o.y + @z * o.z
  end
end
