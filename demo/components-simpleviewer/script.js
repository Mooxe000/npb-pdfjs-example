
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
var DEFAULT_URL, container, pdfViewer;

if (!PDFJS.PDFViewer || !PDFJS.getDocument) {
  alert('Please build the library and components using\n' + '  `node make generic components`');
}

DEFAULT_URL = '/npb-pdfjs-example/PDF/test.pdf';

container = document.getElementById('viewerContainer');

pdfViewer = new PDFJS.PDFViewer({
  container: container
});

container.addEventListener('pagesinit', function() {
  pdfViewer.currentScaleValue = 'page-width';
});

PDFJS.getDocument(DEFAULT_URL).then(function(pdfDocument) {
  pdfViewer.setDocument(pdfDocument);
});
