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

**NOTE:** Currently, `dzi-dl` uses ImageMagick in such a way that the Deep Zoom image overlap will be missing from the assembled image border (e.g. a DZI with `overlap=2` will be missing 2px around the border in the assembled image).
