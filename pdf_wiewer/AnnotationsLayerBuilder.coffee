###*
# @typedef {Object} AnnotationsLayerBuilderOptions
# @property {HTMLDivElement} pageDiv
# @property {PDFPage} pdfPage
# @property {IPDFLinkService} linkService
###

class AnnotationsLayerBuilder

  ###*
  # @param {AnnotationsLayerBuilderOptions} options
  # @constructs AnnotationsLayerBuilder
  ###
  constructor: (options) ->
    @pageDiv = options.pageDiv
    @pdfPage = options.pdfPage
    @linkService = options.linkService
    @div = null
    @

  @::setupAnnotations: (viewport) ->
    linkService = @linkService
    pdfPage = @pdfPage
    self = this

    bindLink = (link, dest) ->
      link.href = linkService.getDestinationHash(dest)

      link.onclick = ->
        if dest
          linkService.navigateTo dest
        false

      if dest
        link.className = 'internalLink'
      return

    bindNamedAction = (link, action) ->
      link.href = linkService.getAnchorUrl('')

      link.onclick = ->
        linkService.executeNamedAction action
        false

      link.className = 'internalLink'
      return

    pdfPage.getAnnotations()
    .then (annotationsData) ->
      viewport = viewport.clone dontFlip: true
      transform = viewport.transform
      transformStr = 'matrix(' + transform.join(',') + ')'

      data = undefined
      element = undefined
      i = undefined
      ii = undefined

      if self.div
        # If an annotationLayer already exists, refresh its children's
        # transformation matrices
        i = 0
        ii = annotationsData.length
        while i < ii
          data = annotationsData[i]
          element = self.div.querySelector('[data-annotation-id="' + data.id + '"]')
          if element
            CustomStyle.setProp 'transform', element, transformStr
          i++

        # See PDFPageView.reset()
        self.div.removeAttribute 'hidden'

      else
        i = 0
        ii = annotationsData.length
        while i < ii
          data = annotationsData[i]
          if !data or !data.hasHtml
            i++
          continue

          element = PDFJS.AnnotationUtils.getHtmlElement data, pdfPage.commonObjs
          element.setAttribute 'data-annotation-id', data.id
          mozL10n.translate element if typeof mozL10n != 'undefined'

          rect = data.rect
          view = pdfPage.view
          rect = PDFJS.Util.normalizeRect [
            rect[0]
            view[3] - rect[1] + view[1]
            rect[2]
            view[3] - rect[3] + view[1]
          ]

          element.style.left = rect[0] + 'px'
          element.style.top = rect[1] + 'px'
          element.style.position = 'absolute'

          CustomStyle.setProp 'transform', element, transformStr
          transformOriginStr = -rect[0] + 'px ' + -rect[1] + 'px'
          CustomStyle.setProp 'transformOrigin', element, transformOriginStr

          if data.subtype == 'Link' and !data.url
            link = element.getElementsByTagName('a')[0]
            if link
              if data.action
                bindNamedAction link, data.action
              else
                bindLink link, if 'dest' in data then data.dest else null

          if !self.div
            annotationLayerDiv = document.createElement('div')
            annotationLayerDiv.className = 'annotationLayer'
            self.pageDiv.appendChild annotationLayerDiv
            self.div = annotationLayerDiv
          self.div.appendChild element

          i++

      return

    return

    @::hide: ->
      return if !@div
      @div.setAttribute 'hidden', 'true'
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
