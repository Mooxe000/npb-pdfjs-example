var container, fillInDom, getPdfData, pdfViewer;

container = document.getElementById('viewerContainer');

pdfViewer = new PDFJS.PDFViewer({
  container: container
});

container.addEventListener('pagesinit', function() {
  pdfViewer.currentScaleValue = 'page-width';
});

getPdfData = function() {
  return new Promise(function(resolve, reject) {
    return (httpinvoke('http://121.40.33.89:8099/files/file', 'POST', {
      outputType: 'json',
      converters: {
        'text json': JSON.parse,
        'json text': JSON.stringify
      }
    })).then((function(res) {
      var pdfData;
      pdfData = res.body.file64;
      return resolve(pdfData);
    }), (function(err) {
      console.error('Get pdfData error!', err);
      return reject();
    }));
  });
};

fillInDom = function(pdfData) {
  return new Promise(function(resolve, reject) {
    var DEFAULT_URL;
    DEFAULT_URL = 'data:application/pdf;base64,' + pdfData;
    return PDFJS.getDocument(DEFAULT_URL).then((function(pdf) {
      pdfViewer.setDocument(pdf);
      return resolve('done');
    }), (function(err) {
      console.error('Fill in dom error!', err);
      return reject('error');
    }));
  });
};

getPdfData().then(function(pdfData) {
  return fillInDom(pdfData);
}).then((function(cb_data) {
  return console.log(cb_data);
}), function(err) {
  return console.error(err);
});
