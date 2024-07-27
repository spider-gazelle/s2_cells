# Based on the ruby lib: https://github.com/99Taxis/s2_cells
# Which in turn was based on: https://github.com/nabeelamjad/poke-api

module S2Cells
  class InvalidLevel < Exception
    def initialize(level)
      super("Level #{level} is invalid, must be between 0 and 30.")
    end
  end

  def self.at(point : LatLng) : CellId
    CellId.from_lat_lng(point)
  end

  def self.at(lat : Float64, lng : Float64) : CellId
    at LatLng.from_degrees(lat, lng)
  end

  def self.in(p1 : LatLng, p2 : LatLng) : Array(CellId)
    coverer = RegionCoverer.new
    coverer.get_covering(LatLngRect.from_point_pair(p1, p2))
  end

  LINEAR_PROJECTION    = 0
  TAN_PROJECTION       = 1
  QUADRATIC_PROJECTION = 2

  SWAP_MASK   =  0x01
  INVERT_MASK =  0x02
  LOOKUP_BITS = 4_u64

  POS_TO_ORIENTATION = {SWAP_MASK, 0, 0, INVERT_MASK | SWAP_MASK}
  POS_TO_IJ          = { {0_u64, 1_u64, 3_u64, 2_u64},
                        {0_u64, 2_u64, 3_u64, 1_u64},
                        {3_u64, 2_u64, 0_u64, 1_u64},
                        {3_u64, 1_u64, 0_u64, 2_u64} }

  LOOKUP_POS = Array.new((1_u64 << (2 * LOOKUP_BITS + 2)), 0_u64)
  LOOKUP_IJ  = Array.new((1_u64 << (2 * LOOKUP_BITS + 2)), 0_u64)
end

require "./s2_cells/angle"
require "./s2_cells/point"
require "./s2_cells/lat_lng"
require "./s2_cells/interval"
require "./s2_cells/cell_id"
require "./s2_cells/metric"
require "./s2_cells/cap"
require "./s2_cells/cell"
require "./s2_cells/cell_union"
require "./s2_cells/lat_lng_rect"
require "./s2_cells/region_coverer"

# helper functions
module S2Cells
  def self.valid_face_xyz_to_uv(face : Int32, p : Point)
    raise "invalid face xyz" unless p.dot_prod(face_uv_to_xyz(face, 0.0, 0.0)) > 0

    case face
    when 0 then [p.y / p.x, p.z / p.x]
    when 1 then [-p.x / p.y, p.z / p.y]
    when 2 then [-p.x / p.z, -p.y / p.z]
    when 3 then [p.z / p.x, p.y / p.x]
    when 4 then [p.z / p.y, -p.x / p.y]
    else        [-p.y / p.z, -p.x / p.z]
    end
  end

  def self.face_uv_to_xyz(face : Int32, u : Float64, v : Float64)
    case face
    when 0 then Point.new(1_f64, u, v)
    when 1 then Point.new(-u, 1_f64, v)
    when 2 then Point.new(-u, -v, 1_f64)
    when 3 then Point.new(-1_f64, -v, -u)
    when 4 then Point.new(v, -1_f64, -u)
    else        Point.new(v, u, -1_f64)
    end
  end

  def self.xyz_to_face_uv(p : Point) : Tuple(Int32, Float64, Float64)
    face = p.largest_abs_component

    pface = case face
            when 0 then p.x
            when 1 then p.y
            else        p.z
            end

    face += 3 if pface < 0.0

    u, v = valid_face_xyz_to_uv(face, p)
    {face, u, v}
  end

  def self.face_xyz_to_uv(face : Int32, p : Point)
    if face < 3
      if p[face] <= 0.0
        return {false, 0.0, 0.0}
      end
    else
      if p[face - 3] >= 0.0
        return {false, 0.0, 0.0}
      end
    end
    u, v = valid_face_xyz_to_uv(face, p)
    {true, u, v}
  end

  def self.is_unit_length(p : Point) : Bool
    (p.norm * p.norm - 1).abs <= 1e-15
  end

  FACE_CELLS = {Cell.from_face_pos_level(0, 0_u64, 0),
                Cell.from_face_pos_level(1, 0_u64, 0),
                Cell.from_face_pos_level(2, 0_u64, 0),
                Cell.from_face_pos_level(3, 0_u64, 0),
                Cell.from_face_pos_level(4, 0_u64, 0),
                Cell.from_face_pos_level(5, 0_u64, 0)}
end
