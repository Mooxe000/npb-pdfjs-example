ProgressBar = do -> # ProgressBarClosure
  class ProgressBar
    constructor: (id, opts) ->
      @visible = true

      # Fetch the sub-elements for later.
      @div = document.querySelector(
        id + ' .progress'
      )

      # Get the loading bar element, so it can be resized to fit the viewer.
      @bar = @div.parentNode

      # Get options, with sensible defaults.
      @height = opts.height or 100
      @width = opts.width or 100
      @units = opts.units or '%'

      # Initialize heights.
      @div.style.height = @height + @units
      @percent = 0

      @

    clamp = (v, min, max) ->
      Math.min Math.max(
        v, min
      ), max

    get_percent = -> this._percent;
    set_percent = -> (val) ->
      @._indeterminate = isNaN val
      @._percent = clamp val, 0, 100
      @.updateBar();

    @::updateBar = -> # ProgressBar_updateBar
      if @_indeterminate
        @div.classList.add 'indeterminate'
        @div.style.width = @width + @units
        return

      @div.classList.remove 'indeterminate'
      progressSize = @width * @_percent / 100
      @div.style.width = progressSize + @units
      return

    @::setWidth: (viewer) ->
      if viewer
        container = viewer.parentNode
        scrollbarWidth = container.offsetWidth - viewer.offsetWidth
        if scrollbarWidth > 0
          @bar.setAttribute 'style', 'width: calc(100% - ' + scrollbarWidth + 'px);'
      return

    @::hide = ->
      return if !@visible
      @visible = false
      @bar.classList.add 'hidden'
      document.body.classList.remove 'loadingInProgress'
      return

    @::show = ->
      return if @visible
      @visible = true
      document.body.classList.add 'loadingInProgress'
      @bar.classList.remove 'hidden'
      return

  ProgressBar
