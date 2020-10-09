module S2Cells::S2Base
  LINEAR_PROJECTION    = 0
  TAN_PROJECTION       = 1
  QUADRATIC_PROJECTION = 2

  MAX_LEVEL   = 30
  NUM_FACES   =  6
  POS_BITS    = 2 * MAX_LEVEL + 1
  MAX_SIZE    = 1_u64 << MAX_LEVEL
  SWAP_MASK   = 0x01_u64
  INVERT_MASK = 0x02_u64
  LOOKUP_BITS =    4_u64
  POS_TO_OR   = {SWAP_MASK, 0_u64, 0_u64, INVERT_MASK | SWAP_MASK}
  POS_TO_IJ   = { {0_u64, 1_u64, 3_u64, 2_u64},
                 {0_u64, 2_u64, 3_u64, 1_u64},
                 {3_u64, 2_u64, 0_u64, 1_u64},
                 {3_u64, 1_u64, 0_u64, 2_u64} }

  LOOKUP_POS = Array.new((1 << (2 * LOOKUP_BITS + 2)), 0_u64)
  LOOKUP_IJ  = Array.new((1 << (2 * LOOKUP_BITS + 2)), 0_u64)

  def self.lookup_cells(level, i, j, orig_orientation, pos, orientation)
    return lookup_bits(i, j, orig_orientation, pos, orientation) if level == LOOKUP_BITS

    r = POS_TO_IJ[orientation]
    4.times do |index|
      lookup_cells(
        level + 1, (i << 1) + (r[index] >> 1), (j << 1) + (r[index] & 1),
        orig_orientation, (pos << 2) + index, orientation ^ POS_TO_OR[index]
      )
    end
  end

  def self.lookup_bits(i, j, orig_orientation, pos, orientation)
    ij = (i << LOOKUP_BITS) + j
    LOOKUP_POS[(ij << 2) + orig_orientation] = (pos << 2) + orientation
    LOOKUP_IJ[(pos << 2) + orig_orientation] = (ij << 2) + orientation
  end

  lookup_cells(0_u64, 0_u64, 0_u64, 0_u64, 0_u64, 0_u64)
  lookup_cells(0_u64, 0_u64, 0_u64, SWAP_MASK, 0_u64, SWAP_MASK)
  lookup_cells(0_u64, 0_u64, 0_u64, INVERT_MASK, 0_u64, INVERT_MASK)
  lookup_cells(0_u64, 0_u64, 0_u64, SWAP_MASK | INVERT_MASK, 0_u64, SWAP_MASK | INVERT_MASK)
end
