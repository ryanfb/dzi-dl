# dzi-dl

Command-line tile downloader/assembler for [Deep Zoom](https://en.wikipedia.org/wiki/Deep_Zoom) images.

Download full-resolution images for a given Deep Zoom image `.dzi`/`.xml` URL.

There are many [tools for slicing images into Deep Zoom tiles](https://openseadragon.github.io/examples/creating-zooming-images/). This does the reverse of those.

See also: [iiif-dl](https://github.com/ryanfb/iiif-dl)

## Requirements

 * `wget`
 * [ImageMagick](http://www.imagemagick.org/)
 * Ruby
 * [Bundler](http://bundler.io/)
 
## Usage

    bundle exec ./dzi-dl.rb 'http://example.com/dzi-viewer/viewer.ashx?zoom=image.xml'

To find a `.dzi`/`.xml` URL for a given Deep Zoom image viewer, you may need to open your web browser's Developer Tools and go to e.g. the "Network" pane, then reload the page and see what resources are loaded via AJAX.

Alternately, if you have [PhantomJS](http://phantomjs.org/) installed, you can use `dzixmlreqs.js` to list all URLs ending in `.dzi`/`.xml` requested by a given webpage URL:

    phantomjs dzixmlreqs.js 'http://example.com/viewer.asp?manuscript=shelfmark'

## Docker Usage

There's also [an automated build for this repository on Docker Hub at `ryanfb/dzi-dl`](http://hub.docker.com/r/ryanfb/dzi-dl). It defines an `ENTRYPOINT` which will start `dzi-dl.rb` and pass any other arguments or environment variables to it, as well as defining a `/data` volume which you can map to your host to store manifests and images. For example, to download an image into the current directory:

    docker run -t -v $(pwd):/data ryanfb/dzi-dl 'http://example.com/dzi-viewer/viewer.ashx?zoom=image.xml'
