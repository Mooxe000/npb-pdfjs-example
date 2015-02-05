
/* Copyright 2014 Mozilla Foundation
#
 * Licensed under the Apache License, Version 2.0 (the "License");
 * you may not use this file except in compliance with the License.
 * You may obtain a copy of the License at
#
 *     http://www.apache.org/licenses/LICENSE-2.0
#
 * Unless required by applicable law or agreed to in writing, software
 * distributed under the License is distributed on an "AS IS" BASIS,
 * WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
 * See the License for the specific language governing permissions and
 * limitations under the License.
 */
var PAGE_NUMBER, PAGE_SCALE, PDF_PATH, SVG_NS, buildSVG, pageLoaded;

PDF_PATH = '/npb-pdfjs-example/PDF/test.pdf';

PAGE_NUMBER = 1;

PAGE_SCALE = 1.5;

SVG_NS = 'http://www.w3.org/2000/svg';

buildSVG = function(viewport, textContent) {
  var svg;
  svg = document.createElementNS(SVG_NS, 'svg:svg');
  svg.setAttribute('width', viewport.width + "px");
  svg.setAttribute('height', viewport.height + "px");
  svg.setAttribute('font-size', 1);
  textContent.items.forEach(function(textItem) {
    var style, text, tx;
    tx = PDFJS.Util.transform(PDFJS.Util.transform(viewport.transform, textItem.transform), [1, 0, 0, -1, 0, 0]);
    style = textContent.styles[textItem.fontName];
    text = document.createElementNS(SVG_NS, 'svg:text');
    text.setAttribute('transform', 'matrix(' + tx.join(' ') + ')');
    text.setAttribute('font-family', style.fontFamily);
    text.textContent = textItem.str;
    svg.appendChild(text);
  });
  return svg;
};

pageLoaded = function() {
  PDFJS.getDocument({
    url: PDF_PATH
  }).then(function(pdfDocument) {
    pdfDocument.getPage(PAGE_NUMBER).then(function(page) {
      var viewport;
      viewport = page.getViewport(PAGE_SCALE);
      page.getTextContent().then(function(textContent) {
        var svg;
        svg = buildSVG(viewport, textContent);
        document.getElementById('pageContainer').appendChild(svg);
      });
    });
  });
};

document.addEventListener('DOMContentLoaded', function() {
  if (typeof PDFJS === 'undefined') {
    alert("Built version of PDF.js was not found.\nPlease run `node make generic`.");
    return;
  }
  pageLoaded();
});
