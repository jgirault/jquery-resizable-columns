(($, window) ->

  # Removes 'px' from the width
  stripPx = (width) ->
    if !width
      return 0
    else
      return if typeof width == 'string' then width.replace('px', '') else width

  # Gets the width of a node
  _parseWidth = (_usePixels, node) ->
    parseFloat(node.style.width.replace((if _usePixels then 'px' else '%'), ''))

  # Sets the width of a node in percentages
  _setWidth = (_usePixels, node, width) ->
    if _usePixels
      width = width.toFixed(2)
      $(node).children().width(width)
      width = "#{width}px"
      node.style.minWidth = width
      node.style.width = width
      node.style.maxWidth = width
    else
      width = width.toFixed(2)
      width = "#{width}%"
      node.style.width = width
    return width

  pointerX = (e) ->
    if e.type.indexOf('touch') == 0
      return (e.originalEvent.touches[0] || e.originalEvent.changedTouches[0]).pageX

    e.pageX

  ##
  # Define the plugin class
  ##
  class ResizableColumns

    defaults:
      usePixels: false # Use pixels or percentages
      selector: 'tr th:visible' # determine columns using visible table headers
      store: window.store
      syncHandlers: true # immediately synchronize handlers with column widths
      resizeFromBody: true # allows for resizing of columns from within tbody

      maxWidth: null # Maximum `percentage` width to allow for any column
      minWidth: null # Minimum `percentage` width to allow for any column

    constructor: ($table, options) ->
      @options = $.extend({}, @defaults, options)
      @$table = $table

      usePixels = @options.usePixels
      @parseWidth = (node) ->
        return _parseWidth usePixels, node


      @setWidth = (node, width) ->
        return _setWidth usePixels, node, width

      @setHeaders()
      if @options.store?
        @restoreColumnWidths()
      @syncHandleWidths()

      $(window).on 'resize.rc', ( => @syncHandleWidths() )

      # Bind event callbacks
      if @options.start
        @$table.bind('column:resize:start.rc', @options.start)
      if @options.resize
        @$table.bind('column:resize.rc', @options.resize)
      if @options.stop
        @$table.bind('column:resize:stop.rc', @options.stop)
      if @options.restore
        @$table.bind('column:resize:restore.rc', @options.restore)

    triggerEvent: (type, args, original) ->
      event = $.Event type
      event.originalEvent = $.extend {}, original
      @$table.trigger event, [this].concat(args || [])

    getColumnId: ($el) ->
      @$table.data('resizable-columns-id') + '-' + $el.data('resizable-column-id')

    setHeaders: ->
      @$tableHeaders = @$table.find(@options.selector)
      if @options.usePixels
        @assignPixelWidths()
      else
        @assignPercentageWidths()
      @createHandles()

    destroy: ->
      @$handleContainer.remove()
      @$table.removeData('resizableColumns')
      @$table.add(window).off '.rc'

    assignPercentageWidths: ->
      @$tableHeaders.each (_, el) =>
        $el = $(el)
        @setWidth $el[0], ($el.outerWidth() / @$table.width() * 100)

    # Gets and sets the width of the table header column
    assignPixelWidths: ->
      @$tableHeaders.each (_, el) =>
        $el = $(el)
        @setWidth $el[0], ($el.outerWidth() - stripPx $el.css('paddingLeft') - stripPx $el.css('paddingRight') )

    createHandles: ->
      @$handleContainer?.remove()
      @$table.before (@$handleContainer = $("<div class='rc-handle-container' />"))
      @$tableHeaders.each (i, el) =>
        return if @$tableHeaders.eq(i + 1).length == 0 ||
                  @$tableHeaders.eq(i).attr('data-noresize')? ||
                  @$tableHeaders.eq(i + 1).attr('data-noresize')?

        $handle = $("<div class='rc-handle' />")
        $handle.data('th', $(el))
        $handle.appendTo(@$handleContainer)

      @$handleContainer.on 'mousedown touchstart', '.rc-handle', @pointerdown

    syncHandleWidths: ->
      if @options.usePixels
        return @syncHandleWidthsPx()

      @$handleContainer.width(@$table.width()).find('.rc-handle').each (_, el) =>
        $el = $(el)
        $el.css
          left: $el.data('th').outerWidth() + ($el.data('th').offset().left - @$handleContainer.offset().left)
          height: if @options.resizeFromBody then @$table.height() else @$table.find('thead').height()

    saveColumnWidths: ->
      columns = []
      @$tableHeaders.each (_, el) =>
        $el = $(el)
        unless $el.attr('data-noresize')?
          width = @parseWidth $el[0]
          columns.push width
          if @options.store?
            @options.store.set @getColumnId($el), width
      @$table.trigger('column:resize:save', [columns]);

    restoreColumnWidths: ->
      @$tableHeaders.each (_, el) =>
        $el = $(el)
        if @options.store? && (width = @options.store.get(@getColumnId($el)))
          @setWidth $el[0], width

    totalColumnWidths: ->
      if @options.usePixels
        return @totalColumnWidthsPx()
      total = 0

      @$tableHeaders.each (_, el) =>
        total += parseFloat($(el)[0].style.width.replace('%', ''))

      total

    # Synchronises the handles widths and the table width with the table headers
    syncHandleWidthsPx: ->
      @$handleContainer.css('minWidth', @totalColumnWidthsPx()).find('.rc-handle').each (_, el) =>
        $el = $(el)
        left = $el.data('th').outerWidth()
        left -= stripPx $el.css('paddingLeft')
        left -= stripPx $el.css('paddingRight')
        left += $el.data('th').offset().left
        left -= @$handleContainer.offset().left
        height = if @options.resizeFromBody then @$table.height() else @$table.find('thead').height()
        $el.css
          left: left
          height: height
#      @$table.css('minWidth', @$handleContainer.width());

    # Calculates the table width based on the cell widths
    totalColumnWidthsPx: ->
      total = 0

      @$table.each (_, el) =>
        $el = $(el)
        total += parseFloat(stripPx $el[0].style.width || $el.width())
        total += parseFloat(stripPx $el.css('paddingLeft'))
        total += parseFloat(stripPx $el.css('paddingRight'))

      total

    constrainWidth: (width) =>
      if @options.minWidth?
        width = Math.max(@options.minWidth, width)

      if @options.maxWidth?
        width = Math.min(@options.maxWidth, width)

      width

    pointerdown: (e) =>
      e.preventDefault()

      $ownerDocument = $(e.currentTarget.ownerDocument);
      startPosition = pointerX(e)
      $currentGrip = $(e.currentTarget)
      $leftColumn = $currentGrip.data('th')
      $rightColumn = @$tableHeaders.eq @$tableHeaders.index($leftColumn) + 1

      widths =
        left: @parseWidth $leftColumn[0]
        right: @parseWidth $rightColumn[0]
      newWidths = 
        left: widths.left
        right: widths.right
      
      @$handleContainer.add(@$table).addClass 'rc-table-resizing'
      $leftColumn.add($rightColumn).add($currentGrip).addClass 'rc-column-resizing'

      @triggerEvent 'column:resize:start', [ $leftColumn, $rightColumn, newWidths.left, newWidths.right  ], e

      # During mousemove readjust the columns
      $ownerDocument.on 'mousemove.rc touchmove.rc', (e) =>
        difference = pointerX(e) - startPosition
        if !@options.usePixels
          # needs to be converted to a percentage
          difference = difference / @$table.width() * 100

        if @options.usePixels
          @setWidth $leftColumn[0], @constrainWidth widths.left + difference
          # needs to reset the width to be sure it is the correct width
          @setWidth $leftColumn[0], newWidths.left = $leftColumn.outerWidth()
        else
          @setWidth $leftColumn[0], newWidths.left = @constrainWidth widths.left + difference
          @setWidth $rightColumn[0], newWidths.right = @constrainWidth widths.right - difference

        # No need to adjust the right column if we use pixels
        if @options.syncHandlers?
          @syncHandleWidths()
        @triggerEvent 'column:resize', [ $leftColumn, $rightColumn, newWidths.left, newWidths.right ], e

      # After mousemove clean up and save widths
      $ownerDocument.one 'mouseup touchend', =>
        $ownerDocument.off 'mousemove.rc touchmove.rc'
        @$handleContainer.add(@$table).removeClass 'rc-table-resizing' 
        $leftColumn.add($rightColumn).add($currentGrip).removeClass 'rc-column-resizing'
        @syncHandleWidths()
        @saveColumnWidths()
        @triggerEvent 'column:resize:stop', [ $leftColumn, $rightColumn, newWidths.left, newWidths.right ], e

  ##
  # Define the plugin
  ##
  $.fn.extend resizableColumns: (option, args...) ->
    @each ->
      $table = $(@)
      data = $table.data('resizableColumns')

      if !data
        $table.data 'resizableColumns', (data = new ResizableColumns($table, option))
      if typeof option == 'string'
        data[option].apply(data, args)

) window.jQuery, window
