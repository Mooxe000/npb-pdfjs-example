var formFields, renderPage, setupForm,
  __indexOf = [].indexOf || function(item) { for (var i = 0, l = this.length; i < l; i++) { if (i in this && this[i] === item) return i; } return -1; };

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
  pdf.getPage(pageNumber).then(function(page) {
    var canvas, context, formDiv, pageDisplayHeight, pageDisplayWidth, pageDivHolder, renderContext, scale, viewport;
    scale = 1.5;
    viewport = page.getViewport(scale);
    pageDisplayWidth = viewport.width;
    pageDisplayHeight = viewport.height;
    pageDivHolder = document.createElement('div');
    pageDivHolder.className = 'pdfpage';
    pageDivHolder.style.width = pageDisplayWidth + "px";
    pageDivHolder.style.height = pageDisplayHeight + "px";
    div.appendChild(pageDivHolder);
    canvas = document.createElement('canvas');
    context = canvas.getContext('2d');
    canvas.width = pageDisplayWidth;
    canvas.height = pageDisplayHeight;
    pageDivHolder.appendChild(canvas);
    renderContext = {
      canvasContext: context,
      viewport: viewport
    };
    page.render(renderContext).promise.then(callback);
    formDiv = document.createElement('div');
    pageDivHolder.appendChild(formDiv);
    setupForm(formDiv, page, viewport);
  });
};

PDFJS.getDocument(pdfWithFormsPath).then(function(pdf) {
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
});
