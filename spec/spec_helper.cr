require "spec"
require "random"
require "../src/s2_cells"

def get_random_cell_id(level : Int32 = Random.rand(S2Cells::CellId::MAX_LEVEL + 1))
  face = Random.rand(S2Cells::CellId::NUM_FACES)
  pos = Random.rand(UInt64::MAX) & ((1_u64 << (2 * S2Cells::CellId::MAX_LEVEL)) - 1)

  S2Cells::CellId.from_face_pos_level(face, pos, level)
end

INVERSE_ITERATIONS          = 20
TOKEN_ITERATIONS            = 10
COVERAGE_ITERATIONS         = 10
NEIGHBORS_ITERATIONS        = 10
NORMALIZE_ITERATIONS        = 20
REGION_COVERER_ITERATIONS   = 10
RANDOM_CAPS_ITERATIONS      = 10
SIMPLE_COVERINGS_ITERATIONS = 10
