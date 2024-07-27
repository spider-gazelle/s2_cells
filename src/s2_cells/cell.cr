struct S2Cells::Cell
  @uv : Array(Array(Float64))
  @cell_id : CellId
  @face : Int32
  @orientation : Int32
  @level : Int32

  def initialize(cell_id : CellId)
    @uv = Array.new(2) { Array(Float64).new(2, Float64::NAN) }

    @cell_id = cell_id
    face, i, j, orientation = cell_id.to_face_ij_orientation
    ij = {i, j}
    @face = face
    @orientation = orientation
    @level = cell_id.level

    cell_size = cell_id.get_size_ij
    ij.zip(@uv) do |ij_, uv_|
      ij_lo = ij_ & (~cell_size &+ 1)
      ij_hi = ij_lo + cell_size
      uv_[0] = CellId.st_to_uv((1.0 / CellId::MAX_SIZE) * ij_lo)
      uv_[1] = CellId.st_to_uv((1.0 / CellId::MAX_SIZE) * ij_hi)
    end
  end

  def initialize(@face, @level, @orientation, @cell_id, @uv)
  end

  def self.from_lat_lng(lat_lng : LatLng) : Cell
    new(CellId.from_lat_lng(lat_lng))
  end

  def self.from_point(point : Point) : Cell
    new(CellId.from_point(point))
  end

  def to_s : String
    "#{self.class.name}: face #{@face}, level #{@level}, orientation #{orientation}, id #{@cell_id.id}"
  end

  def self.from_face_pos_level(face : Int32, pos : UInt64, level : Int32) : Cell
    new(CellId.from_face_pos_level(face, pos, level))
  end

  def id : CellId?
    @cell_id
  end

  def face : Int32
    @face
  end

  def level : Int32
    @level
  end

  def orientation : Int32
    @orientation
  end

  def leaf? : Bool
    @level == CellId::MAX_LEVEL
  end

  def get_edge(k : Int32) : Point
    get_edge_raw(k).normalize
  end

  def get_edge_raw(k : Int32) : Point
    case k
    when 0
      get_v_norm(@face, @uv[1][0])
    when 1
      get_u_norm(@face, @uv[0][1])
    when 2
      -get_v_norm(@face, @uv[1][1])
    else
      -get_u_norm(@face, @uv[0][0])
    end
  end

  def get_vertex(k : Int32) : Point
    get_vertex_raw(k).normalize
  end

  def get_vertex_raw(k : Int32) : Point
    S2Cells.face_uv_to_xyz(@face, @uv[0][(k >> 1) ^ (k & 1)], @uv[1][k >> 1])
  end

  def exact_area : Float64
    v0 = get_vertex(0)
    v1 = get_vertex(1)
    v2 = get_vertex(2)
    v3 = get_vertex(3)
    area(v0, v1, v2) + area(v0, v2, v3)
  end

  def average_area : Float64
    AVG_AREA.get_value(@level)
  end

  def approx_area : Float64
    if @level < 2
      average_area
    else
      flat_area = 0.5 * (get_vertex(2) - get_vertex(0)).cross_prod(get_vertex(3) - get_vertex(1)).norm
      flat_area * 2 / (1 + Math.sqrt(1 - [1.0 / Math::PI * flat_area, 1.0].min))
    end
  end

  def subdivide(&)
    uv_mid = @cell_id.get_center_uv

    @cell_id.children.each_with_index do |cell_id, pos|
      uv = Array.new(2) { Array(Float64).new(2, Float64::NAN) }
      ij = POS_TO_IJ[@orientation][pos]
      i = ij >> 1
      j = ij & 1
      uv[0][i] = @uv[0][i]
      uv[0][1 - i] = uv_mid[0]
      uv[1][j] = @uv[1][j]
      uv[1][1 - j] = uv_mid[1]

      yield Cell.new(
        @face,
        @level + 1,
        @orientation ^ POS_TO_ORIENTATION[pos],
        cell_id,
        uv
      )
    end
  end

  def get_center : Point
    get_center_raw.normalize
  end

  def get_center_raw : Point
    @cell_id.to_point_raw
  end

  def contains(other : Cell | Point) : Bool
    case other
    in Cell
      @cell_id.contains(other.@cell_id)
    in Point
      valid, u, v = S2Cells.face_xyz_to_uv(@face, other)
      return false unless valid
      u >= @uv[0][0] && u <= @uv[0][1] && v >= @uv[1][0] && v <= @uv[1][1]
    end
  end

  def may_intersect(cell : Cell) : Bool
    @cell_id.intersects(cell.@cell_id)
  end

  def get_latitude(i : Int32, j : Int32) : Float64
    p = S2Cells.face_uv_to_xyz(@face, @uv[0][i], @uv[1][j])
    LatLng.latitude(p).radians
  end

  def get_longitude(i : Int32, j : Int32) : Float64
    p = S2Cells.face_uv_to_xyz(@face, @uv[0][i], @uv[1][j])
    LatLng.longitude(p).radians
  end

  def get_cap_bound : Cap
    u = 0.5 * (@uv[0][0] + @uv[0][1])
    v = 0.5 * (@uv[1][0] + @uv[1][1])
    cap = Cap.from_axis_height(face_uv_to_xyz(@face, u, v).normalize, 0)
    4.times { |k| cap.add_point(get_vertex(k)) }
    cap
  end

  def get_rect_bound : LatLngRect
    if @level > 0
      u = @uv[0][0] + @uv[0][1]
      v = @uv[1][0] + @uv[1][1]
      i = get_u_axis(@face)[2] == 0 ? (u < 0 ? 1 : 0) : (u > 0 ? 1 : 0)
      j = get_v_axis(@face)[2] == 0 ? (v < 0 ? 1 : 0) : (v > 0 ? 1 : 0)

      max_error = 1.0 / (1_u64 << 51)
      lat = LineInterval.from_point_pair(get_latitude(i, j), get_latitude(1 - i, 1 - j))
      lat = lat.expanded(max_error).intersection(LatLngRect.full_lat)

      if lat.lo == (-Math::PI / 2.0) || lat.hi == (Math::PI / 2.0)
        return LatLngRect.new(lat, SphereInterval.full)
      end

      lng = SphereInterval.from_point_pair(get_longitude(i, 1 - j), get_longitude(1 - i, j))
      return LatLngRect.new(lat, lng.expanded(max_error))
    end

    pole_min_lat = Math.asin(Math.sqrt(1.0 / 3.0))

    case @face
    when 0
      LatLngRect.new(LineInterval.new(-Math::PI / 4.0, Math::PI / 4.0), SphereInterval.new(-Math::PI / 4.0, Math::PI / 4.0))
    when 1
      LatLngRect.new(LineInterval.new(-Math::PI / 4.0, Math::PI / 4.0), SphereInterval.new(Math::PI / 4.0, 3.0 * Math::PI / 4.0))
    when 2
      LatLngRect.new(LineInterval.new(pole_min_lat, Math::PI / 2.0), SphereInterval.new(-Math::PI, Math::PI))
    when 3
      LatLngRect.new(LineInterval.new(-Math::PI / 4.0, Math::PI / 4.0), SphereInterval.new(3.0 * Math::PI / 4.0, -3.0 * Math::PI / 4.0))
    when 4
      LatLngRect.new(LineInterval.new(-Math::PI / 4.0, Math::PI / 4.0), SphereInterval.new(-3.0 * Math::PI / 4.0, -Math::PI / 4.0))
    else
      LatLngRect.new(LineInterval.new(-Math::PI / 2.0, -pole_min_lat), SphereInterval.new(-Math::PI, Math::PI))
    end
  end

  def get_u_axis(face : Int)
    case face
    when 0
      Point.new(0, 1, 0)
    when 1
      Point.new(-1, 0, 0)
    when 2
      Point.new(-1, 0, 0)
    when 3
      Point.new(0, 0, -1)
    when 4
      Point.new(0, 0, -1)
    else
      Point.new(0, 1, 0)
    end
  end

  def get_v_axis(face : Int)
    case face
    when 0
      Point.new(0, 0, 1)
    when 1
      Point.new(0, 0, 1)
    when 2
      Point.new(0, -1, 0)
    when 3
      Point.new(0, -1, 0)
    when 4
      Point.new(1, 0, 0)
    else
      Point.new(1, 0, 0)
    end
  end

  # Vector normal to the positive v-axis and the plane through the origin.
  #
  # The vector is normal to the positive v-axis and a plane that contains the
  # origin and the v-axis.
  def get_u_norm(face : Int, u : Float64)
    case face
    when 0
      Point.new(u, -1, 0)
    when 1
      Point.new(1, u, 0)
    when 2
      Point.new(1, 0, u)
    when 3
      Point.new(-u, 0, 1)
    when 4
      Point.new(0, -u, 1)
    else
      Point.new(0, -1, -u)
    end
  end

  # Vector normal to the positive u-axis and the plane through the origin.
  #
  # The vector is normal to the positive u-axis and a plane that contains the
  # origin and the u-axis.
  def get_v_norm(face, v)
    case face
    when 0
      Point.new(-v, 0, 1)
    when 1
      Point.new(0, -v, 1)
    when 2
      Point.new(0, -1, -v)
    when 3
      Point.new(v, -1, 0)
    when 4
      Point.new(1, v, 0)
    else
      Point.new(1, 0, v)
    end
  end
end
