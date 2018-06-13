var page = require('webpage').create(),
    system = require('system'),
    address;

if (system.args.length === 1) {
    console.log('Usage: dzixmlreqs.js <some URL>');
    phantom.exit(1);
} else {
    address = system.args[1];

    page.onResourceRequested = function (req) {
        if(/\.(xml|dzi)$/.test(req['url'])) {
          console.log(req['url']);
        }
    };

    page.onError = function(msg, trace) {
      system.stderr.write(msg + "\n");
    };

    page.open(address, function (status) {
        if (status !== 'success') {
            console.log('FAIL to load the address');
        }
        phantom.exit();
    });
}
