###*
# @typedef {Object} PDFViewerOptions
# @property {HTMLDivElement} container - The container for the viewer element.
# @property {HTMLDivElement} viewer - (optional) The viewer element.
# @property {IPDFLinkService} linkService - The navigation/linking service.
# @property {PDFRenderingQueue} renderingQueue - (optional) The rendering
#   queue object.
###

###*
# Simple viewer control to display PDF content/pages.
# @class
# @implements {IRenderableView}
###
class PDFViewer
  ###*
  * @constructs PDFViewer
  * @param {PDFViewerOptions} options
  ###
  constructor: (options) ->
    @container = options.container
    @viewer = options.viewer or options.container.firstElementChild
    @linkService = options.linkService or new SimpleLinkService this

    @defaultRenderingQueue = !options.renderingQueue
    if @defaultRenderingQueue
      # Custom rendering queue is not specified, using default one
      @renderingQueue = new PDFRenderingQueue
      @renderingQueue.setViewer this
    else
      @renderingQueue = options.renderingQueue
    @scroll = watchScroll @container, @_scrollUpdate.bind this
    @updateInProgress = false
    @presentationModeState = PresentationModeState.UNKNOWN
    @_resetView()
    return

  PDFPageViewBuffer = (size) ->
    data = []

    @push = (view) ->
      i = data.indexOf(view)
      if i >= 0
        data.splice i, 1
      data.push view
      if data.length > size
        data.shift().destroy()
      return

    @resize = (newSize) ->
      size = newSize
      while data.length > size
        data.shift().destroy()
      return

    return

  @::pagesCount = -> # get
    return this.pages.length

  @::currentPageNumber = (val) -> # set
    @_currentPageNumber = val unless @pdfDocument
    event = document.createEvent 'UIEvents'
    event.initUIEvent 'pagechange', true, true, window, 0
    event.updateInProgress = @updateInProgress
    unless (
      0 < val and val <= @pagesCount
    )
      event.pageNumber = @_currentPageNumber
      event.previousPageNumber = val
      @container.dispatchEvent event
      return

    event.previousPageNumber = @_currentPageNumber
    @_currentPageNumber = val
    event.pageNumber = val
    @container.dispatchEvent event
    return

  ###*
  * @returns {number}
  ###
  @::currentScale = -> @_currentScale # get

  ###*
  * @param {number} val - Scale of the pages in percents.
  ###
  @::currentScale = (val) -> # set
    if isNaN val
      throw new Error('Invalid numeric scale')
    if !@pdfDocument
      @_currentScale = val
      @_currentScaleValue = val.toString()
      return
    @_setScale val, false
    return

  ###*
  * @returns {string}
  ###
  @::currentScaleValue = -> @_currentScaleValue # get

  ###*
  * @param val - The scale of the pages (in percent or predefined value).
  ###
  @::currentScaleValue = (val) -> # set
    unless @pdfDocument
      @_currentScale =
        if isNaN(val)
        then UNKNOWN_SCALE
        else val
      @_currentScaleValue = val
      return
    @_setScale val, false
    return

  ###*
  * @returns {number}
  ###
  @::pagesRotation = -> @_pagesRotation # get

  ###*
  * @param {number} rotation - The rotation of the pages (0, 90, 180, 270).
  ###
  @::pagesRotation = (rotation) -> # set
    @_pagesRotation = rotation
    i = 0
    l = @pages.length
    while i < l
      page = @pages[i]
      page.update page.scale, rotation
      i++
    @_setScale @_currentScaleValue, true
    return

  ###*
  * @param pdfDocument {PDFDocument}
  ###
  @::setDocument = (pdfDocument) ->
    @_resetView() if @pdfDocument
    return unless pdfDocument
    @pdfDocument = pdfDocument

    pagesCount = pdfDocument.numPages
    pagesRefMap = @pagesRefMap = {}
    self = this

    resolvePagesPromise = undefined
    pagesPromise = new Promise (resolve) ->
      resolvePagesPromise = resolve
      return

    @pagesPromise = pagesPromise

    pagesPromise.then ->
      event = document.createEvent 'CustomEvent'
      event.initCustomEvent 'pagesloaded', true, true, pagesCount: pagesCount
      self.container.dispatchEvent event
      return

    isOnePageRenderedResolved = false
    resolveOnePageRendered = null
    onePageRendered = new Promise (resolve) ->
      resolveOnePageRendered = resolve
      return

    @onePageRendered = onePageRendered

    bindOnAfterAndBeforeDraw = (pageView) ->

      pageView.onBeforeDraw = ->
        # Add the page to the buffer at the start of drawing. That way it can
        # be evicted from the buffer and destroyed even if we pause its
        # rendering.
        self._buffer.push this
        return

      # when page is painted, using the image as thumbnail base
      pageView.onAfterDraw = -> # pdfViewLoadOnAfterDraw
        unless isOnePageRenderedResolved
          isOnePageRenderedResolved = true
          resolveOnePageRendered()
        return

      return

    firstPagePromise = pdfDocument.getPage 1
    @firstPagePromise = firstPagePromise

    # Fetch a single page so we can get a viewport that will be the default
    # viewport for all pages
    firstPagePromise.then (pdfPage) ->
      scale = @_currentScale or 1.0
      viewport = pdfPage.getViewport scale * CSS_UNITS

      pageNum = 1
      while pageNum <= pagesCount
        textLayerFactory = null
        if !PDFJS.disableTextLayer
          textLayerFactory = this
        pageView = new PDFPageView(
          container: @viewer
          id: pageNum
          scale: scale
          defaultViewport: viewport.clone()
          renderingQueue: @renderingQueue
          textLayerFactory: textLayerFactory
          annotationsLayerFactory: this)
        bindOnAfterAndBeforeDraw pageView
        @pages.push pageView
        ++pageNum

      # Fetch all the pages since the viewport is needed before printing
      # starts to create the correct size canvas. Wait until one page is
      # rendered so we don't tie up too many resources early on.
      onePageRendered.then -> # pageNum
        unless PDFJS.disableAutoFetch
          getPagesLeft = pagesCount
          pageNum = 1
          while pageNum <= pagesCount
            pdfDocument.getPage pageNum
            .then (pageNum, pdfPage) -> # pageView
              pageView = self.pages[pageNum - 1]
              if !pageView.pdfPage
                pageView.setPdfPage pdfPage
              refStr = pdfPage.ref.num + ' ' + pdfPage.ref.gen + ' R'
              pagesRefMap[refStr] = pageNum
              getPagesLeft--
              if !getPagesLeft
                resolvePagesPromise()
              return
            .bind(null, pageNum)
            ++pageNum
        else
          # XXX: Printing is semi-broken with auto fetch disabled.
          resolvePagesPromise()
        return

      event = document.createEvent 'CustomEvent'
      event.initCustomEvent 'pagesinit', true, true, null
      self.container.dispatchEvent event

      @update() if @defaultRenderingQueue
      return

    .bind @

  @::_resetView = ->
    @pages = []
    @_currentPageNumber = 1
    @_currentScale = UNKNOWN_SCALE
    @_currentScaleValue = null
    @_buffer = new PDFPageViewBuffer(DEFAULT_CACHE_SIZE)
    @location = null
    @_pagesRotation = 0
    @_pagesRequests = []
    container = @viewer
    while container.hasChildNodes()
      container.removeChild container.lastChild
    return

  @::_scrollUpdate = ->
    if @pagesCount == 0
      return
    @update()
    i = 0
    ii = @pages.length
    while i < ii
      @pages[i].updatePosition()
      i++
    return

  @::_setScaleUpdatePages = (newScale, newValue, noScroll, preset) ->
    @_currentScaleValue = newValue
    return if newScale is @_currentScale

    i = 0
    ii = @pages.length
    while i < ii
      @pages[i].update newScale
      i++

    @_currentScale = newScale

    unless noScroll
      page = @_currentPageNumber
      dest = undefined
      inPresentationMode = @presentationModeState == PresentationModeState.CHANGING or @presentationModeState == PresentationModeState.FULLSCREEN
      if @location and !inPresentationMode and !IGNORE_CURRENT_POSITION_ON_ZOOM
        page = @location.pageNumber
        dest = [
          null
          { name: 'XYZ' }
          @location.left
          @location.top
          null
        ]
      @scrollPageIntoView page, dest

    event = document.createEvent('UIEvents')
    event.initUIEvent 'scalechange', true, true, window, 0
    event.scale = newScale

    event.presetValue = newValue if preset
    @container.dispatchEvent event
    return

  @::_setScale = (value, noScroll) ->
    return if value is 'custom'
    scale = parseFloat(value)
    if scale > 0
      @_setScaleUpdatePages scale, value, noScroll, false
    else
      currentPage = @pages[@_currentPageNumber - 1]
      if !currentPage
        return
      inPresentationMode = @presentationModeState is PresentationModeState.FULLSCREEN
      hPadding =
        if inPresentationMode
        then 0
        else SCROLLBAR_PADDING
      vPadding =
        if inPresentationMode
        then 0
        else VERTICAL_PADDING
      pageWidthScale = (
        @container.clientWidth - hPadding
      ) / currentPage.width * currentPage.scale
      pageHeightScale = (
        @container.clientHeight - vPadding
      ) / currentPage.height * currentPage.scale
      switch value
        when 'page-actual' then scale = 1
        when 'page-width' then scale = pageWidthScale
        when 'page-height' then scale = pageHeightScale
        when 'page-fit' then scale = Math.min(pageWidthScale, pageHeightScale)
        when 'auto'
          isLandscape = currentPage.width > currentPage.height
          # For pages in landscape mode, fit the page height to the viewer
          # *unless* the page would thus become too wide to fit horizontally.
          horizontalScale = if isLandscape then Math.min(pageHeightScale, pageWidthScale) else pageWidthScale
          scale = Math.min(MAX_AUTO_SCALE, horizontalScale)
        else
          console.error 'pdfViewSetScale: \'' + value + '\' is an unknown zoom value.'
          return
      @_setScaleUpdatePages scale, value, noScroll, true
    return

  ###*
   * Scrolls page into view.
   * @param {number} pageNumber
   * @param {Array} dest - (optional) original PDF destination array:
   *   <page-ref> </XYZ|FitXXX> <args..>
  ###
  @::scrollPageIntoView = (pageNumber, dest) -> # PDFViewer_scrollPageIntoView
    pageView = @pages[pageNumber - 1]
    if @presentationModeState is PresentationModeState.FULLSCREEN
      unless @linkService.page is pageView.id
        # Avoid breaking getVisiblePages in presentation mode.
        @linkService.page = pageView.id
        return
      dest = null
      # Fixes the case when PDF has different page sizes.
      @_setScale @currentScaleValue, true

    unless dest
      scrollIntoView pageView.div
      return

    x = 0
    y = 0
    width = 0
    height = 0
    widthScale = undefined
    heightScale = undefined

    changeOrientation =
      if pageView.rotation % 180 is 0
      then false
      else true
    pageWidth = (
      if changeOrientation
      then pageView.height
      else pageView.width
    ) / pageView.scale / CSS_UNITS
    pageHeight = (
      if changeOrientation
      then pageView.width
      else pageView.height
    ) / pageView.scale / CSS_UNITS

    scale = 0
    switch dest[1].name
      when 'XYZ'
        x = dest[2]
        y = dest[3]
        scale = dest[4]
        # If x and/or y coordinates are not supplied, default to
        # _top_ left of the page (not the obvious bottom left,
        # since aligning the bottom of the intended page with the
        # top of the window is rarely helpful).
        x = if x != null then x else 0
        y = if y != null then y else pageHeight
      when 'Fit', 'FitB'
        scale = 'page-fit'
      when 'FitH', 'FitBH'
        y = dest[2]
        scale = 'page-width'
      when 'FitV', 'FitBV'
        x = dest[2]
        width = pageWidth
        height = pageHeight
        scale = 'page-height'
      when 'FitR'
        x = dest[2]
        y = dest[3]
        width = dest[4] - x
        height = dest[5] - y
        viewerContainer = @container
        widthScale = (
          viewerContainer.clientWidth - SCROLLBAR_PADDING
        ) / width / CSS_UNITS
        heightScale = (
          viewerContainer.clientHeight - SCROLLBAR_PADDING
        ) / height / CSS_UNITS
        scale = Math.min (
          Math.abs widthScale
        ), Math.abs heightScale
      else
        return

    if scale and scale isnt @currentScale
      @currentScaleValue = scale
    else if @currentScale is UNKNOWN_SCALE
      @currentScaleValue = DEFAULT_SCALE
    if scale is 'page-fit' and !dest[4]
      scrollIntoView pageView.div
      return

    boundingRect = [
      pageView.viewport.convertToViewportPoint x, y
      pageView.viewport.convertToViewportPoint x + width, y + height
    ]

    left = Math.min boundingRect[0][0], boundingRect[1][0]
    top = Math.min boundingRect[0][1], boundingRect[1][1]

    scrollIntoView pageView.div,
      left: left
      top: top

    return

  @::_updateLocation = (firstPage) ->
    currentScale = @_currentScale
    currentScaleValue = @_currentScaleValue

    normalizedScaleValue =
      if (
        parseFloat currentScaleValue
      ) is currentScale
      then Math.round(
        currentScale * 10000
      ) / 100
      else currentScaleValue
    pageNumber = firstPage.id
    pdfOpenParams = '#page=' + pageNumber
    pdfOpenParams += '&zoom=' + normalizedScaleValue
    currentPageView = @pages[pageNumber - 1]
    container = @container
    topLeft = currentPageView.getPagePoint(container.scrollLeft - firstPage.x, container.scrollTop - firstPage.y)
    intLeft = Math.round(topLeft[0])
    intTop = Math.round(topLeft[1])
    pdfOpenParams += ',' + intLeft + ',' + intTop
    @location =
      pageNumber: pageNumber
      scale: normalizedScaleValue
      top: intTop
      left: intLeft
      pdfOpenParams: pdfOpenParams
    return

  @::update = ->
    visible = @_getVisiblePages()
    visiblePages = visible.views
    return if visiblePages.length is 0
    @updateInProgress = true
    suggestedCacheSize = Math.max(DEFAULT_CACHE_SIZE, 2 * visiblePages.length + 1)
    @_buffer.resize suggestedCacheSize
    @renderingQueue.renderHighestPriority visible
    currentId = @currentPageNumber
    firstPage = visible.first
    i = 0
    ii = visiblePages.length
    stillFullyVisible = false
    while i < ii
      page = visiblePages[i]
      if page.percent < 100
        break
      if page.id == currentId
        stillFullyVisible = true
        break
      ++i
    if !stillFullyVisible
      currentId = visiblePages[0].id
    if @presentationModeState != PresentationModeState.FULLSCREEN
      @currentPageNumber = currentId
    @_updateLocation firstPage
    @updateInProgress = false
    event = document.createEvent('UIEvents')
    event.initUIEvent 'updateviewarea', true, true, window, 0
    @container.dispatchEvent event
    return

  @::containsElement = (element) -> @container.contains element
  @::focus = -> @container.focus()
  @::blur = -> @container.blur()

  @::isHorizontalScrollbarEnabled = -> @presentationModeState is (
    if PresentationModeState.FULLSCREEN
    then false
    else @container.scrollWidth > @container.clientWidth
  )

  @::_getVisiblePages = ->
    unless @presentationModeState is PresentationModeState.FULLSCREEN
      getVisibleElements @container, @pages, true
    else
      # The algorithm in getVisibleElements doesn't work in all browsers and
      # configurations when presentation mode is active.
      visible = []
      currentPage = @pages[@_currentPageNumber - 1]
      visible.push
        id: currentPage.id
        view: currentPage

      first: currentPage
      last: currentPage
      views: visible

  @::cleanup = ->
    i = 0
    ii = @pages.length
    while i < ii
      if @pages[i] and @pages[i].renderingState != RenderingStates.FINISHED
        @pages[i].reset()
      i++
    return

  ###*
  * @param {PDFPageView} pageView
  * @returns {PDFPage}
  * @private
  ###
  @::_ensurePdfPageLoaded = (pageView) ->
    return Promise.resolve pageView.pdfPage if pageView.pdfPage
    pageNumber = pageView.id
    return @_pagesRequests[pageNumber] if @_pagesRequests[pageNumber]
    promise = @pdfDocument.getPage pageNumber
    .then (pdfPage) ->
      pageView.setPdfPage pdfPage
      @_pagesRequests[pageNumber] = null
      pdfPage
    .bind @
    @_pagesRequests[pageNumber] = promise
    promise

  @::forceRendering = (currentlyVisiblePages) ->
    visiblePages = currentlyVisiblePages or @_getVisiblePages()
    pageView = @renderingQueue.getHighestPriority visiblePages, @pages, @scroll.down
    if pageView
      @_ensurePdfPageLoaded pageView
      .then ->
        @renderingQueue.renderView pageView
        return
      .bind @
      return true
    false

  @::getPageTextContent: (pageIndex) ->
    @pdfDocument.getPage(pageIndex + 1).then (page) ->
      page.getTextContent()

  ###*
  * @param {HTMLDivElement} textLayerDiv
  * @param {number} pageIndex
  * @param {PageViewport} viewport
  * @returns {TextLayerBuilder}
  ###
  @::createTextLayerBuilder = (textLayerDiv, pageIndex, viewport) ->
    isViewerInPresentationMode =
      @presentationModeState is PresentationModeState.FULLSCREEN
    new TextLayerBuilder
      textLayerDiv: textLayerDiv
      pageIndex: pageIndex
      viewport: viewport
      findController:
        if isViewerInPresentationMode
        then null
        else @findController

  ###*
  * @param {HTMLDivElement} pageDiv
  * @param {PDFPage} pdfPage
  * @returns {AnnotationsLayerBuilder}
  ###
  @::createAnnotationsLayerBuilder = (pageDiv, pdfPage) ->
    new AnnotationsLayerBuilder
      pageDiv: pageDiv
      pdfPage: pdfPage
      linkService: @linkService

  setFindController = (findController) ->
    @findController = findController
