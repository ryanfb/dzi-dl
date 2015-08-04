#!/usr/bin/env ruby

require 'nokogiri'
require 'open-uri'

$stderr.puts ARGV[0]
files_url = ARGV[0].sub(/\.xml$/, '_files')
$stderr.puts files_url

doc = Nokogiri::XML(open(ARGV[0])).remove_namespaces!
deepzoom = {}
deepzoom[:tile_size] = doc.xpath('/Image/@TileSize').first.value.to_i
deepzoom[:overlap] = doc.xpath('/Image/@Overlap').first.value.to_i
deepzoom[:format] = doc.xpath('/Image/@Format').first.value
deepzoom[:width] = doc.xpath('/Image/Size/@Width').first.value.to_i
deepzoom[:height] = doc.xpath('/Image/Size/@Height').first.value.to_i
$stderr.puts deepzoom.inspect

max_level = Math.log2([deepzoom[:width],deepzoom[:height]].max).ceil
$stderr.puts max_level
tiles_x = (deepzoom[:width] / deepzoom[:tile_size]).ceil
tiles_y = (deepzoom[:height] / deepzoom[:tile_size]).ceil
$stderr.puts "#{tiles_x} x #{tiles_y} = #{tiles_x * tiles_y} tiles"
for x in 0..tiles_x
  for y in 0..tiles_y
    tile_url = File.join(files_url, max_level.to_s, "#{x}_#{y}.#{deepzoom[:format]}")
    `wget #{tile_url}`
  end
end
