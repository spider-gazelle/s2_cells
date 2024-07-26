require "math"

class S2Cells::LatLon
  def initialize(lat : Float64, lon : Float64, radians : Bool = false)
    if radians
      @lat_radians = lat
      @lon_radians = lon
    else
      @lat = lat
      @lon = lon
    end
  end

  def self.rad_to_deg(radians : Float64) : Float64
    radians * 180.0 / Math::PI
  end

  def self.deg_to_rad(degrees : Float64) : Float64
    degrees * Math::PI / 180.0
  end

  getter lat : Float64 { self.class.rad_to_deg(@lat_radians.as(Float64)) }
  getter lon : Float64 { self.class.rad_to_deg(@lon_radians.as(Float64)) }
  getter lat_radians : Float64 { self.class.deg_to_rad(@lat.as(Float64)) }
  getter lon_radians : Float64 { self.class.deg_to_rad(@lon.as(Float64)) }

  def to_point
    phi = lat_radians
    theta = lon_radians
    cosphi = Math.cos(phi)
    Point.new(Math.cos(theta) * cosphi, Math.sin(theta) * cosphi, Math.sin(phi))
  end

  def self.from_point(point : Point) : LatLon
    new(
      latitude(point),
      longitude(point),
      radians: true
    )
  end

  def to_token(level = 30)
    CellId.from_point(to_point)
      .parent(level)
      .to_token
  end

  # in radians
  def self.latitude(point : Point)
    Math.atan2(point.z, Math.sqrt(point.x * point.x + point.y * point.y))
  end

  # in radians
  def self.longitude(point : Point)
    Math.atan2(point.y, point.x)
  end
end
