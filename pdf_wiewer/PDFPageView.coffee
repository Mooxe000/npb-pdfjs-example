###*
# @typedef {Object} PDFPageViewOptions
# @property {HTMLDivElement} container - The viewer element.
# @property {number} id - The page unique ID (normally its number).
# @property {number} scale - The page scale display.
# @property {PageViewport} defaultViewport - The page viewport.
# @property {PDFRenderingQueue} renderingQueue - The rendering queue object.
# @property {IPDFTextLayerFactory} textLayerFactory
# @property {IPDFAnnotationsLayerFactory} annotationsLayerFactory
###

###*
# @class
# @implements {IRenderableView}
###
PDFPageView = do -> # PDFPageViewClosure
  ###*
   * @constructs PDFPageView
   * @param {PDFPageViewOptions} options
  ###
  construct: (options) ->
    container = options.container
    id = options.id
    scale = options.scale
    defaultViewport = options.defaultViewport
    renderingQueue = options.renderingQueue
    textLayerFactory = options.textLayerFactory
    annotationsLayerFactory = options.annotationsLayerFactory

    @id = id
    @renderingId = 'page' + id
    @rotation = 0
    @scale = scale or 1.0
    @viewport = defaultViewport
    @pdfPageRotate = defaultViewport.rotation
    @hasRestrictedScaling = false
    @renderingQueue = renderingQueue
    @textLayerFactory = textLayerFactory
    @annotationsLayerFactory = annotationsLayerFactory
    @renderingState = RenderingStates.INITIAL
    @resume = null
    @onBeforeDraw = null
    @onAfterDraw = null
    @textLayer = null
    @zoomLayer = null
    @annotationLayer = null

    div = document.createElement('div')
    div.id = 'pageContainer' + @id
    div.className = 'page'
    div.style.width = Math.floor(@viewport.width) + 'px'
    div.style.height = Math.floor(@viewport.height) + 'px'

    @el = div
    # TODO replace 'el' property usage
    @div = div

    container.appendChild div

    return

  @::setPdfPage = (pdfPage) -> # PDFPageView_setPdfPage
    @pdfPage = pdfPage
    @pdfPageRotate = pdfPage.rotate
    totalRotation = (@rotation + @pdfPageRotate) % 360
    @viewport = pdfPage.getViewport(@scale * CSS_UNITS, totalRotation)
    @stats = pdfPage.stats
    @reset()
    return

  @::destroy: -> # PDFPageView_destroy
    @zoomLayer = null
    @reset()
    if @pdfPage
      @pdfPage.destroy()
    return

  @::reset: (keepAnnotations) -> # PDFPageView_reset
    @renderTask.cancel() if @renderTask
    @resume = null
    @renderingState = RenderingStates.INITIAL

    div = @div
    div.style.width = Math.floor(@viewport.width) + 'px'
    div.style.height = Math.floor(@viewport.height) + 'px'

    childNodes = div.childNodes
    currentZoomLayer = @zoomLayer or null
    currentAnnotationNode = keepAnnotations and
      @annotationLayer and
      @annotationLayer.div or
      null

    i = childNodes.length - 1
    while i >= 0
      node = childNodes[i]
      if currentZoomLayer == node or currentAnnotationNode == node
        i--
      continue
      div.removeChild node
      i--

    div.removeAttribute 'data-loaded'

    if keepAnnotations
      if @annotationLayer
        # Hide annotationLayer until all elements are resized
        # so they are not displayed on the already-resized page
        @annotationLayer.hide()
    else
      @annotationLayer = null

    if @canvas
      # Zeroing the width and height causes Firefox to release graphics
      # resources immediately, which can greatly reduce memory consumption.
      @canvas.width = 0
      @canvas.height = 0
      delete @canvas

    @loadingIconDiv = document.createElement 'div'
    @loadingIconDiv.className = 'loadingIcon'

    div.appendChild @loadingIconDiv

    return

  @::update: (scale, rotation) -> # PDFPageView_update
    @scale = scale or @scale
    @rotation = rotation unless typeof rotation is 'undefined'

    totalRotation = (@rotation + @pdfPageRotate) % 360

    @viewport = @viewport.clone(
      scale: @scale * CSS_UNITS
      rotation: totalRotation)

    isScalingRestricted = false

    if @canvas and PDFJS.maxCanvasPixels > 0
      ctx = @canvas.getContext '2d'
      outputScale = getOutputScale ctx
      pixelsInViewport = @viewport.width * @viewport.height
      maxScale = Math.sqrt PDFJS.maxCanvasPixels / pixelsInViewport

      if ((
        Math.floor(@viewport.width) * outputScale.sx | 0
      ) * (
        Math.floor(@viewport.height) * outputScale.sy | 0
      )) > PDFJS.maxCanvasPixels
        isScalingRestricted = true

    if @canvas and (
      PDFJS.useOnlyCssZoom or (
        @hasRestrictedScaling and
        isScalingRestricted
      )
    )
      @cssTransform @canvas, true
      return
    else if @canvas and !@zoomLayer
      @zoomLayer = @canvas.parentNode
      @zoomLayer.style.position = 'absolute'

    if @zoomLayer
      @cssTransform @zoomLayer.firstChild

    @reset true

    return

  ###*
    * Called when moved in the parent's container.
  ###
  @::updatePosition: -> # PDFPageView_updatePosition
    if @textLayer
      @textLayer.render TEXT_LAYER_RENDER_DELAY
    return

  @::cssTransform: (canvas, redrawAnnotations) -> # PDFPageView_transform
    # Scale canvas, canvas wrapper, and page container.
    width = @viewport.width
    height = @viewport.height
    div = @div
    canvas.style.width = canvas.parentNode.style.width = div.style.width = Math.floor(width) + 'px'
    canvas.style.height = canvas.parentNode.style.height = div.style.height = Math.floor(height) + 'px'
    # The canvas may have been originally rotated, rotate relative to that.
    relativeRotation = @viewport.rotation - canvas._viewport.rotation
    absRotation = Math.abs(relativeRotation)
    scaleX = 1
    scaleY = 1
    if absRotation == 90 or absRotation == 270
      # Scale x and y because of the rotation.
      scaleX = height / width
      scaleY = width / height
    cssTransform = 'rotate(' + relativeRotation + 'deg) ' + 'scale(' + scaleX + ',' + scaleY + ')'
    CustomStyle.setProp 'transform', canvas, cssTransform
    if @textLayer
      # Rotating the text layer is more complicated since the divs inside the
      # the text layer are rotated.
      # TODO: This could probably be simplified by drawing the text layer in
      # one orientation then rotating overall.
      textLayerViewport = @textLayer.viewport
      textRelativeRotation = @viewport.rotation - textLayerViewport.rotation
      textAbsRotation = Math.abs(textRelativeRotation)
      scale = width / textLayerViewport.width
      if textAbsRotation == 90 or textAbsRotation == 270
        scale = width / textLayerViewport.height
      textLayerDiv = @textLayer.textLayerDiv
      transX = undefined
      transY = undefined
      switch textAbsRotation
        when 0
          transX = transY = 0
        when 90
          transX = 0
          transY = '-' + textLayerDiv.style.height
        when 180
          transX = '-' + textLayerDiv.style.width
          transY = '-' + textLayerDiv.style.height
        when 270
          transX = '-' + textLayerDiv.style.width
          transY = 0
        else
          console.error 'Bad rotation value.'
          break
      CustomStyle.setProp 'transform', textLayerDiv, 'rotate(' + textAbsRotation + 'deg) ' + 'scale(' + scale + ', ' + scale + ') ' + 'translate(' + transX + ', ' + transY + ')'
      CustomStyle.setProp 'transformOrigin', textLayerDiv, '0% 0%'
    if redrawAnnotations and @annotationLayer
      @annotationLayer.setupAnnotations @viewport
    return

  get_width: -> @viewport.width
  get_height: -> @viewport.height

  @::getPagePoint = (x, y) -> # PDFPageView_getPagePoint
    @viewport.convertToPdfPoint x, y

  @::draw: -> # PDFPageView_draw

    unless @renderingState is RenderingStates.INITIAL
      console.error 'Must be in new state before drawing'

    @renderingState = RenderingStates.RUNNING

    pdfPage = @pdfPage
    viewport = @viewport
    div = @div

    # Wrap the canvas so if it has a css transform for highdpi the overflow
    # will be hidden in FF.
    canvasWrapper = document.createElement('div')
    canvasWrapper.style.width = div.style.width
    canvasWrapper.style.height = div.style.height
    canvasWrapper.classList.add 'canvasWrapper'

    canvas = document.createElement('canvas')
    canvas.id = 'page' + @id
    canvasWrapper.appendChild canvas

    if @annotationLayer
      # annotationLayer needs to stay on top
      div.insertBefore canvasWrapper, @annotationLayer.div
    else
      div.appendChild canvasWrapper
    @canvas = canvas

    ctx = canvas.getContext '2d'
    outputScale = getOutputScale ctx

    if PDFJS.useOnlyCssZoom
      actualSizeViewport = viewport.clone scale: CSS_UNITS

      # Use a scale that will make the canvas be the original intended size
      # of the page.
      outputScale.sx *= actualSizeViewport.width / viewport.width
      outputScale.sy *= actualSizeViewport.height / viewport.height
      outputScale.scaled = true

    if PDFJS.maxCanvasPixels > 0
      pixelsInViewport = viewport.width * viewport.height
      maxScale = Math.sqrt PDFJS.maxCanvasPixels / pixelsInViewport
      if outputScale.sx > maxScale or outputScale.sy > maxScale
        outputScale.sx = maxScale
        outputScale.sy = maxScale
        outputScale.scaled = true
        @hasRestrictedScaling = true
      else
        @hasRestrictedScaling = false

    canvas.width = Math.floor(viewport.width) * outputScale.sx | 0
    canvas.height = Math.floor(viewport.height) * outputScale.sy | 0
    canvas.style.width = Math.floor(viewport.width) + 'px'
    canvas.style.height = Math.floor(viewport.height) + 'px'

    # Add the viewport so it's known what it was originally drawn with.
    canvas._viewport = viewport

    textLayerDiv = null
    textLayer = null

    if @textLayerFactory
      textLayerDiv = document.createElement('div')
      textLayerDiv.className = 'textLayer'
      textLayerDiv.style.width = canvas.style.width
      textLayerDiv.style.height = canvas.style.height

      if @annotationLayer
        # annotationLayer needs to stay on top
        div.insertBefore textLayerDiv, @annotationLayer.div
      else
        div.appendChild textLayerDiv

      textLayer = @textLayerFactory.createTextLayerBuilder(textLayerDiv, @id - 1, @viewport)

    @textLayer = textLayer

    # TODO(mack): use data attributes to store these
    ctx._scaleX = outputScale.sx
    ctx._scaleY = outputScale.sy
    ctx.scale outputScale.sx, outputScale.sy if outputScale.scaled

    resolveRenderPromise = undefined
    rejectRenderPromise = undefined

    promise = new Promise (resolve, reject) ->
      resolveRenderPromise = resolve
      rejectRenderPromise = reject
      return

    # Rendering area
    self = this

    pageViewDrawCallback = (error) ->
      # The renderTask may have been replaced by a new one, so only remove
      # the reference to the renderTask if it matches the one that is
      # triggering this callback.
      self.renderTask = null if renderTask is self.renderTask
      rejectRenderPromise error if error is 'cancelled'

      self.renderingState = RenderingStates.FINISHED

      if self.loadingIconDiv
        div.removeChild self.loadingIconDiv
        delete self.loadingIconDiv

      if self.zoomLayer
        div.removeChild self.zoomLayer
        self.zoomLayer = null

      self.error = error
      self.stats = pdfPage.stats

      self.onAfterDraw() if self.onAfterDraw

      event = document.createEvent 'CustomEvent'
      event.initCustomEvent 'pagerendered', true, true, pageNumber: self.id

      div.dispatchEvent event

      unless error
        resolveRenderPromise undefined
      else
        rejectRenderPromise error

      return

    if @renderingQueue
      renderContinueCallback = (cont) ->
        unless self.renderingQueue.isHighestPriority self
          self.renderingState = RenderingStates.PAUSED
          self.resume = -> # resumeCallback
            self.renderingState = RenderingStates.RUNNING
            cont()
            return
          return
        cont()
        return

    renderContext =
      canvasContext: ctx
      viewport: @viewport
      # intent: 'default', || === 'display'
      continueCallback: renderContinueCallback
    renderTask = @renderTask = @pdfPage.render renderContext

    @renderTask.promise.then (
      ->
        pageViewDrawCallback null
        if textLayer
          self.pdfPage.getTextContent()
          .then (textContent) ->
            textLayer.setTextContent textContent
            textLayer.render TEXT_LAYER_RENDER_DELAY
            return
        return
    ), (error) -> # pdfPageRenderError
      pageViewDrawCallback error
      return

    if @annotationsLayerFactory
      unless @annotationLayer
        @annotationLayer = @annotationsLayerFactory.createAnnotationsLayerBuilder div, @pdfPage
      @annotationLayer.setupAnnotations @viewport
    div.setAttribute 'data-loaded', true

    if self.onBeforeDraw
      self.onBeforeDraw()

    promise

