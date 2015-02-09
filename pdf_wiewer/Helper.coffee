getFileName = (url) ->
  anchor = url.indexOf('#')
  query = url.indexOf('?')
  end = Math.min(
    if anchor > 0
    then anchor
    else url.length, (
      if query > 0
      then query
      else url.length
    )
  )
  url.substring (
    (
      url.lastIndexOf '/', end
    ) + 1
  ), end

###*
# Returns scale factor for the canvas. It makes sense for the HiDPI displays.
# @return {Object} The object with horizontal (sx) and vertical (sy)
                    scales. The scaled property is set to false if scaling is
                    not required, true otherwise.
###
getOutputScale = (ctx) ->
  devicePixelRatio = window.devicePixelRatio or 1
  backingStoreRatio =
    ctx.webkitBackingStorePixelRatio or
      ctx.mozBackingStorePixelRatio or
      ctx.msBackingStorePixelRatio or
      ctx.oBackingStorePixelRatio or
      ctx.backingStorePixelRatio or 1
  pixelRatio = devicePixelRatio / backingStoreRatio
  sx: pixelRatio
  sy: pixelRatio
  scaled: pixelRatio isnt 1

###*
# Scrolls specified element into view of its parent.
# element {Object} The element to be visible.
# spot {Object} An object with optional top and left properties,
#               specifying the offset from the top left edge.
###
scrollIntoView = (element, spot) ->
  # Assuming offsetParent is available (it's not available when viewer is in
  # hidden iframe or object). We have to scroll: if the offsetParent is not set
  # producing the error. See also animationStartedClosure.
  parent = element.offsetParent
  offsetY = element.offsetTop + element.clientTop
  offsetX = element.offsetLeft + element.clientLeft
  unless parent
    console.error 'offsetParent is not set -- cannot scroll'
    return
  while parent.clientHeight is parent.scrollHeight
    if parent.dataset._scaleY
      offsetY /= parent.dataset._scaleY
      offsetX /= parent.dataset._scaleX
    offsetY += parent.offsetTop
    offsetX += parent.offsetLeft
    parent = parent.offsetParent
    return unless parent # no need to scroll
  if spot
    if spot.top isnt undefined
      offsetY += spot.top
    if spot.left isnt undefined
      offsetX += spot.left
      parent.scrollLeft = offsetX
  parent.scrollTop = offsetY
  return

###*
# Helper function to start monitoring the scroll event and converting them into
# PDF.js friendly one: with scroll debounce and scroll direction.
###
watchScroll = (viewAreaElement, callback) ->

  debounceScroll = (evt) ->
    return if rAF
    # schedule an invocation of scroll for next animation frame.
    rAF = window.requestAnimationFrame -> # viewAreaElementScrolled
      rAF = null

      currentY = viewAreaElement.scrollTop
      lastY = state.lastY

      if currentY > lastY
        state.down = true
      else if currentY < lastY
        state.down = false
      state.lastY = currentY
      # else do nothing and use previous value
      callback state
      return
    return

  state =
    down: true
    lastY: viewAreaElement.scrollTop
    _eventHandler: debounceScroll

  rAF = null

  viewAreaElement.addEventListener 'scroll', debounceScroll, true
  state

###*
# Generic helper to find out what elements are visible within a scroll pane.
###
getVisibleElements = (scrollEl, views, sortByVisibility) ->
  top = scrollEl.scrollTop
  bottom = top + scrollEl.clientHeight
  left = scrollEl.scrollLeft
  right = left + scrollEl.clientWidth

  visible = []
  view = undefined

  currentHeight = undefined
  viewHeight = undefined
  hiddenHeight = undefined
  percentHeight = undefined
  currentWidth = undefined
  viewWidth = undefined

  for view in views

    currentHeight = view.el.offsetTop + view.el.clientTop
    viewHeight = view.el.clientHeight

    continue if currentHeight + viewHeight < top
    break if currentHeight > bottom

    currentWidth = view.el.offsetLeft + view.el.clientLeft
    viewWidth = view.el.clientWidth

    continue if currentWidth + viewWidth < left or currentWidth > right

    hiddenHeight = Math.max(0, top - currentHeight) + Math.max(0, currentHeight + viewHeight - bottom)
    percentHeight = (viewHeight - hiddenHeight) * 100 / viewHeight | 0

    visible.push
      id: view.id
      x: currentWidth
      y: currentHeight
      view: view
      percent: percentHeight

  first = visible[0]
  last = visible[visible.length - 1]
  if sortByVisibility
    visible.sort (a, b) ->
      pc = a.percent - b.percent
      return -pc if Math.abs(pc) > 0.001
      a.id - b.id  # ensure stability

  first: first
  last: last
  views: visible

###*
# Event handler to suppress context menu.
###
noContextMenuHandler = (e) ->
  e.preventDefault()
  return

###*
# Returns the filename or guessed filename from the url (see issue 3455).
# url {String} The original PDF location.
# @return {String} Guessed PDF file name.
###
getPDFFileNameFromURL = (url) ->
  reURI = /^(?:([^:]+:)?\/\/[^\/]+)?([^?#]*)(\?[^#]*)?(#.*)?$/
  #            SCHEME      HOST         1.PATH  2.QUERY   3.REF
  # Pattern to get last matching NAME.pdf
  reFilename = /[^\/?#=]+\.pdf\b(?!.*\.pdf\b)/i
  splitURI = reURI.exec url
  suggestedFilename = reFilename.exec(splitURI[1]) or reFilename.exec(splitURI[2]) or reFilename.exec(splitURI[3])
  if suggestedFilename
    suggestedFilename = suggestedFilename[0]
    if suggestedFilename.indexOf('%') != -1
      # URL-encoded %2Fpath%2Fto%2Ffile.pdf should be file.pdf
      try
        suggestedFilename = reFilename.exec(decodeURIComponent(suggestedFilename))[0]
      catch e
      # Possible (extremely rare) errors:
      # URIError "Malformed URI", e.g. for "%AA.pdf"
      # TypeError "null has no properties", e.g. for "%2F.pdf"
  suggestedFilename or 'document.pdf'

isAllWhitespace = (str) -> !NonWhitespaceRegexp.test str
