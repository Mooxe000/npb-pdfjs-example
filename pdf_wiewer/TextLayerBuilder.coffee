###*
# @typedef {Object} TextLayerBuilderOptions
# @property {HTMLDivElement} textLayerDiv - The text layer container.
# @property {number} pageIndex - The page index.
# @property {PageViewport} viewport - The viewport of the text layer.
# @property {PDFFindController} findController
###

###*
# TextLayerBuilder provides text-selection functionality for the PDF.
# It does this by creating overlay divs over the PDF text. These divs
# contain text that matches the PDF text they are overlaying. This object
# also provides a way to highlight text that is being searched for.
# @class
###
class TextLayerBuilder
  construct: (options) ->
    @textLayerDiv = options.textLayerDiv
    @renderingDone = false
    @divContentDone = false
    @pageIdx = options.pageIndex
    @pageNumber = @pageIdx + 1
    @matches = []
    @viewport = options.viewport
    @textDivs = []
    @findController = options.findController or null
    @

  @::_finishRendering: -> # TextLayerBuilder_finishRendering
    @renderingDone = true
    event = document.createEvent('CustomEvent')
    event.initCustomEvent 'textlayerrendered', true, true, pageNumber: @pageNumber
    @textLayerDiv.dispatchEvent event
    return

  @::renderLayer: -> # TextLayerBuilder_renderLayer
    textLayerFrag = document.createDocumentFragment()
    textDivs = @textDivs
    textDivsLength = textDivs.length
    canvas = document.createElement 'canvas'
    ctx = canvas.getContext '2d'

    # No point in rendering many divs as it would make the browser
    # unusable even after the divs are rendered.
    if textDivsLength > MAX_TEXT_DIVS_TO_RENDER
      @_finishRendering()
      return

    lastFontSize = undefined
    lastFontFamily = undefined

    i = 0
    while i < textDivsLength
      textDiv = textDivs[i]
      unless textDiv.dataset.isWhitespace is undefined
        i++
      continue

      fontSize = textDiv.style.fontSize
      fontFamily = textDiv.style.fontFamily

      # Only build font string and set to context if different from last.
      if fontSize != lastFontSize or fontFamily != lastFontFamily
        ctx.font = fontSize + ' ' + fontFamily
        lastFontSize = fontSize
        lastFontFamily = fontFamily

      width = ctx.measureText(textDiv.textContent).width

      if width > 0
        textLayerFrag.appendChild textDiv
        transform = undefined
        if textDiv.dataset.canvasWidth != undefined
          # Dataset values come of type string.
          textScale = textDiv.dataset.canvasWidth / width
          transform = 'scaleX(' + textScale + ')'
        else
          transform = ''
        rotation = textDiv.dataset.angle
        if rotation
          transform = 'rotate(' + rotation + 'deg) ' + transform
        if transform
          CustomStyle.setProp 'transform', textDiv, transform
      i++

    @textLayerDiv.appendChild textLayerFrag
    @_finishRendering()
    @updateMatches()
    return

  ###*
  # Renders the text layer.
  # @param {number} timeout (optional) if specified, the rendering waits
  #   for specified amount of ms.
  ###
  @::render: (timeout) -> # TextLayerBuilder_render
    if !@divContentDone or @renderingDone
      return

    if @renderTimer
      clearTimeout @renderTimer
      @renderTimer = null

    if !timeout
      # Render right away
      @renderLayer()
    else
      # Schedule
      self = this
      @renderTimer = setTimeout (
        ->
          self.renderLayer()
          self.renderTimer = null
          return
      ), timeout
    return

  @::appendText: (geom, styles) -> # TextLayerBuilder_appendText
    style = styles[geom.fontName]
    textDiv = document.createElement 'div'
    @textDivs.push textDiv
    if isAllWhitespace geom.str
      textDiv.dataset.isWhitespace = true
      return

    tx = PDFJS.Util.transform @viewport.transform, geom.transform
    angle = Math.atan2 tx[1], tx[0]

    if style.vertical
      angle += Math.PI / 2

    fontHeight = Math.sqrt tx[2] * tx[2] + tx[3] * tx[3]
    fontAscent = fontHeight

    if style.ascent
      fontAscent = style.ascent * fontAscent
    else if style.descent
      fontAscent = (1 + style.descent) * fontAscent

    left = undefined
    top = undefined

    if angle is 0
      left = tx[4]
      top = tx[5] - fontAscent
    else
      left = tx[4] + fontAscent * Math.sin(angle)
      top = tx[5] - fontAscent * Math.cos(angle)

    textDiv.style.left = left + 'px'
    textDiv.style.top = top + 'px'
    textDiv.style.fontSize = fontHeight + 'px'
    textDiv.style.fontFamily = style.fontFamily
    textDiv.textContent = geom.str

    # |fontName| is only used by the Font Inspector. This test will succeed
    # when e.g. the Font Inspector is off but the Stepper is on, but it's
    # not worth the effort to do a more accurate test.
    if PDFJS.pdfBug
      textDiv.dataset.fontName = geom.fontName

    # Storing into dataset will convert number into string.
    if angle != 0
      textDiv.dataset.angle = angle * 180 / Math.PI

    # We don't bother scaling single-char text divs, because it has very
    # little effect on text highlighting. This makes scrolling on docs with
    # lots of such divs a lot faster.
    if textDiv.textContent.length > 1
      if style.vertical
        textDiv.dataset.canvasWidth = geom.height * @viewport.scale
      else
        textDiv.dataset.canvasWidth = geom.width * @viewport.scale
    return

  @::setTextContent: (textContent) -> # TextLayerBuilder_setTextContent
    @textContent = textContent
    textItems = textContent.items
    i = 0
    len = textItems.length
    while i < len
      @appendText textItems[i], textContent.styles
      i++
    @divContentDone = true
    return

  @::convertMatches: (matches) -> # TextLayerBuilder_convertMatches
    i = 0
    iIndex = 0
    bidiTexts = @textContent.items
    end = bidiTexts.length - 1
    queryLen = if @findController == null then 0 else @findController.state.query.length
    ret = []

    m = 0
    len = matches.length
    while m < len
      # Calculate the start position.
      matchIdx = matches[m]

      # Loop over the divIdxs.
      while i != end and matchIdx >= iIndex + bidiTexts[i].str.length
        iIndex += bidiTexts[i].str.length
        i++

      if i == bidiTexts.length
        console.error 'Could not find a matching mapping'

      match = begin:
        divIdx: i
        offset: matchIdx - iIndex

      # Calculate the end position.
      matchIdx += queryLen

      # Somewhat the same array as above, but use > instead of >= to get
      # the end position right.
      while i != end and matchIdx > iIndex + bidiTexts[i].str.length
        iIndex += bidiTexts[i].str.length
        i++

      match.end =
        divIdx: i
        offset: matchIdx - iIndex

      ret.push match
      m++

    ret

  @::renderMatches: (matches) -> # TextLayerBuilder_renderMatches
    # Early exit if there is nothing to render.
    return if matches.length is 0
    bidiTexts = @textContent.items
    textDivs = @textDivs
    prevEnd = null
    pageIdx = @pageIdx
    isSelectedPage =
      if @findController is null
      then false
      else pageIdx is @findController.selected.pageIdx
    selectedMatchIdx =
      if @findController is null
      then -1
      else @findController.selected.matchIdx
    highlightAll =
      if @findController is null
      then false
      else @findController.state.highlightAll
    infinity =
      divIdx: -1
      offset: undefined

    beginText = (begin, className) ->
      divIdx = begin.divIdx
      textDivs[divIdx].textContent = ''
      appendTextToDiv divIdx, 0, begin.offset, className
      return

    appendTextToDiv = (divIdx, fromOffset, toOffset, className) ->
      div = textDivs[divIdx]
      content = bidiTexts[divIdx].str.substring(fromOffset, toOffset)
      node = document.createTextNode(content)
      if className
        span = document.createElement('span')
        span.className = className
        span.appendChild node
        div.appendChild span
        return
      div.appendChild node
      return

    i0 = selectedMatchIdx
    i1 = i0 + 1
    if highlightAll
      i0 = 0
      i1 = matches.length
    else if !isSelectedPage
      # Not highlighting all and this isn't the selected page, so do nothing.
      return

    i = i0
    while i < i1
      match = matches[i]
      begin = match.begin
      end = match.end
      isSelected = isSelectedPage and i is selectedMatchIdx
      highlightSuffix = if isSelected then ' selected' else ''
      if @findController
        @findController.updateMatchPosition pageIdx
        , i, textDivs, begin.divIdx, end.divIdx

      # Match inside new div.
      if !prevEnd or begin.divIdx != prevEnd.divIdx
        # If there was a previous div, then add the text at the end.
        if prevEnd != null
          appendTextToDiv prevEnd.divIdx, prevEnd.offset, infinity.offset
        # Clear the divs and set the content until the starting point.
        beginText begin
      else
        appendTextToDiv prevEnd.divIdx, prevEnd.offset, begin.offset

      if begin.divIdx is end.divIdx
        appendTextToDiv begin.divIdx, begin.offset, end.offset, 'highlight' + highlightSuffix
      else
        appendTextToDiv begin.divIdx, begin.offset, infinity.offset, 'highlight begin' + highlightSuffix

        n0 = begin.divIdx + 1
        n1 = end.divIdx
        while n0 < n1
          textDivs[n0].className = 'highlight middle' + highlightSuffix
          n0++
        beginText end, 'highlight end' + highlightSuffix
      prevEnd = end
      i++

    if prevEnd
      appendTextToDiv prevEnd.divIdx, prevEnd.offset, infinity.offset

    return

  @::updateMatches: -> # TextLayerBuilder_updateMatches
    # Only show matches when all rendering is done.
    return unless @renderingDone

    # Clear all matches.
    matches = @matches
    textDivs = @textDivs
    bidiTexts = @textContent.items
    clearedUntilDivIdx = -1

    # Clear all current matches.
    i = 0
    len = matches.length
    while i < len
      match = matches[i]
      begin = Math.max(clearedUntilDivIdx, match.begin.divIdx)
      n = begin
      end = match.end.divIdx
      while n <= end
        div = textDivs[n]
        div.textContent = bidiTexts[n].str
        div.className = ''
        n++
      clearedUntilDivIdx = match.end.divIdx + 1
      i++

    if @findController == null or !@findController.active
      return

    # Convert the matches on the page controller into the match format
    # used for the textLayer.
    @matches = @convertMatches(if @findController == null then [] else @findController.pageMatches[@pageIdx] or [])
    @renderMatches @matches
    return

###*
# @constructor
# @implements IPDFAnnotationsLayerFactory
###
class DefaultAnnotationsLayerFactory
  constructor: ->
  @::createAnnotationsLayerBuilder: (pageDiv, pdfPage) ->
    new AnnotationsLayerBuilder
      pageDiv: pageDiv
      pdfPage: pdfPage