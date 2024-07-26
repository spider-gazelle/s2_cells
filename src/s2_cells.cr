# Based on the ruby lib: https://github.com/99Taxis/s2_cells
# Which in turn was based on: https://github.com/nabeelamjad/poke-api

module S2Cells
  class InvalidLevel < Exception
    def initialize(level)
      super("Level #{level} is invalid, must be between 0 and 30.")
    end
  end

  def self.at(lat : Float64, lon : Float64)
    CellId.from_lat_lon(lat, lon)
  end

  struct Bounds
    property lat_lo : Float64
    property lat_hi : Float64
    property lon_lo : Float64
    property lon_hi : Float64

    def initialize(@lat_lo, @lat_hi, @lon_lo, @lon_hi)
    end
  end
end

require "./s2_cells/cell_base"
require "./s2_cells/point"
require "./s2_cells/cell_id"
require "./s2_cells/lat_lon"
require "./s2_cells/region_coverer"
