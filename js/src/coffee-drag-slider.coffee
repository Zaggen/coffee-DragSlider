window.sliders = {}
$ = window.jQuery

defaults =
  #viewportMaxWidth:  1000
  #viewportMaxHeight: 500
  slideShow:         false
  #stopOnHover:      yes # Not implemented yet
  cycle:           yes
  useNavigator:    yes
  addNavigator:     yes
  navigatorEvents:   no
  addBtns:    yes # Use false, when you want to manually add btns
  autoHideBtns:    yes # Not implemented yet
  duration:       1 # In seconds
  emmitEvents:  no
  draggable:  yes
  #preventLinksOnDrag:config.allowLinks ? yes

class Slider
  constructor:(slider)->
    #jQuery Objects
    @$el = $(slider)
    @$sliderViewport   = $(@$el.find('.sliderViewport'))
    @$sliderTrack           = $(@$sliderViewport.children('.sliderTrack'))
    @$sliderTrackItems      = $(@$sliderTrack.children('li'))
    @$sliderPrevBtn    = $(@$sliderViewport.children('.prevBtn'))
    @$sliderNextBtn    = $(@$sliderViewport.children('.nextBtn'))

    config = @$el.data('slider')
    @settings = $.extend({}, defaults, config)

    # In order to prevent any other link event handler to activate first we find the childrens and use those to
    # stop and Immediate Propagation of the event
    if @settings.preventLinksOnDrag
      @$sliderTrackLinks = @$sliderTrackItems.children().children()

    #Slider sizing variables and settings
    @_setSlider(true)
    @index = 0
    @slideToPos = 0
    @_draggedEl = null
    @hasLimitClass = false

    @slideTo(0)
    @setListeners()

  setListeners: ->
    @$sliderPrevBtn.click (e)=>
      e.stopPropagation()
      @slideTo('prev')

    @$sliderNextBtn.click (e)=>
      e.stopPropagation()
      @slideTo('next')

    if @settings.slideShow
      setInterval =>
        @slideTo('next')
      , 12000

    # Navigator Bullets

    @$navigator.on 'mousedown', 'li', (e)=>
      e.stopPropagation()
      index = $(e.currentTarget).index()
      @slideTo(index)

    # Drag
    if @settings.draggable
      @$sliderViewport.on 'mousedown', (e)=>
        e.stopPropagation()
        e.preventDefault()
        @_draggedEl = e.currentTarget
        @_dragStart(e.pageX)
        null

      @$sliderViewport.on 'touchstart', (e)=>
        e = e.originalEvent
        x = e.touches[0].pageX
        @_draggedEl = e.currentTarget
        @_dragStart(x, 'touchmove')
        null

      # Removes mousemove ev when the mouse is up anywhere in
      # the doc using the ev target stored in the mousedow ev
      # if @_dragStartX means the current object called by the handler
      # did not started the mousedown event so we skip it

      $(document).on 'mouseup',(e)=>
        e.stopPropagation()
        e.preventDefault()
        @_dragEnd(e.pageX)

      @$sliderViewport.on 'touchend',(e)=>
        #not working
        x = e.originalEvent.touches[0].pageX
        @_dragEnd(x)

    $( window ).resize =>
      #TODO: This seems like a bad idea, or at least an incomplete one
      setTimeout =>
        @_setSlider(false)
      , 1

  # Slider SetUp methods

  _setSlider: (initialSetUp)->
    @viewPortWidth = @$sliderViewport.width()
    @elementsQ = @$sliderTrackItems.length
    @sliderWidth = @elementsQ * 100
    @percentageStep = sliderTrackItemWidth = 100 / @elementsQ
    @rightLimit = (@viewPortWidth * @elementsQ) - @viewPortWidth #
    @$sliderTrackItems.css 'width', "#{sliderTrackItemWidth}%"

    @$sliderTrack.css
      'width': "#{@sliderWidth}%"
      'transition-duration': "#{@settings.duration}s"

    if initialSetUp
      @_sequentiallyLazyLoadResources()

      if @settings.addBtns
        @_addBtns()

      unless @settings.autoHideBtns and $(window).width() > 1024
        @$sliderPrevBtn.css('opacity', '1')
        @$sliderNextBtn.css('opacity', '1')

      unless @$navigator?
        if @settings.addNavigator
          @_buildNavigator()
        if @settings.useNavigator
          @$navigator = $(@$el.find('.navigator'))

  _buildNavigator: ->
    navigatorHtml = '<ul class="navigator">';
    navigatorHtml +=  '<li class="navBullet selectedBullet"></li>'; # First item, already selected
    navigatorHtml +=  '<li class="navBullet"></li>' for i in [1...@elementsQ]
    navigatorHtml += '</ul>'

    @$sliderViewport.append(navigatorHtml)

  _addBtns: ->
    btnsHtml  =  '<div class="sliderBtn prevBtn"><i class="fa fa-angle-left"></i></div>';
    btnsHtml +=  '<div class="sliderBtn nextBtn"><i class="fa fa-angle-right"></i></div>';
    @$sliderViewport.prepend(btnsHtml)
    @$sliderPrevBtn    = $(@$sliderViewport.children('.prevBtn'))
    @$sliderNextBtn    = $(@$sliderViewport.children('.nextBtn'))

  _addLoader: ($el)->
    loaderHtml = '<div class="progress"><div></div></div>'
    $el.append(loaderHtml)

  _removeLoader: ($el)->
    $el.find('.progress').remove()

  # Will lazy-load (sequentially) all the images with data-src attribute,
  # the ones that do not define this attribute will be loaded by the browser
  # in the default fashion. You can have the first one with out data-src and the
  # rest with it, so the first one loads as soon as possible, and the rest starts to
  # queue as soon as this code is run
  _sequentiallyLazyLoadResources: ->
    resourcesToLazyLoad = @$sliderTrack.find('[data-src]')
    @_lazyLoadResource(resourcesToLazyLoad, 0)

  _lazyLoadResource: (resources, index)->
    if index <= resources.length
      $resource = $(resources[index])
      src = $resource.data('src')
      $slide = $($resource.parent())

      $resource.one 'load', ()=>
        $resource.css('display', 'block')
        @_lazyLoadResource(resources, ++index)
        @_removeLoader($slide)

      @_addLoader($slide)
      $resource
      .attr('src', src)
      .css('display', 'none')

  #TODO: Check to see if using an image has performance
  _addLoader: ($el)->
    loaderHtml = '<div class="progress"><div></div></div>'
    $el.append(loaderHtml)

  _removeLoader: ($el)->
    $el.find('.progress').remove()

  # Behavior methods

  _dragStart: (startX, inputEvent = 'mousemove')->
    $el = $ @_draggedEl
    @_dragStartX = startX
    slideToPos = @$sliderTrack.position().left

    @$sliderTrack.css
      'transition-duration': '0s' # We are doing direct manipulation, no need for transitions here

    $el.on inputEvent, (ev)=>
      ev = ev.originalEvent
      x = if inputEvent is 'mousemove' then ev.pageX else ev.touches[0].pageX
      @_drag(startX, x, slideToPos)


  _drag: (startX, currentX, slideToPos) =>
    offsetX = startX - currentX # Difference between the new mouse x pos and the previus one
    slideToPos -= offsetX

    # Refactor below asap

    if slideToPos >= 0
      slideToPos = 0
      @isOutBounds = yes
      @_dragStartX = currentX

      unless @hasLimitClass
        @$sliderViewport.addClass('onLeftLimit')
        @hasLimitClass = yes

    else if slideToPos <= -@rightLimit
      slideToPos = -@rightLimit
      @isOutBounds = yes
      @_dragStartX = currentX

      unless @hasLimitClass
        @$sliderViewport.addClass('onRightLimit')
        @hasLimitClass = yes

    dragPos = (slideToPos / @viewPortWidth) * 100
    dragPos = dragPos * (@percentageStep / 100)

    @$sliderTrack.css('transform', "translate3d(#{dragPos}%, 0, 0)")
    @isOutBounds = no

    null

  _dragEnd: (currentX)->
    if @_draggedEl or @clicked #not working, always null :S
      #console.log 'drag end event fired for ' + slider
      console.log @_draggedEl
      if @hasLimitClass
        @$sliderViewport.removeClass('onLeftLimit onRightLimit')
        @hasLimitClass = no

      offsetX = @_dragStartX - currentX
      offsetPercentage = Math.abs (offsetX / @viewPortWidth)
      minToAction = 0.1 # The user must have dragged the sliderTrack at least 10% to move it
      if offsetPercentage < minToAction then offsetPercentage = 0

      if offsetX > 0 and not @isOutBounds

        ## Dragued-> right
        console.log "Dragued-> right"
        tempIndex = @index + Math.ceil(offsetPercentage)
      else if offsetX < 0 and not @isOutBounds

        ## Dragued-> left
        console.log "Dragued-> left"
        tempIndex = @index - Math.ceil(offsetPercentage)
      else

        ## Didn't move, or at least not much
        #console.log "Didn't move, or at least not much"
        tempIndex = @index

      @slideTo(tempIndex)

      # if it goes beyond a certain percentage we use slideTo to move
      # to the next slide or we use it to center up the current one
      $(@_draggedEl).off('mousemove')

      #if not @settings.preventLinksOnDrag
      @_draggedEl = null

      console.log @_draggedEl
      false

  ###
  # Moves the sliderTrack to the prev, next, or an specific position based on the command argument
  # @param {string}|{integer} command
  # @return {void}
  ###

  slideTo: (command)->
    @clicked = null
    switch command
      when 'next'
        @index++
      when 'prev'
        @index--
      when 'first'
        @index = 0
      when 'last'
        @index = @elementsQ - 1
      else
        if isFinite(command)
          @index = command
        else
          err = 'Please provide a valid command for the slider [prev,next or a valid index]'
          console.error err
          return false

    lastIndx = (@elementsQ - 1)
    if @index > lastIndx
      if @settings.cycle
        @index = 0
      else
        @index = lastIndx
        return false
    else if @index < 0
      if @settings.cycle
        @index = lastIndx
      else
        @index = 0
        return false

    slideToPos = -1 * (@index * @percentageStep)

    index = @index
    if @$navigator?
      @$navigator.each ->
        $childrens = $($(@).children())
        $childrens.removeClass('selected')
        $($childrens[index]).addClass('selected')

    @$sliderTrack.css
      'transform': "translate3d(#{slideToPos}%, 0, 0)"
      'transition-duration': "#{@settings.duration}s"

    if(@settings.emmitEvents)
      $.event.trigger('onSlide', [@index]);

$ ->
  window.sliders = []
  $('.slider').each ->
    sliders.push(new Slider(this))