
/* Any copyright is dedicated to the Public Domain.
 * http://creativecommons.org/publicdomain/zero/1.0/
 */
var data, fs, pdfPath;

fs = require('fs');

global.window = global;

global.navigator = {
  userAgent: 'node'
};

global.PDFJS = {};

global.DOMParser = (require('./domparsermock.js')).DOMParserMock;

require('../../build/singlefile/build/pdf.combined.js');

pdfPath = process.argv[2] || '../../web/compressed.tracemonkey-pldi-09.pdf';

data = new Uint8Array(fs.readFileSync(pdfPath));

PDFJS.getDocument(data).then(function(doc) {
  var i, lastPromise, loadPage, numPages;
  numPages = doc.numPages;
  console.log('# Document Loaded');
  console.log('Number of Pages: ' + numPages);
  console.log();
  lastPromise = void 0;
  lastPromise = doc.getMetadata().then(function(data) {
    console.log('# Metadata Is Loaded');
    console.log('## Info');
    console.log(JSON.stringify(data.info, null, 2));
    console.log();
    if (data.metadata) {
      console.log('## Metadata');
      console.log(JSON.stringify(data.metadata.metadata, null, 2));
      console.log();
    }
  });
  loadPage = function(pageNum) {
    return doc.getPage(pageNum).then(function(page) {
      var viewport;
      console.log("# Page " + pageNum);
      viewport = page.getViewport(1.0);
      console.log("Size: " + viewport.width + "x" + viewport.height);
      console.log();
      return page.getTextContent().then(function(content) {
        var strings;
        strings = content.items.map(function(item) {
          return item.str;
        });
        console.log('## Text Content');
        console.log(strings.join(' '));
      }).then(function() {
        console.log();
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
