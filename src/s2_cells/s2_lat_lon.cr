class S2Cells::S2LatLon
  def initialize(lat_degrees : Float64, lon_degrees : Float64)
    @lat = lat_degrees * Math::PI / 180.0
    @lon = lon_degrees * Math::PI / 180.0
  end

  @lat : Float64
  @lon : Float64

  def to_point
    phi = @lat
    theta = @lon
    cosphi = Math.cos(phi)
    S2Point.new(Math.cos(theta) * cosphi, Math.sin(theta) * cosphi, Math.sin(phi))
  end

  def to_s2_id(level)
    S2CellId.from_point(to_point)
      .parent(level)
      .id
  end
end
