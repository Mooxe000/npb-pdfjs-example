var url;

url = '/PDF/test.pdf';

PDFJS.getDocument(url).then(function(pdf) {
  pdf.getPage(1).then(function(page) {
    var canvas, context, renderContext, scale, viewport;
    scale = 1.5;
    viewport = page.getViewport(scale);
    canvas = document.getElementById('the-canvas');
    context = canvas.getContext('2d');
    canvas.height = viewport.height;
    canvas.width = viewport.width;
    renderContext = {
      canvasContext: context,
      viewport: viewport
    };
    page.render(renderContext);
  });
});
