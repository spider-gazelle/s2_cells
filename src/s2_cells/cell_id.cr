class S2Cells::CellId
  include CellBase
  getter id : UInt64

  def initialize(@id)
  end

  # ToToken returns a hex-encoded string of the uint64 cell id, with leading
  # zeros included but trailing zeros stripped.
  def to_token : String
    token = @id.to_s(16).rjust(16, '0').rstrip('0')
    return "X" if token.size == 0
    token
  end

  # returns a cell given a hex-encoded string of its uint64 ID
  def self.from_token(token : String)
    raise ArgumentError.new("token size was #{token.bytesize}, max size is 16 bytes") if token.bytesize > 16
    # pad to 16 characters
    self.new(token.ljust(16, '0').to_u64(16))
  end

  def parent(level)
    new_lsb = lsb_for_level(level)
    s2 = CellId.new((@id & ((~new_lsb) &+ 1)) | new_lsb)

    raise InvalidLevel.new(level) unless valid?(s2.id)
    s2
  end

  def prev
    CellId.new(@id - (lsb << 1))
  end

  def next
    CellId.new(@id + (lsb << 1))
  end

  def level
    return MAX_LEVEL if leaf?

    level = -1
    x = (@id & 0xffffffff_u64)

    if x != 0
      level += 16
    else
      x = ((@id >> 32) & 0xffffffff_u64)
    end

    # 2s compliment
    x &= ((~x) &+ 1)

    level += 8 unless (x & 0x00005555_u64).zero?
    level += 4 unless (x & 0x00550055_u64).zero?
    level += 2 unless (x & 0x05050505_u64).zero?
    level += 1 unless (x & 0x11111111_u64).zero?
    level
  end

  def self.from_lat_lon(lat : Float64, lon : Float64)
    from_point LatLon.new(lat, lon).to_point
  end

  def self.from_point(p : Point)
    face, u, v = xyz_to_face_uv(p)
    i = st_to_ij(uv_to_st(u))
    j = st_to_ij(uv_to_st(v))

    CellId.new(from_face_ij(face, i, j))
  end

  def self.from_face_ij(face : UInt64, i : UInt64, j : UInt64)
    n = face << (POS_BITS - 1)
    bits = face & SWAP_MASK

    7.downto(0).each do |k|
      mask = (1_u64 << LOOKUP_BITS) - 1
      bits += (((i >> (k * LOOKUP_BITS)) & mask) << (LOOKUP_BITS + 2))
      bits += (((j >> (k * LOOKUP_BITS)) & mask) << 2)
      bits = LOOKUP_POS[bits]
      n |= (bits >> 2) << (k * 2 * LOOKUP_BITS)
      bits &= (SWAP_MASK | INVERT_MASK)
    end

    n * 2 + 1
  end

  def self.xyz_to_face_uv(p : Point) : Tuple(UInt64, Float64, Float64)
    face = p.largest_abs_component

    pface = case face
            when 0_u64 then p.x
            when 1_u64 then p.y
            else            p.z
            end

    face += 3_u64 if pface < 0.0

    u, v = valid_face_xyz_to_uv(face, p)
    {face, u, v}
  end

  def self.uv_to_st(u : Float64)
    return 0.5 * Math.sqrt(1.0 + 3.0 * u) if u >= 0.0
    1.0 - 0.5 * Math.sqrt(1.0 - 3.0 * u)
  end

  def self.st_to_ij(s : Float64) : UInt64
    {0_u64, {MAX_SIZE - 1_u64, (MAX_SIZE * s).floor.to_u64}.min}.max
  end

  def self.valid_face_xyz_to_uv(face : UInt64, p : Point)
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

  def self.face_uv_to_xyz(face : UInt64, u : Float64, v : Float64)
    case face
    when 0 then Point.new(1_f64, u, v)
    when 1 then Point.new(-u, 1_f64, v)
    when 2 then Point.new(-u, -v, 1_f64)
    when 3 then Point.new(-1_f64, -v, -u)
    when 4 then Point.new(v, -1_f64, -u)
    else        Point.new(v, u, -1_f64)
    end
  end

  private def leaf?
    @id & 1 != 0
  end

  private def valid?(s2_id : UInt64)
    face = s2_id >> POS_BITS
    # We're performing 2s compliment
    lsb = s2_id & ((~s2_id) &+ 1)
    (face < NUM_FACES) && ((lsb & 0x1555555555555555_u64) != 0)
  end

  private def lsb
    @id & -@id
  end

  private def lsb_for_level(level)
    1_u64 << (2 * (MAX_LEVEL - level))
  end
end
