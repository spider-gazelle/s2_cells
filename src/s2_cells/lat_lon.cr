class S2Cells::LatLon
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
    Point.new(Math.cos(theta) * cosphi, Math.sin(theta) * cosphi, Math.sin(phi))
  end

  def to_token(level = 30)
    CellId.from_point(to_point)
      .parent(level)
      .to_token
  end
end
