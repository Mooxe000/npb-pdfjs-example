class SimpleLinkService
  constructor: (@pdfViewer) ->

  ###*
  * @returns {number}
  ###
  page = -> #get
    @pdfViewer.currentPageNumber

  page = (value) -> # set
    @.pdfViewer.currentPageNumber = value

  ###*
  * @param dest - The PDF destination object.
  ###
  navigateTo = (dest) ->

  ###*
  * @param dest - The PDF destination object.
  * @returns {string} The hyperlink to the PDF object.
  ###
  getDestinationHash = (dest) -> '#'

  ###*
  * @param hash - The PDF parameters/hash.
  * @returns {string} The hyperlink to the PDF object.
  ###
  getAnchorUrl = (hash) -> '#'

  ###*
  * @param {string} hash
  ###
  setHash = (hash) ->

  ###*
  * @param {string} action
  ###
  executeNamedAction = (action) ->
