
/* Any copyright is dedicated to the Public Domain.
 * http://creativecommons.org/publicdomain/zero/1.0/
 */
var data, fs, getFileNameFromPath, pdfPath, writeToFile;

fs = require('fs');

global.window = global;

global.navigator = {
  userAgent: 'node'
};

global.PDFJS = {};

require('./domstubs.js');

PDFJS.workerSrc = true;

require('../../build/singlefile/build/pdf.combined.js');

pdfPath = process.argv[2] || '../../web/compressed.tracemonkey-pldi-09.pdf';

data = new Uint8Array(fs.readFileSync(pdfPath));

writeToFile = function(svgdump, pageNum) {
  var name;
  name = getFileNameFromPath(pdfPath);
  fs.mkdir('./svgdump/', function(err) {
    if (!err || err.code === 'EEXIST') {
      fs.writeFile("./svgdump/" + name + "-" + pageNum + ".svg", svgdump, function(err) {
        if (err) {
          console.log('Error: ' + err);
        } else {
          console.log('Page: ' + pageNum);
        }
      });
    }
  });
};

getFileNameFromPath = function(path) {
  var extIndex, index;
  index = path.lastIndexOf('/');
  extIndex = path.lastIndexOf('.');
  return path.substring(index, extIndex);
};

PDFJS.getDocument(data).then(function(doc) {
  var i, lastPromise, loadPage, numPages;
  numPages = doc.numPages;
  console.log('# Document Loaded');
  console.log("Number of Pages: " + numPages);
  console.log();
  lastPromise = Promise.resolve();
  loadPage = function(pageNum) {
    return doc.getPage(pageNum).then(function(page) {
      var viewport;
      console.log("# Page " + pageNum);
      viewport = page.getViewport(1.0);
      console.log("Size: " + viewport.width + "x" + viewport.height);
      console.log();
      return page.getOperatorList().then(function(opList) {
        var svgGfx;
        svgGfx = new PDFJS.SVGGraphics(page.commonObjs, page.objs);
        svgGfx.embedFonts = true;
        return svgGfx.getSVG(opList, viewport).then(function(svg) {
          var svgDump;
          svgDump = svg.toString();
          writeToFile(svgDump, pageNum);
        });
      });
    });
  };
  i = 1;
  while (i <= numPages) {
    lastPromise = lastPromise.then(loadPage.bind(null, i));
    i++;
  }
  return lastPromise;
}).then(function() {
  console.log('# End of Document');
}, function(err) {
  console.error("Error: " + err);
});
