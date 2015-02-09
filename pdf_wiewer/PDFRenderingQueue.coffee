###*
# Controls rendering of the views for pages and thumbnails.
# @class
###
PDFRenderingQueue = do -> # PDFRenderingQueueClosure
  class PDFRenderingQueue
    ###*
    # @constructs
    ###
    constructor: ->
      @pdfViewer = null
      @pdfThumbnailViewer = null
      @onIdle = null

      @highestPriorityPage = null
      @idleTimeout = null
      @printing = false
      @isThumbnailViewEnabled = false

      @

    @::setViewer: (pdfViewer) ->
      @pdfViewer = pdfViewer
      return

    @::setThumbnailViewer: (pdfThumbnailViewer) ->
      @pdfThumbnailViewer = pdfThumbnailViewer
      return

    @::isHighestPriority: (view) ->
      @highestPriorityPage is view.renderingId

    @::renderHighestPriority: (currentlyVisiblePages) ->
      if @idleTimeout
        clearTimeout @idleTimeout
        @idleTimeout = null
      # Pages have a higher priority than thumbnails, so check them first.
      if @pdfViewer.forceRendering(currentlyVisiblePages)
        return
      # No pages needed rendering so check thumbnails.
      if @pdfThumbnailViewer and @isThumbnailViewEnabled
        if @pdfThumbnailViewer.forceRendering()
          return
      if @printing
        # If printing is currently ongoing do not reschedule cleanup.
        return
      if @onIdle
        @idleTimeout = setTimeout(@onIdle.bind(this), CLEANUP_TIMEOUT)
      return

    @::getHighestPriority: (visible, views, scrolledDown) ->
      # The state has changed figure out which page has the highest priority to
      # render next (if any).
      # Priority:
      # 1 visible pages
      # 2 if last scrolled down page after the visible pages
      # 2 if last scrolled up page before the visible pages
      visibleViews = visible.views
      numVisible = visibleViews.length
      if numVisible == 0
        return false
      i = 0
      while i < numVisible
        view = visibleViews[i].view
        if !@isViewFinished(view)
          return view
        ++i
      # All the visible views have rendered, try to render next/previous pages.
      if scrolledDown
        nextPageIndex = visible.last.id
        # ID's start at 1 so no need to add 1.
        if views[nextPageIndex] and !@isViewFinished(views[nextPageIndex])
          return views[nextPageIndex]
      else
        previousPageIndex = visible.first.id - 2
        if views[previousPageIndex] and !@isViewFinished(views[previousPageIndex])
          return views[previousPageIndex]
      # Everything that needs to be rendered has been.
      null

    @::isViewFinished: (view) ->
      view.renderingState is RenderingStates.FINISHED

    @::renderView: (view) ->
      state = view.renderingState
      switch state
        when RenderingStates.FINISHED then return false
        when RenderingStates.PAUSED
          @highestPriorityPage = view.renderingId
          view.resume()
        when RenderingStates.RUNNING
          @highestPriorityPage = view.renderingId
        when RenderingStates.INITIAL
          @highestPriorityPage = view.renderingId
          continueRendering = (
            ->
              @renderHighestPriority()
              return
          ).bind @
          view.draw()
          .then continueRendering, continueRendering
      true

  PDFRenderingQueue
