# dzi-dl

Command-line tile downloader/assembler for [Deep Zoom](https://en.wikipedia.org/wiki/Deep_Zoom) images.

Download full-resolution images for a given Deep Zoom image `.dzi`/`.xml` URL.

## Requirements

 * `wget`
 * [ImageMagick](http://www.imagemagick.org/)
 * Ruby
 * [Bundler](http://bundler.io/)
 
## Usage

    bundle exec ./dzi-dl.rb 'http://example.com/dzi-viewer/viewer.ashx?zoom=image.xml'

See also: [iiif-dl](https://github.com/ryanfb/iiif-dl)
