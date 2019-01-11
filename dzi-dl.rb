#!/usr/bin/env ruby

require 'nokogiri'
require 'open-uri'
require 'tempfile'
require 'robotex'
require 'uri'

USER_AGENT = ENV['USER_AGENT'] || 'dzi-dl'
DEFAULT_DELAY = ENV['DEFAULT_DELAY'].to_f || 1

def do_mogrify(filename, tile_size, overlap, gravity)
  geometry = "#{tile_size}x#{tile_size}-#{overlap}-#{overlap}"
  `mogrify -gravity #{gravity} -crop #{geometry} +repage #{filename}`
end

$stderr.puts ARGV[0]
files_url = ARGV[0].sub(/\.(xml|dzi)$/, '_files')
$stderr.puts files_url

robotex = Robotex.new(USER_AGENT)
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
$stderr.puts "#{max_level + 1} tile levels"
tiles_x = (deepzoom[:width].to_f / deepzoom[:tile_size]).ceil
tiles_y = (deepzoom[:height].to_f / deepzoom[:tile_size]).ceil
$stderr.puts "#{tiles_x} x #{tiles_y} = #{tiles_x * tiles_y} tiles"
tempfiles = Array.new(tiles_y){Array.new(tiles_x)}
begin
  for y in 0..(tiles_y - 1)
    for x in 0..(tiles_x - 1)
      tile_url = URI.escape(File.join(files_url, max_level.to_s, "#{x}_#{y}.#{deepzoom[:format]}"))
      if robotex.allowed?(tile_url)
        delay = robotex.delay(tile_url)
        tempfile = Tempfile.new(["#{x}_#{y}",".#{deepzoom[:format]}"])
        tempfile.close
        tempfiles[y][x] = tempfile
        $stderr.puts "Downloading tile #{x}_#{y}"
        while !system("wget -U '#{USER_AGENT}' -q -O #{tempfile.path} '#{tile_url}'") do
          $stderr.puts "Retrying download for: #{tile_url}"
          sleep (delay ? delay : DEFAULT_DELAY)
        end
        sleep (delay ? delay : DEFAULT_DELAY)
      else
        $stderr.puts "User agent \"#{USER_AGENT}\" not allowed by `robots.txt` for #{tile_url}, aborting"
        exit 1
      end
    end
  end
  if deepzoom[:overlap] != 0
    $stderr.puts "Shaving overlap from tiles"
    for x in 0..(tiles_x - 1)
      for y in 0..(tiles_y - 1)
        gravity = ''
        if y == 0
          gravity += 'North'
        elsif y == (tiles_y - 1)
          gravity += 'South'
        end
        if x == 0
          gravity += 'West'
        elsif x == (tiles_x - 1)
          gravity += 'East'
        end
        if gravity == ''
          gravity = 'Center'
        end
        do_mogrify(tempfiles[y][x].path,deepzoom[:tile_size],deepzoom[:overlap],gravity)
      end
    end
  end
  $stderr.puts "Combining tiles into #{output_filename}"
  `montage -mode concatenate -tile #{tiles_x}x#{tiles_y} #{tempfiles.flatten.map{|t| t.path}.join(' ')} #{output_filename}`
ensure
  tempfiles.flatten.each{|t| t.unlink unless t.nil?}
end
