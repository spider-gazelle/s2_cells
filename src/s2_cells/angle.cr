require "math"

struct S2Cells::Angle
  include Comparable(Angle)

  # A one-dimensional angle (as opposed to a two-dimensional solid angle).
  # It has methods for converting angles to or from radians and degrees.

  # Initializes a new Angle with a given radians value.
  def initialize(@radians : Float64 = 0)
    raise ArgumentError.new("Invalid type for radians") unless @radians.is_a?(Float64)
  end

  def hash : UInt64
    @radians.hash
  end

  # Checks equality of the Angle with another object.
  def ==(other : Angle)
    @radians == other.radians
  end

  # Compares this Angle to another Angle to determine if it is less than the other.
  def <=>(other : Angle)
    @radians <=> other.radians
  end

  # Adds two Angles together.
  def +(other : Angle) : Angle
    Angle.from_radians(@radians + other.radians)
  end

  # Represents the Angle as a string.
  def to_s : String
    "#{self.class.name}: #{@radians}"
  end

  # Creates an Angle from a degree measurement.
  def self.from_degrees(degrees : Float64) : Angle
    new(degrees * Math::PI / 180.0)
  end

  # Creates an Angle from a radians measurement.
  def self.from_radians(radians : Float64) : Angle
    new(radians)
  end

  # Gets the radians value of the Angle.
  getter radians : Float64

  # Converts the Angle's radians to degrees.
  def degrees : Float64
    @radians * 180.0 / Math::PI
  end
end
