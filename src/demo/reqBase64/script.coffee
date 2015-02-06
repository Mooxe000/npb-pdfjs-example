#container = document.getElementById 'viewerContainer'
#pdfViewer = new PDFJS.PDFViewer
#  container: container
#
#(
#  httpinvoke 'http://localhost:8099/files/file'
#  , 'GET'
#  ,
#    outputType: 'json',
#    converters:
#      'text json': JSON.parse
#      'json text': JSON.stringify
#).then (res) ->
#  pdfData = atob res.body.file64
#  pdfData
#.then (pdfData) ->
#  new Promise (resolve, reject) ->
#    PDFJS.getDocument
#      data: pdfData
#    .then (pdf) ->
#      if pdf
#        # Document loaded, specifying document for the viewer.
#        pdfViewer.setDocument pdfData
#        resolve 'done'
#      else
#        reject 'error'
#.then (cbdata) ->
#  console.log cbdata

#    # Fetch the first page.
#    pdf.getPage 1
#    .then (page) ->
#      scale = 1.5
#      viewport = page.getViewport scale
#      # Prepare canvas using PDF page dimensions.
#      canvas = document.getElementById 'the-canvas'
#      context = canvas.getContext '2d'
#      canvas.height = viewport.height
#      canvas.width = viewport.width
#      # Render PDF page into canvas context.
#      renderContext =
#        canvasContext: context
#        viewport: viewport
#      page.render renderContext