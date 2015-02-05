#
# If absolute URL from the remote server is provided, configure the CORS
# header on that server.
#
url = '/PDF/test.pdf'
#
# Disable workers to avoid yet another cross-origin issue (workers need
# the URL of the script to be loaded, and dynamically loading a cross-origin
# script does not work).
#
# PDFJS.disableWorker = true;
#
# In cases when the pdf.worker.js is located at the different folder than the
# pdf.js's one, or the pdf.js is executed via eval(), the workerSrc property
# shall be specified.
#
# PDFJS.workerSrc = '../../scripts/pdf.worker.js';
pdfDoc = null
pageNum = 1
pageRendering = false
pageNumPending = null
scale = 0.8
canvas = document.getElementById 'the-canvas'
ctx = canvas.getContext '2d'

###
# Get page info from document, resize canvas accordingly, and render page.
# @param num Page number.
###

renderPage = (num) ->
  pageRendering = true
  # Using promise to fetch the page
  pdfDoc.getPage num
  .then (page) ->
    viewport = page.getViewport scale
    canvas.height = viewport.height
    canvas.width = viewport.width

    # Render PDF page into canvas context
    renderContext =
      canvasContext: ctx
      viewport: viewport
    renderTask = page.render renderContext

    # Wait for rendering to finish
    renderTask.promise.then ->
      pageRendering = false
      if pageNumPending isnt null
        # New page rendering is pending
        renderPage pageNumPending
        pageNumPending = null
      return
    return

  # Update page counters
  document.getElementById 'page_num'
  .textContent = pageNum

  return

###
# If another page rendering in progress, waits until the rendering is
# finised. Otherwise, executes rendering immediately.
###

queueRenderPage = (num) ->
  if pageRendering
  then pageNumPending = num
  else renderPage num

###
# Displays previous page.
###

onPrevPage = ->
  return if pageNum <= 1
  pageNum--
  queueRenderPage pageNum
  return
document.getElementById 'prev'
.addEventListener 'click', onPrevPage

###
# Displays next page.
###

onNextPage = ->
  return if pageNum >= pdfDoc.numPages
  pageNum++
  queueRenderPage pageNum
  return
document.getElementById 'next'
.addEventListener 'click', onNextPage

###*
# Asynchronously downloads PDF.
###

PDFJS.getDocument url
.then (pdfDoc_) ->
  pdfDoc = pdfDoc_
  document.getElementById 'page_count'
  .textContent = pdfDoc.numPages
  # Initial/first page rendering
  renderPage pageNum
  return

# ---
# generated by js2coffee 2.0.0