require "math"

struct S2Cells::LatLng
  # A point on a sphere in latitude-longitude coordinates.

  # Creates a LatLng from degrees.
  def self.from_degrees(lat : Float64, lng : Float64) : LatLng
    from_angles(Angle.from_degrees(lat), Angle.from_degrees(lng))
  end

  # Creates a LatLng from radians.
  def self.from_radians(lat : Float64, lng : Float64) : LatLng
    new(lat, lng)
  end

  # Creates a LatLng from a Point object.
  def self.from_point(point : Point) : LatLng
    new(LatLng.latitude(point).radians, LatLng.longitude(point).radians)
  end

  # Creates a LatLng from two angles.
  def self.from_angles(lat : Angle, lng : Angle) : LatLng
    new(lat.radians, lng.radians)
  end

  # Creates a default LatLng (0, 0).
  def self.default : LatLng
    new(0.0, 0.0)
  end

  # Creates an invalid LatLng.
  def self.invalid : LatLng
    new(Math::PI, 2.0 * Math::PI)
  end

  # Initializes a LatLng with latitude and longitude in radians.
  def initialize(@lat : Float64, @lng : Float64)
  end

  # Checks equality of LatLng with another LatLng.
  def ==(other : LatLng) : Bool
    @lat == other.lat && @lng == other.lng
  end

  # Checks inequality of LatLng with another LatLng.
  def !=(other : LatLng) : Bool
    !(self == other)
  end

  # Returns the hash code of LatLng.
  def hash : Int32
    {@lat, @lng}.hash
  end

  # Returns the string representation of LatLng.
  def to_s : String
    "LatLng: #{Math.degrees(@lat)},#{Math.degrees(@lng)}"
  end

  # Adds two LatLng objects.
  def +(other : LatLng) : LatLng
    self.class.new(@lat + other.lat, @lng + other.lng)
  end

  # Subtracts one LatLng from another.
  def -(other : LatLng) : LatLng
    self.class.new(@lat - other.lat, @lng - other.lng)
  end

  # Multiplies LatLng by a scalar.
  def *(scalar : Float64) : LatLng
    self.class.new(scalar * @lat, scalar * @lng)
  end

  # Static method to calculate latitude from a Point.
  def self.latitude(point : Point) : Angle
    Angle.from_radians(Math.atan2(point.z, Math.sqrt(point.x**2 + point.y**2)))
  end

  # Static method to calculate longitude from a Point.
  def self.longitude(point : Point) : Angle
    Angle.from_radians(Math.atan2(point.y, point.x))
  end

  # Returns the latitude as an Angle.
  def lat : Angle
    Angle.from_radians(@lat)
  end

  # Returns the longitude as an Angle.
  def lng : Angle
    Angle.from_radians(@lng)
  end

  # Checks if the LatLng is valid.
  def valid? : Bool
    @lat.abs <= Math::PI / 2 && @lng.abs <= Math::PI
  end

  # Converts LatLng to a Point.
  def to_point : Point
    phi = @lat
    theta = @lng
    cosphi = Math.cos(phi)
    Point.new(Math.cos(theta) * cosphi, Math.sin(theta) * cosphi, Math.sin(phi))
  end

  # Normalizes the LatLng.
  def normalized : LatLng
    self.class.new(@lat.clamp(-Math::PI / 2, Math::PI / 2), Math.drem(@lng, 2 * Math::PI))
  end

  # Checks if two LatLng objects are approximately equal.
  def approx_equals(other : LatLng, max_error : Float64 = 1e-15) : Bool
    Math.abs(@lat - other.lat) < max_error && Math.abs(@lng - other.lng) < max_error
  end

  # Calculates the great-circle distance between two LatLng objects.
  def get_distance(other : LatLng) : Angle
    raise "Invalid LatLng" unless valid? && other.valid?

    from_lat = @lat
    to_lat = other.lat
    from_lng = @lng
    to_lng = other.lng
    dlat = Math.sin(0.5 * (to_lat - from_lat))
    dlng = Math.sin(0.5 * (to_lng - from_lng))
    x = dlat**2 + dlng**2 * Math.cos(from_lat) * Math.cos(to_lat)
    Angle.from_radians(2 * Math.atan2(Math.sqrt(x), Math.sqrt([0.0, 1.0 - x].max)))
  end
end
