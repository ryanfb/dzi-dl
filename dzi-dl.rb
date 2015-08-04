#!/usr/bin/env ruby

require 'nokogiri'
require 'open-uri'
require 'tempfile'

$stderr.puts ARGV[0]
files_url = ARGV[0].sub(/\.(xml|dzi)$/, '_files')
$stderr.puts files_url

doc = Nokogiri::XML(open(ARGV[0])).remove_namespaces!
deepzoom = {}
deepzoom[:tile_size] = doc.xpath('/Image/@TileSize').first.value.to_i
deepzoom[:overlap] = doc.xpath('/Image/@Overlap').first.value.to_i
deepzoom[:format] = doc.xpath('/Image/@Format').first.value
deepzoom[:width] = doc.xpath('/Image/Size/@Width').first.value.to_i
deepzoom[:height] = doc.xpath('/Image/Size/@Height').first.value.to_i
$stderr.puts deepzoom.inspect
output_filename = ARGV[0].split(/[?\/=]/).last.sub(/\.(xml|dzi)$/,'') + '.' + deepzoom[:format]

max_level = Math.log2([deepzoom[:width],deepzoom[:height]].max).ceil
$stderr.puts max_level
tiles_x = (deepzoom[:width].to_f / deepzoom[:tile_size]).floor
tiles_y = (deepzoom[:height].to_f / deepzoom[:tile_size]).floor
$stderr.puts "#{tiles_x} x #{tiles_y} = #{tiles_x * tiles_y} tiles"
tempfiles = []
begin
  for y in 0..(tiles_y - 1)
    for x in 0..(tiles_x - 1)
      tile_url = File.join(files_url, max_level.to_s, "#{x}_#{y}.#{deepzoom[:format]}")
      tempfile = Tempfile.new(["#{x}_#{y}",".#{deepzoom[:format]}"])
      tempfile.close
      tempfiles << tempfile
      $stderr.puts "Downloading tile #{x}_#{y}"
      while !system("wget -q -O #{tempfile.path} #{tile_url}") do
        $stderr.puts "Retrying download for: #{tile_url}"
      end
    end
  end
  $stderr.puts "Combining tiles into #{output_filename}"
  `montage -mode concatenate -tile #{tiles_x}x#{tiles_y} #{tempfiles.map{|t| t.path}.join(' ')} -geometry '-#{deepzoom[:overlap]}-#{deepzoom[:overlap]}' #{output_filename}`
ensure
  tempfiles.each{|t| t.unlink}
end
