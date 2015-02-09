CSS_UNITS = 96.0 / 72.0

getPdfData = ->
  new Promise (resolve, reject) ->
    (
#      httpinvoke 'http://121.40.33.89:8099/files/file'
      httpinvoke 'http://localhost:8099/files/file'
      , 'GET'
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

getPdfObj = (pdfData) ->
  new Promise (resolve, reject) ->
#    DEFAULT_URL = 'data:application/pdf;base64,' + pdfData
#    PDFJS.getDocument DEFAULT_URL
    PDFJS.getDocument
      data: atob pdfData
    .then (
      (pdf) ->
        resolve pdf
    ), (err) ->
      console.error 'Fill in dom error!', err
      reject 'error'

#
# Basic AcroForms input controls rendering
#

formFields = {}

setupForm = (div, content, viewport) ->

  bindInputItem = (input, item) ->
    if input.name in formFields
      value = formFields[input.name]
      if input.type is 'checkbox'
        input.checked = value
      else if !input.type or input.type is 'text'
        input.value = value

    input.onchange = ->
      if input.type is 'checkbox'
        formFields[input.name] = input.checked
      else if !input.type or input.type is 'text'
        formFields[input.name] = input.value
      return

    return

  createElementWithStyle = (tagName, item) ->
    element = document.createElement tagName
    rect =
      PDFJS.Util
      .normalizeRect(
        viewport.convertToViewportRectangle item.rect
      )
    element.style.left = "#{Math.floor rect[0]}px"
    element.style.top = "#{Math.floor rect[1]}px"
    element.style.width = "#{Math.ceil(rect[2] - rect[0])}px"
    element.style.height = "#{Math.ceil(rect[3] - rect[1])}px"
    element

  assignFontStyle = (element, item) ->
    fontStyles = ''
    if 'fontSize' in item
      fontStyles += "font-size: #{Math.round(item.fontSize * viewport.fontScale)}px;"
    switch item.textAlignment
      when 0
        fontStyles += 'text-align: left;'
      when 1
        fontStyles += 'text-align: center;'
      when 2
        fontStyles += 'text-align: right;'
    element.setAttribute 'style', "#{element.getAttribute 'style'}#{fontStyles}"
    return

  content.getAnnotations()
  .then (items) ->
    for item in items
      switch item.subtype
        when 'Widget'
          break if item.fieldType isnt 'Tx' and
            item.fieldType isnt 'Btn' and
            item.fieldType isnt 'Ch'
          inputDiv = createElementWithStyle 'div', item
          inputDiv.className = 'inputHint'
          div.appendChild inputDiv
          input = undefined
          if item.fieldType is 'Tx'
            input = createElementWithStyle 'input', item
          if item.fieldType is 'Btn'
            input = createElementWithStyle 'input', item
            if item.flags & 32768
              input.type = 'radio'
              # radio button is not supported
            else if item.flags & 65536
              input.type = 'button'
              # pushbutton is not supported
            else
              input.type = 'checkbox'
          if item.fieldType is 'Ch'
            input = createElementWithStyle 'select', item
          # select box is not supported
          input.className = 'inputControl'
          input.name = item.fullName
          input.title = item.alternativeText
          assignFontStyle input, item
          bindInputItem input, item
          div.appendChild input
    return
  return

renderPage = (div, pdf, pageNumber, callback) ->
  new Promise (resolve, reject) ->
    pdf.getPage pageNumber
    .then (
      (page) ->
        scale = (
          document.getElementById 'viewer'
        ).clientWidth / (
          page.view[2] - page.view[0] + 9
        ) / CSS_UNITS

        viewport = page.getViewport scale

        pageDisplayWidth = viewport.width
        pageDisplayHeight = viewport.height * CSS_UNITS + 9

        pageDivHolder = document.createElement 'div'

        pageDivHolder.className = 'pdfpage'
        pageDivHolder.style.width = "#{pageDisplayWidth}px"
        pageDivHolder.style.height = "#{pageDisplayHeight}px"

        div.appendChild pageDivHolder

        pdfPageView = new PDFJS.PDFPageView
          id: pageNumber
          container: pageDivHolder
          scale: scale
          defaultViewport:
            rotation: 0
          textLayerFactory: new PDFJS.DefaultTextLayerFactory
          annotationsLayerFactory: new PDFJS.DefaultAnnotationsLayerFactory
        pdfPageView.setPdfPage page
        pdfPageView.draw()
        callback()
        resolve 'done'

    ), (err) ->
      console.error 'Fill in dom error!', err
      reject 'error'

#PDFJS.getDocument 'http://localhost:9000/PDF/test.pdf'
PDFJS.getDocument 'http://fenyincloud.oss-cn-hangzhou.aliyuncs.com/pdf/test.pdf?Expires=1423830585&OSSAccessKeyId=Y4azACOX3BBdR0Qi&Signature=Zj0yslWvl2CJOt4SkpeHpO4u%2Bdo%3D'

#getPdfData()
#.then (pdfData) -> getPdfObj pdfData

.then (pdf) ->
  # Rendering all pages starting from first
  viewer = document.getElementById 'viewer'
  pageNumber = 1

  pageRenderingComplete = ->
    if pageNumber > pdf.numPages
      return # All pages rendered
    # Continue rendering of the next page
    renderPage viewer, pdf, pageNumber++, pageRenderingComplete

  renderPage viewer, pdf, pageNumber++, pageRenderingComplete
.then (cb_data) -> console.info cb_data
