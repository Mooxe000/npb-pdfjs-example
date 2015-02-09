var CSS_UNITS, formFields, getPdfData, getPdfObj, renderPage, setupForm,
  __indexOf = [].indexOf || function(item) { for (var i = 0, l = this.length; i < l; i++) { if (i in this && this[i] === item) return i; } return -1; };

CSS_UNITS = 96.0 / 72.0;

getPdfData = function() {
  return new Promise(function(resolve, reject) {
    return (httpinvoke('http://localhost:8099/files/file', 'GET', {
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

getPdfObj = function(pdfData) {
  return new Promise(function(resolve, reject) {
    return PDFJS.getDocument({
      data: atob(pdfData)
    }).then((function(pdf) {
      return resolve(pdf);
    }), function(err) {
      console.error('Fill in dom error!', err);
      return reject('error');
    });
  });
};

formFields = {};

setupForm = function(div, content, viewport) {
  var assignFontStyle, bindInputItem, createElementWithStyle;
  bindInputItem = function(input, item) {
    var value, _ref;
    if (_ref = input.name, __indexOf.call(formFields, _ref) >= 0) {
      value = formFields[input.name];
      if (input.type === 'checkbox') {
        input.checked = value;
      } else if (!input.type || input.type === 'text') {
        input.value = value;
      }
    }
    input.onchange = function() {
      if (input.type === 'checkbox') {
        formFields[input.name] = input.checked;
      } else if (!input.type || input.type === 'text') {
        formFields[input.name] = input.value;
      }
    };
  };
  createElementWithStyle = function(tagName, item) {
    var element, rect;
    element = document.createElement(tagName);
    rect = PDFJS.Util.normalizeRect(viewport.convertToViewportRectangle(item.rect));
    element.style.left = (Math.floor(rect[0])) + "px";
    element.style.top = (Math.floor(rect[1])) + "px";
    element.style.width = (Math.ceil(rect[2] - rect[0])) + "px";
    element.style.height = (Math.ceil(rect[3] - rect[1])) + "px";
    return element;
  };
  assignFontStyle = function(element, item) {
    var fontStyles;
    fontStyles = '';
    if (__indexOf.call(item, 'fontSize') >= 0) {
      fontStyles += "font-size: " + (Math.round(item.fontSize * viewport.fontScale)) + "px;";
    }
    switch (item.textAlignment) {
      case 0:
        fontStyles += 'text-align: left;';
        break;
      case 1:
        fontStyles += 'text-align: center;';
        break;
      case 2:
        fontStyles += 'text-align: right;';
    }
    element.setAttribute('style', "" + (element.getAttribute('style')) + fontStyles);
  };
  content.getAnnotations().then(function(items) {
    var input, inputDiv, item, _i, _len;
    for (_i = 0, _len = items.length; _i < _len; _i++) {
      item = items[_i];
      switch (item.subtype) {
        case 'Widget':
          if (item.fieldType !== 'Tx' && item.fieldType !== 'Btn' && item.fieldType !== 'Ch') {
            break;
          }
          inputDiv = createElementWithStyle('div', item);
          inputDiv.className = 'inputHint';
          div.appendChild(inputDiv);
          input = void 0;
          if (item.fieldType === 'Tx') {
            input = createElementWithStyle('input', item);
          }
          if (item.fieldType === 'Btn') {
            input = createElementWithStyle('input', item);
            if (item.flags & 32768) {
              input.type = 'radio';
            } else if (item.flags & 65536) {
              input.type = 'button';
            } else {
              input.type = 'checkbox';
            }
          }
          if (item.fieldType === 'Ch') {
            input = createElementWithStyle('select', item);
          }
          input.className = 'inputControl';
          input.name = item.fullName;
          input.title = item.alternativeText;
          assignFontStyle(input, item);
          bindInputItem(input, item);
          div.appendChild(input);
      }
    }
  });
};

renderPage = function(div, pdf, pageNumber, callback) {
  return new Promise(function(resolve, reject) {
    return pdf.getPage(pageNumber).then((function(page) {
      var pageDisplayHeight, pageDisplayWidth, pageDivHolder, pdfPageView, scale, viewport;
      scale = (document.getElementById('viewer')).clientWidth / (page.view[2] - page.view[0] + 9) / CSS_UNITS;
      viewport = page.getViewport(scale);
      pageDisplayWidth = viewport.width;
      pageDisplayHeight = viewport.height * CSS_UNITS + 9;
      pageDivHolder = document.createElement('div');
      pageDivHolder.className = 'pdfpage';
      pageDivHolder.style.width = pageDisplayWidth + "px";
      pageDivHolder.style.height = pageDisplayHeight + "px";
      div.appendChild(pageDivHolder);
      pdfPageView = new PDFJS.PDFPageView({
        id: pageNumber,
        container: pageDivHolder,
        scale: scale,
        defaultViewport: {
          rotation: 0
        },
        textLayerFactory: new PDFJS.DefaultTextLayerFactory,
        annotationsLayerFactory: new PDFJS.DefaultAnnotationsLayerFactory
      });
      pdfPageView.setPdfPage(page);
      pdfPageView.draw();
      callback();
      return resolve('done');
    }), function(err) {
      console.error('Fill in dom error!', err);
      return reject('error');
    });
  });
};

PDFJS.getDocument('http://fenyincloud.oss-cn-hangzhou.aliyuncs.com/pdf/test.pdf?Expires=1423830585&OSSAccessKeyId=Y4azACOX3BBdR0Qi&Signature=Zj0yslWvl2CJOt4SkpeHpO4u%2Bdo%3D').then(function(pdf) {
  var pageNumber, pageRenderingComplete, viewer;
  viewer = document.getElementById('viewer');
  pageNumber = 1;
  pageRenderingComplete = function() {
    if (pageNumber > pdf.numPages) {
      return;
    }
    return renderPage(viewer, pdf, pageNumber++, pageRenderingComplete);
  };
  return renderPage(viewer, pdf, pageNumber++, pageRenderingComplete);
}).then(function(cb_data) {
  return console.info(cb_data);
});
