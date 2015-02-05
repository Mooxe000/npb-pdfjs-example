var query, queryParams, scale, url;

PDFJS.workerSrc = '../../scripts/pdf.worker.js';

query = document.location.href.replace(/^[^?]*(\?([^#]*))?(#.*)?/, '$2');

queryParams = query ? JSON.parse('{' + (query.split('&').map(function(a) {
  return a.split('=').map(decodeURIComponent).map(JSON.stringify).join(': ');
}).join(',')) + '}') : {};

url = queryParams.file || '../../PDF/test.pdf';

scale = +queryParams.scale || 1.5;

PDFJS.getDocument(url).then(function(pdf) {
  var MAX_NUM_PAGES, anchor, i, numPages, promise, _i, _ref;
  numPages = pdf.numPages;
  promise = Promise.resolve();
  MAX_NUM_PAGES = 50;
  for (i = _i = 1, _ref = Math.min(MAX_NUM_PAGES, numPages); 1 <= _ref ? _i <= _ref : _i >= _ref; i = 1 <= _ref ? ++_i : --_i) {
    anchor = document.createElement('a');
    anchor.setAttribute('name', "page= " + i);
    anchor.setAttribute('title', "Page " + i);
    document.body.appendChild(anchor);
    promise = promise.then((function(pageNum, anchor) {
      return pdf.getPage(pageNum).then(function(page) {
        var container, viewport;
        viewport = page.getViewport(scale);
        container = document.createElement('div');
        container.id = "pageContainer " + pageNum;
        container.className = 'pageContainer';
        container.style.width = viewport.width + "px";
        container.style.height = viewport.height + "px";
        anchor.appendChild(container);
        return page.getOperatorList().then(function(opList) {
          var svgGfx;
          svgGfx = new PDFJS.SVGGraphics(page.commonObjs, page.objs);
          return svgGfx.getSVG(opList, viewport).then(function(svg) {
            container.appendChild(svg);
          });
        });
      });
    }).bind(null, i, anchor));
  }
});
