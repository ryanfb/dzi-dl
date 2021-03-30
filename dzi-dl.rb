#!/usr/bin/env ruby

require 'nokogiri'
require 'open-uri'
require 'open_uri_redirections'
require 'tempfile'
require 'robotex'
require 'uri'
require 'json'
require 'net/https'
require 'ruby-progressbar'
require 'shellwords'
require 'addressable/uri'

USER_AGENT = ENV['USER_AGENT'] || 'dzi-dl'
DEFAULT_DELAY = ENV['DEFAULT_DELAY'].nil? ? 1 : ENV['DEFAULT_DELAY'].to_f
MAX_RETRIES = ENV['MAX_RETRIES'].nil? ? 3 : ENV['MAX_RETRIES'].to_i
VERIFY_SSL = (ENV['VERIFY_SSL'] == 'true') ? OpenSSL::SSL::VERIFY_PEER : OpenSSL::SSL::VERIFY_NONE
OPEN_URI_OPTIONS = {"User-Agent" => USER_AGENT, :allow_redirections => :all, :ssl_verify_mode => VERIFY_SSL}

def do_mogrify(filename, tile_size, overlap, gravity)
  geometry = "#{tile_size}x#{tile_size}-#{overlap}-#{overlap}"
  `mogrify -gravity #{gravity} -crop #{geometry} +repage #{filename}`
  if($?.exitstatus != 0)
    destination = File.join('backup',File.basename(filename))
    $stderr.puts "Error calling `mogrify` on #{filename}. Copying bad file to: #{destination}"
    FileUtils.mkdir_p('backup')
    FileUtils.cp(filename, destination, :verbose => true)
    raise "Non-zero exit status for `mogrify`"
  end
end

begin
  `montage --version`
  if($?.exitstatus != 0)
    raise "Non-zero exit status"
  end
rescue StandardError => e
  $stderr.puts "Unable to call `montage` command from ImageMagick.\nPlease ensure ImageMagick is installed and available on your PATH."
  exit 1
end

$stderr.puts "URL: #{ARGV[0]}"
files_url = ARGV[0].sub(/\.(xml|dzi)$/, '_files')
$stderr.puts "DeepZoom files URL: #{files_url}"

robotex = Robotex.new(USER_AGENT)
doc = Nokogiri::XML(URI.open(ARGV[0])).remove_namespaces!
$stderr.puts "DZI XML document contents:"
$stderr.puts doc.to_s
deepzoom = {}
deepzoom[:tile_size] = doc.xpath('/Image/@TileSize').first.value.to_i
deepzoom[:overlap] = doc.xpath('/Image/@Overlap').first.value.to_i
deepzoom[:format] = doc.xpath('/Image/@Format').first.value
deepzoom[:width] = doc.xpath('/Image/Size/@Width').first.value.to_i
deepzoom[:height] = doc.xpath('/Image/Size/@Height').first.value.to_i
$stderr.puts "DeepZoom parameters:\n#{JSON.pretty_generate(deepzoom)}"
output_filename = ARGV[0].split(/[?\/=]/).last.sub(/\.(xml|dzi)$/,'') + '.' + deepzoom[:format]

max_level = Math.log2([deepzoom[:width],deepzoom[:height]].max).ceil
$stderr.puts "#{max_level + 1} tile levels"
tiles_x = (deepzoom[:width].to_f / deepzoom[:tile_size]).ceil
tiles_y = (deepzoom[:height].to_f / deepzoom[:tile_size]).ceil
total_tiles = tiles_x * tiles_y
$stderr.puts "#{tiles_x} x #{tiles_y} = #{total_tiles} tiles"
progress_bar = ProgressBar.create(:title => "Downloading Tiles", :total => total_tiles, :format => '%t (%c/%C): |%B| %p%% %E')
tempfiles = Array.new(tiles_y){Array.new(tiles_x)}
begin
  for y in 0..(tiles_y - 1)
    for x in 0..(tiles_x - 1)
      retries = 0
      tile_url = Addressable::URI.normalized_encode(File.join(files_url, max_level.to_s, "#{x}_#{y}.#{deepzoom[:format]}"))
      if robotex.allowed?(tile_url)
        delay = robotex.delay(tile_url)
        tempfile = Tempfile.new(["#{x}_#{y}",".#{deepzoom[:format]}"])
        tempfile.close
        tempfiles[y][x] = tempfile
        # progress_bar.log "Downloading tile #{x}_#{y}"
        begin
          URI.open(tile_url, OPEN_URI_OPTIONS) do |open_uri_response|
            unless open_uri_response.meta['content-type'] == 'image/jpeg'
              raise "Got response content-type: #{open_uri_response.meta['content-type']}"
            end
            IO.copy_stream(open_uri_response, tempfile.path)
            unless File.exist?(tempfile.path)
              raise "#{tempfile.path} doesn't exist"
            end
          end
        rescue StandardError => e
          progress_bar.log e.inspect
          if retries < MAX_RETRIES
            progress_bar.log "Retrying download for: #{tile_url}"
            sleep (delay ? delay : DEFAULT_DELAY)
            retries += 1
            retry
          else
            progress_bar.log "Maximum retries (#{MAX_RETRIES}) reached, aborting"
            exit 1
          end
        end
        sleep (delay ? delay : DEFAULT_DELAY)
        progress_bar.increment
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
  `montage -mode concatenate -tile #{tiles_x}x#{tiles_y} #{tempfiles.flatten.map{|t| t.path}.join(' ')} #{Shellwords.escape(output_filename)}`
  if($?.exitstatus != 0)
    destination = Shellwords.escape(File.join('backup',File.basename(output_filename)))
    $stderr.puts "Error calling `montage` for #{output_filename}. Moving bad output to: #{destination}"
    FileUtils.mkdir_p('backup')
    FileUtils.mv(output_filename, destination, :verbose => true, :force => true)
    raise "Non-zero exit status for `montage`"
  end
  unless File.exist?(output_filename)
    $stderr.puts "ERROR: Expected #{output_filename} to be assembled from tiles, but file does not exist."
    exit 1
  end
rescue StandardError => e
  $stderr.puts("#{e.message}, exiting")
  exit 1
ensure
  tempfiles.flatten.each{|t| t.unlink unless t.nil?}
end
