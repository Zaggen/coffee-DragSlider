root = window ? global # no need for node.js global in a slider but w/e
root.sliders = {}
$ = root.jQuery

class Slider
  constructor:(@sliderId, config = {})->
    $ = window.jQuery

    @settings =
      viewportMaxWidth:  config.viewportMaxWidth ? 1000
      viewportMaxHeight: config.viewportMaxHeight ? 500
      slideShow:         config.slideShow ? yes
      stopOnHover:       config.stopOnHover ? yes
      cycle:             config.cycle ? yes
      navigator:         config.navigator ? no
      navigatorEvents:   config.navigatorEvents ? no
      autoHideBtns:      config.autoHideBtns ? yes # Not implemented yet
      duration:          config.duration ? 1 # In seconds
      emmitEvents:       config.emmitEvents ? no
      draggable:         config.draggable ? yes
      preventLinksOnDrag:config.allowLinks ? yes

    #jQuery Objects
    @$sliderViewport   = $('#' + sliderId)
    @$slider           = $ @$sliderViewport.children('.slider')
    @$sliderItems      = $ @$slider.children('li')
    @$sliderPrevBtn    = $ @$sliderViewport.children('.prevBtn')
    @$sliderNextBtn    = $ @$sliderViewport.children('.nextBtn')

    # In order to prevent any other link event handler to activate first we find the childrens and use those to
    # stop and Immediate Propagation of the event
    if @settings.preventLinksOnDrag
      @$sliderLinks = @$sliderItems.children().children()

    if config.navigatorInParent?
      @$sliderNavBtns    = $ @$sliderViewport.parent().find('.navigator a')
    else
      @$sliderNavBtns    = $ @$sliderViewport.children('.navigator').children()


    #Slider sizing variables and settings
    @getBrowserPrefix()
    @transitionProperty = "#{@cssPrefix}-transition-duration"
    @setSlider()

    @index = 0
    @slideToPos = 0
    @draggedEl = null
    @hasLimitClass = false


    ## Listeners

    @$sliderPrevBtn.click (e)=>
      e.stopPropagation()
      @slideTo('prev')

    @$sliderNextBtn.click (e)=>
      e.stopPropagation()
      @slideTo('next')

    # Navigator Bullets

    @$sliderNavBtns.mousedown (e)=>
      e.stopPropagation()
      index = $(e.currentTarget).index()
      @slideTo(index)

    # Drag
    if @settings.draggable
      @$sliderViewport.mousedown (e)=>
        e.stopPropagation()
        e.preventDefault()
        @dragStart(e)
        null

      # Removes mousemove ev when the mouse is up anywhere in
      # the doc using the ev target stored in the mousedow ev
      # if @dragStartX means the current object called by the handler
      # did not started the mousedown event so we skip it

      $(document).mouseup (e)=>
        e.stopPropagation()
        e.preventDefault()
        @dragEnd(e)

    $( window ).resize =>
      @setSlider()

  ###
  Not Working yet :S
  if @settings.preventLinksOnDrag

    @$sliderLinks.click (e)=>
      e.stopImmediatePropagation()
      e.preventDefault()
      if @draggedEl
        alert 'yep it was dragged'
        @draggedEl = null
        console.log '@draggedEl is ' + @draggedEl
      else
        alert 'nopes'
  ###

  addNavigator: ->
    navigatorHtml = '<ul class="navigator">';
    navigatorHtml += '<li class="navBullet selectedBullet"></li>'; # First item, already selected
    navigatorHtml += '<li class="navBullet"></li>' for i in [1...@elementsQ]
    navigatorHtml += '</ul>'
    @$sliderViewport.append(navigatorHtml)

    if @settings.navigatorInParent
      @$sliderNavBtns    = $ @$sliderViewport.parent().find('.navigator a')
    else
      @$sliderNavBtns    = $ @$sliderViewport.children('.navigator').children()


  setSlider: ->
    @viewPortWidth = @$sliderViewport.width()
    @elementsQ = @$sliderItems.length
    @sliderWidth = @elementsQ * 100
    sliderItemWidth = 100 / @elementsQ
    @rightLimit = (@viewPortWidth * @elementsQ) - @viewPortWidth #
    @$sliderItems.css 'width', "#{sliderItemWidth}%"

    @$slider.css('width', "#{@sliderWidth}%")
    @$slider.css("#{@transitionProperty}", "#{@settings.duration}s")



    @addNavigator()

  dragStart: (e)->
    $el = $ e.currentTarget
    @dragStartX = e.pageX
    startX = e.pageX
    @draggedEl = e.currentTarget
    @slideToPos = @$slider.position().left

    @$slider.css(@transitionProperty, '0s') # We are doing direct manipulation, no need for transitions here

    dragPos = (@slideToPos / @viewPortWidth) * 100

    @$slider.css('left', dragPos + '%')

    $el.on 'mousemove', (ev)=>

      offsetX = startX - ev.pageX # Difference between the new mouse x pos and the previus one

      startX = ev.pageX

      @slideToPos -= offsetX

      # Refactor below asap

      if @slideToPos >= 0
        @slideToPos = 0
        @isOutBounds = yes
        @dragStartX = startX
        unless @hasLimitClass
          @$sliderViewport.addClass('onLeftLimit')
          @hasLimitClass = yes

      else if @slideToPos <= -@rightLimit
        @slideToPos = -@rightLimit
        @isOutBounds = yes
        @dragStartX = startX
        unless @hasLimitClass
          @$sliderViewport.addClass('onRightLimit')
          @hasLimitClass = yes

      dragPos = (@slideToPos / @viewPortWidth) * 100

      #@$slider.css('left', @slideToPos + 'px') Deprecated px drag
      @$slider.css('left', dragPos + '%')
      @isOutBounds = no
      ###
      We should use a better way to move the elements around, using forced gpu calcs
      @$slider.css({
        '-webkit-transform': "translate3d(#{@slideToPos}%, 0px, 0px) perspective(2000px)"
      })
      ###
      null

  dragEnd: (e)->
    if @draggedEl or @clicked #not working, always null :S
      console.log 'drag end event fired for ' + @sliderId
      console.log @draggedEl
      if @hasLimitClass
        @$sliderViewport.removeClass('onLeftLimit onRightLimit')
        @hasLimitClass = no

      offsetX = @dragStartX - e.pageX
      offsetPercentage = Math.abs (offsetX / @viewPortWidth)
      minToAction = 0.1 # The user must have dragged the slider at least 10% to move it
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
        console.log "Didn't move, or at least not much"
        tempIndex = @index

      console.log "tempIndex:" + tempIndex
      @slideTo(tempIndex)

      # if it goes beyond a certain percentage we use slideTo to move
      # to the next slide or we use it to center up the current one
      $(@draggedEl).off('mousemove')

      #if not @settings.preventLinksOnDrag
      @draggedEl = null

      console.log @draggedEl
      false

  ###
  # Moves the slider to the prev, next, or an specific position based on the command argument
  # @param {string}|{integer} command
  # @return {void}
  ###

  slideTo: (command)->
    @clicked = null
    console.log 'slideTo Called with argument:' + command
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

    console.log 'index:' + @index
    @slideToPos = -1 * (@index * 100)
    if(@settings.navigator)
      @$sliderNavBtns.removeClass 'selectedBullet'
      $(@$sliderNavBtns[@index]).addClass 'selectedBullet'

    #@$slider.stop().animate({'left': @slideToPos + '%'}, @settings.duration)
    @$slider.css('left', "#{@slideToPos}%")
    @$slider.css("#{@transitionProperty}", "#{@settings.duration}s")

    if(@settings.emmitEvents)
      $.event.trigger('onSlide', [@index, @sliderId]);

  getBrowserPrefix: ->

    #Based on the browserprefix function found in http://css-tricks.com/controlling-css-animations-transitions-javascript/
    @cssPrefix = 'webkit'
    ###N = navigator.appName
    ua = navigator.userAgent
    M = ua.match(/(opera|chrome|safari|firefox|msie)\/?\s*(\.?\d+(\.\d+)*)/i)

    if(M && (tem = ua.match(/version\/([\.\d]+)/i))!= null)
      M[2] = tem[1]
    M = if M [M[1], M[2]] then [N, navigator.appVersion,'-?']
    M = M[0]

    if(M is "Chrome") then browserPrefix = 'webkit'
    if(M is "Firefox") then browserPrefix = 'moz'
    if(M is "Safari") then browserPrefix = 'webkit'
    if(M is "MSIE") then browserPrefix = 'ms'###

    return @cssPrefix


###
@$slider.stop().css({
  '-webkit-transform': "translate3d(#{@slideToPos}%, 0px, 0px) perspective(2000px)"
})
###

$ ->
  sliders.main = new Slider 'mainSlider',
    autoHideBtns: yes
    emmitEvents: yes
    navigator: yes

