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

lat = -33.870456
lon = 151.208889
level = 24

cell = S2Cells.at(lat, lon).parent(level)
token = cell.to_token # => "3ba32f81"

# Or a little more direct
S2Cells::LatLon.new(lat, lon).to_token(level)

```
