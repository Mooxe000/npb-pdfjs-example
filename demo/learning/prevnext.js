var canvas, ctx, onNextPage, onPrevPage, pageNum, pageNumPending, pageRendering, pdfDoc, queueRenderPage, renderPage, scale, url;

url = '/npb-pdfjs-example/PDF/test.pdf';

pdfDoc = null;

pageNum = 1;

pageRendering = false;

pageNumPending = null;

scale = 0.8;

canvas = document.getElementById('the-canvas');

ctx = canvas.getContext('2d');


/*
 * Get page info from document, resize canvas accordingly, and render page.
 * @param num Page number.
 */

renderPage = function(num) {
  pageRendering = true;
  pdfDoc.getPage(num).then(function(page) {
    var renderContext, renderTask, viewport;
    viewport = page.getViewport(scale);
    canvas.height = viewport.height;
    canvas.width = viewport.width;
    renderContext = {
      canvasContext: ctx,
      viewport: viewport
    };
    renderTask = page.render(renderContext);
    renderTask.promise.then(function() {
      pageRendering = false;
      if (pageNumPending !== null) {
        renderPage(pageNumPending);
        pageNumPending = null;
      }
    });
  });
  document.getElementById('page_num').textContent = pageNum;
};


/*
 * If another page rendering in progress, waits until the rendering is
 * finised. Otherwise, executes rendering immediately.
 */

queueRenderPage = function(num) {
  if (pageRendering) {
    return pageNumPending = num;
  } else {
    return renderPage(num);
  }
};


/*
 * Displays previous page.
 */

onPrevPage = function() {
  if (pageNum <= 1) {
    return;
  }
  pageNum--;
  queueRenderPage(pageNum);
};

document.getElementById('prev').addEventListener('click', onPrevPage);


/*
 * Displays next page.
 */

onNextPage = function() {
  if (pageNum >= pdfDoc.numPages) {
    return;
  }
  pageNum++;
  queueRenderPage(pageNum);
};

document.getElementById('next').addEventListener('click', onNextPage);


/**
 * Asynchronously downloads PDF.
 */

PDFJS.getDocument(url).then(function(pdfDoc_) {
  pdfDoc = pdfDoc_;
  document.getElementById('page_count').textContent = pdfDoc.numPages;
  renderPage(pageNum);
});
