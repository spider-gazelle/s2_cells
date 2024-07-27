# Crystal Lang S2 Cells

[![CI](https://github.com/spider-gazelle/s2_cells/actions/workflows/ci.yml/badge.svg)](https://github.com/spider-gazelle/s2_cells/actions/workflows/ci.yml)

Maps Lat Lon coordinates to S2 Cells.
Useful for things like storing points [in InfluxDB](https://docs.influxdata.com/influxdb/v2.0/reference/flux/stdlib/experimental/geo/#geo-schema-requirements)

## Installation

1. Add the dependency to your `shard.yml`:

   ```yaml
   dependencies:
     s2_cells:
       github: spider-gazelle/s2_cells
   ```

2. Run `shards install`


## Usage

```crystal

require "s2_cells"

# index a location in your database
lat = -33.870456
lon = 151.208889
level = 24

cell = S2Cells.at(lat, lon).parent(level)
token = cell.to_token # => "3ba32f81"
# or
id = cell.id # => Int64

# find all the indexes in an area
p1 = S2Cells::LatLng.from_degrees(33.0, -122.0)
p2 = S2Cells::LatLng.from_degrees(33.1, -122.1)
cells = S2Cells.in(p1, p2) # => Array(CellId)

# then can search your index:
# loc_index = ANY(cells.map(&.id))
```
