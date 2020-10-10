# Crystal Lang S2 Cells

[![Build Status](https://travis-ci.com/spider-gazelle/s2_cells.svg?branch=master)](https://travis-ci.com/github/spider-gazelle/s2_cells)

Maps Lat Long coordinates to S2 Cells.
Useful for things like storing points [in InfluxDB](https://docs.influxdata.com/influxdb/v2.0/reference/flux/stdlib/experimental/geo/#geo-schema-requirements)

## Installation

1. Add the dependency to your `shard.yml`:

   ```yaml
   dependencies:
     coap:
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
