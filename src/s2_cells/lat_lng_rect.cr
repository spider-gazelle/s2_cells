struct S2Cells::LatLngRect
  getter lat : LineInterval
  getter lng : SphereInterval

  def initialize
    @lat = LineInterval.empty
    @lng = SphereInterval.empty
  end

  def initialize(lo : LatLng, hi : LatLng)
    @lat = LineInterval.new(lo.lat.radians, hi.lat.radians)
    @lng = SphereInterval.new(lo.lng.radians, hi.lng.radians)
  end

  def initialize(@lat : LineInterval, @lng : SphereInterval)
  end

  def ==(other : LatLngRect) : Bool
    self.lat == other.lat && self.lng == other.lng
  end

  def to_s : String
    "#{self.class.name}: #{self.lat}, #{self.lng}"
  end

  def lat_lo : Angle
    Angle.from_radians(self.lat.lo)
  end

  def lat_hi : Angle
    Angle.from_radians(self.lat.hi)
  end

  def lng_lo : Angle
    Angle.from_radians(self.lng.lo)
  end

  def lng_hi : Angle
    Angle.from_radians(self.lng.hi)
  end

  def lo : LatLng
    LatLng.from_angles(self.lat_lo, self.lng_lo)
  end

  def hi : LatLng
    LatLng.from_angles(self.lat_hi, self.lng_hi)
  end

  def self.from_center_size(center : LatLng, size : LatLng) : LatLngRect
    self.from_point(center).expanded(0.5 * size)
  end

  def self.from_point(p : LatLng) : LatLngRect
    raise "Invalid point" unless p.valid?
    new(p, p)
  end

  def self.from_point_pair(a : LatLng, b : LatLng) : LatLngRect
    raise "Invalid point" unless a.valid? && b.valid?
    LatLngRect.new(
      LineInterval.from_point_pair(a.lat.radians, b.lat.radians),
      SphereInterval.from_point_pair(a.lng.radians, b.lng.radians)
    )
  end

  def self.full_lat : LineInterval
    LineInterval.new(-Math::PI / 2.0, Math::PI / 2.0)
  end

  def self.full_lng : SphereInterval
    SphereInterval.full
  end

  def self.full : LatLngRect
    new(self.full_lat, self.full_lng)
  end

  def full? : Bool
    self.lat == self.class.full_lat && self.lng.full?
  end

  def valid? : Bool
    (self.lat.lo.abs <= Math::PI / 2.0 &&
      self.lat.hi.abs <= Math::PI / 2.0 &&
      self.lng.valid? &&
      self.lat.empty? == self.lng.empty?)
  end

  def self.empty : LatLngRect
    new
  end

  def get_center : LatLng
    LatLng.from_radians(self.lat.get_center, self.lng.get_center)
  end

  def get_size : LatLng
    LatLng.from_radians(self.lat.get_length, self.lng.get_length)
  end

  def get_vertex(k : Int32) : LatLng
    LatLng.from_radians(self.lat.bound(k >> 1), self.lng.bound((k >> 1) ^ (k & 1)))
  end

  def area : Float64
    return 0.0 if self.empty?
    self.lng.get_length * (Math.sin(self.lat_hi.radians) - Math.sin(self.lat_lo.radians)).abs
  end

  def empty? : Bool
    self.lat.empty?
  end

  def point? : Bool
    self.lat.lo == self.lat.hi && self.lng.lo == self.lng.hi
  end

  def convolve_with_cap(angle : Angle) : LatLngRect
    cap = Cap.from_axis_angle(Point.new(1, 0, 0), angle)
    r = self
    4.times do |k|
      vertex_cap = Cap.from_axis_height(self.get_vertex(k).to_point, cap.height)
      r = r.union(vertex_cap.get_rect_bound)
    end
    r
  end

  def contains(other : LatLngRect | LatLng | Point | Cell) : Bool
    case other
    in Point
      self.contains(LatLng.from_point(other))
    in LatLng
      raise "Invalid LatLng" unless other.valid?
      self.lat.contains(other.lat.radians) && self.lng.contains(other.lng.radians)
    in LatLngRect
      self.lat.contains(other.lat) && self.lng.contains(other.lng)
    in Cell
      self.contains(other.get_rect_bound)
    end
  end

  def interior_contains(other : LatLngRect | LatLng | Point) : Bool
    case other
    in Point
      self.interior_contains(LatLng.new(other))
    in LatLng
      raise "Invalid LatLng" unless other.valid?
      self.lat.interior_contains(other.lat.radians) && self.lng.interior_contains(other.lng.radians)
    in LatLngRect
      self.lat.interior_contains(other.lat) && self.lng.interior_contains(other.lng)
    end
  end

  def may_intersect(cell : Cell) : Bool
    self.intersects(cell.get_rect_bound)
  end

  def intersects(other : LatLngRect | Cell) : Bool
    case other
    in LatLngRect
      self.lat.intersects(other.lat) && self.lng.intersects(other.lng)
    in Cell
      return false if self.empty?
      return true if self.contains(other.get_center_raw)
      return true if other.contains(self.get_center.to_point)
      return false unless self.intersects(other.get_rect_bound)

      cell_v = [] of Point
      cell_ll = [] of LatLng
      4.times do |i|
        cell_v << other.get_vertex(i)
        cell_ll << LatLng.from_point(cell_v[i])
        return true if self.contains(cell_ll[i])
        return true if other.contains(self.get_vertex(i).to_point)
      end

      4.times do |i|
        edge_lng = SphereInterval.from_point_pair(cell_ll[i].lng.radians, cell_ll[(i + 1) & 3].lng.radians)
        next unless self.lng.intersects(edge_lng)

        a = cell_v[i]
        b = cell_v[(i + 1) & 3]
        if edge_lng.contains(self.lng.lo)
          return true if self.class.intersects_lng_edge(a, b, self.lat, self.lng.lo)
        end
        if edge_lng.contains(self.lng.hi)
          return true if self.class.intersects_lng_edge(a, b, self.lat, self.lng.hi)
        end
        return true if self.class.intersects_lat_edge(a, b, self.lat.lo, self.lng)
        return true if self.class.intersects_lat_edge(a, b, self.lat.hi, self.lng)
      end
      false
    end
  end

  def self.intersects_lng_edge(a : Point, b : Point, lat : LineInterval, lng : Float64) : Bool
    simple_crossing(a, b, LatLng.from_radians(lat.lo, lng).to_point, LatLng.from_radians(lat.hi, lng).to_point)
  end

  def self.simple_crossing(a : Point, b : Point, c : Point, d : Point) : Bool
    ab = a.cross_prod(b)
    acb = -(ab.dot_prod(c))
    bda = ab.dot_prod(d)
    return false if acb * bda <= 0

    cd = c.cross_prod(d)
    cbd = -(cd.dot_prod(b))
    dac = cd.dot_prod(a)
    (acb * cbd > 0) && (acb * dac > 0)
  end

  def self.intersects_lat_edge(a : Point, b : Point, lat : Float64, lng : SphereInterval) : Bool
    raise "Point not unit length" unless S2Cells.is_unit_length(a) && S2Cells.is_unit_length(b)

    z = robust_cross_prod(a, b).normalize
    z = -z if z.z < 0

    y = robust_cross_prod(z, Point.new(0, 0, 1)).normalize
    x = y.cross_prod(z)
    raise "Point not unit length" unless S2Cells.is_unit_length(x)
    raise "Invalid X value" unless x.z >= 0

    sin_lat = Math.sin(lat)
    return false if sin_lat.abs >= x.z

    cos_theta = sin_lat / x.z
    sin_theta = Math.sqrt(1 - cos_theta * cos_theta)
    theta = Math.atan2(sin_theta, cos_theta)

    ab_theta = SphereInterval.from_point_pair(
      Math.atan2(a.dot_prod(y), a.dot_prod(x)),
      Math.atan2(b.dot_prod(y), b.dot_prod(x))
    )

    if ab_theta.contains(theta)
      isect = x * cos_theta + y * sin_theta
      return true if lng.contains(Math.atan2(isect.y, isect.x))
    end
    if ab_theta.contains(-theta)
      isect = x * cos_theta - y * sin_theta
      return true if lng.contains(Math.atan2(isect.y, isect.x))
    end
    false
  end

  def interior_intersects(other : LatLngRect) : Bool
    self.lat.interior_intersects(other.lat) && self.lng.interior_intersects(other.lng)
  end

  def union(other : LatLngRect) : LatLngRect
    LatLngRect.new(self.lat.union(other.lat), self.lng.union(other.lng))
  end

  def intersection(other : LatLngRect) : LatLngRect
    lat = self.lat.intersection(other.lat)
    lng = self.lng.intersection(other.lng)
    return LatLngRect.empty if lat.empty? || lng.empty?
    LatLngRect.new(lat, lng)
  end

  def expanded(margin : LatLng) : LatLngRect
    raise "Invalid margin" unless margin.lat.radians > 0 && margin.lng.radians > 0
    LatLngRect.new(
      self.lat.expanded(margin.lat.radians).intersection(self.full_lat),
      self.lng.expanded(margin.lng.radians)
    )
  end

  def approx_equals(other : LatLngRect, max_error = 1e-15) : Bool
    self.lat.approx_equals(other.lat, max_error) && self.lng.approx_equals(other.lng, max_error)
  end

  def get_cap_bound : Cap
    return Cap.empty if self.empty?

    pole_z, pole_angle = if (self.lat.lo + self.lat.hi) < 0
                           {-1.0, Math::PI / 2.0 + self.lat.hi}
                         else
                           {1.0, Math::PI / 2.0 - self.lat.lo}
                         end

    pole_cap = Cap.from_axis_angle(Point.new(0.0, 0.0, pole_z), Angle.from_radians(pole_angle))
    lng_span = self.lng.hi - self.lng.lo

    if (lng_span % (2 * Math::PI)) >= 0 && lng_span < (2 * Math::PI)
      mid_cap = Cap.from_axis_angle(self.get_center.to_point, Angle.from_radians(0))
      4.times { |k| mid_cap.add_point(self.get_vertex(k).to_point) }
      return mid_cap if mid_cap.height < pole_cap.height
    end
    pole_cap
  end

  def self.ortho(a : Point) : Point
    k = a.largest_abs_component - 1
    k = 2 if k < 0
    temp = case k
           when 0
             Point.new(1, 0.0053, 0.00457)
           when 1
             Point.new(0.012, 1, 0.00457)
           else
             Point.new(0.012, 0.0053, 1)
           end
    a.cross_prod(temp).normalize
  end

  def self.robust_cross_prod(a : Point, b : Point) : Point
    raise "Input must be unit length" unless S2Cells.is_unit_length(a) && S2Cells.is_unit_length(b)

    x = (b + a).cross_prod(b - a)
    return x unless x == Point.new(0, 0, 0)

    ortho(a)
  end
end
