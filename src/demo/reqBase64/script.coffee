container = document.getElementById 'viewerContainer'
pdfViewer = new PDFJS.PDFViewer
  container: container
container.addEventListener 'pagesinit', ->
  # we can use pdfViewer now, e.g. let's change default scale.
  pdfViewer.currentScaleValue = 'page-width'
  return

getPdfData = ->
  new Promise (resolve, reject) ->
    (
      httpinvoke 'http://121.40.33.89:8099/files/file'
      , 'POST'
      ,
        outputType: 'json',
        converters:
          'text json': JSON.parse
          'json text': JSON.stringify
    ).then (
      (res) ->
#        pdfData = atob res.body.file64
        pdfData = res.body.file64
        resolve pdfData
    ), (
      (err) ->
        console.error 'Get pdfData error!', err
        reject()
    )

fillInDom = (pdfData) ->
  new Promise (resolve, reject) ->
#    PDFJS.getDocument
#      data: pdfData
    DEFAULT_URL = 'data:application/pdf;base64,' + pdfData
    PDFJS.getDocument DEFAULT_URL
    .then (
      (pdf) ->
        # Document loaded, specifying document for the viewer.
        pdfViewer.setDocument pdf
        resolve 'done'
    ), (
      (err) ->
        console.error 'Fill in dom error!', err
        reject 'error'
    )

getPdfData()
.then (pdfData) -> fillInDom pdfData
.then (
  (cb_data) -> console.log cb_data
), (err) ->
  console.error err


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