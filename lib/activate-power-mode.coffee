throttle = require "lodash.throttle"
{CompositeDisposable} = require 'atom'

module.exports = ActivatePowerMode =
  activatePowerModeView: null
  modalPanel: null
  subscriptions: null

  activate: (state) ->
    @subscriptions = new CompositeDisposable

    @subscriptions.add atom.commands.add "atom-workspace",
      "activate-power-mode:toggle": => @toggle()

    @throttledShake = throttle @shake.bind(this), 100, trailing: false
    @throttledSpawnParticles = throttle @spawnParticles.bind(this), 25, trailing: false

    @editor = atom.workspace.getActiveTextEditor()
    @editorElement = atom.views.getView @editor
    @editorElement.classList.add "power-mode"

    @subscriptions.add @editor.getBuffer().onDidChange(@onChange.bind(this))
    @setupCanvas()

  setupCanvas: ->
    @canvas = document.createElement "canvas"
    @context = @canvas.getContext "2d"
    @canvas.classList.add "power-mode-canvas"
    @canvas.width = @editorElement.offsetWidth
    @canvas.height = @editorElement.offsetHeight
    @editorElement.parentNode.appendChild @canvas

  calculateCursorOffset: ->
    editorRect = @editorElement.getBoundingClientRect()
    scrollViewRect = @editorElement.shadowRoot.querySelector(".scroll-view").getBoundingClientRect()

    top: scrollViewRect.top - editorRect.top + @editor.getLineHeightInPixels() / 2
    left: scrollViewRect.left - editorRect.left

  onChange: (e) ->
    spawnParticles = true
    if e.newText
      spawnParticles = e.newText isnt "\n"
      range = e.newRange.end
    else
      range = e.newRange.start

    @throttledSpawnParticles(range) if spawnParticles
    @throttledShake()

  shake: ->
    intensity = 0
    x = intensity * (if Math.random() > 0.5 then -1 else 1)
    y = intensity * (if Math.random() > 0.5 then -1 else 1)

    @editorElement.style.top = "#{y}px"
    @editorElement.style.left = "#{x}px"

    setTimeout =>
      @editorElement.style.top = ""
      @editorElement.style.left = ""
    , 75

  spawnParticles: (range) ->
    cursorOffset = @calculateCursorOffset()

    {left, top} = @editor.pixelPositionForScreenPosition range
    left += cursorOffset.left - @editor.getScrollLeft()
    top += cursorOffset.top - @editor.getScrollTop()

    color = @getColorAtPosition left, top
    numParticles = 5 + Math.round(Math.random() * 10)
    while numParticles--
      part =  @createParticle left, top, color
      @particles[@particlePointer] = part
      @particlePointer = (@particlePointer + 1) % 500

  _randomNum: (max,min=0) ->
	   return Math.floor(Math.random() * (max - min) + min)
	# min is set to 0 by default but a different value can be passed to function

  getColorAtPosition: (left, top) ->
    offset = @editorElement.getBoundingClientRect()
    el = atom.views.getView(@editor).shadowRoot.elementFromPoint(
      left + offset.left
      top + offset.top
    )

    if el
      r = @_randomNum(255)
      g = @_randomNum(255)
      b = @_randomNum(255)
      "rgb( #{r},#{g},#{b})"
    else
      r = @_randomNum(255)
      g = @_randomNum(255)
      b = @_randomNum(255)
      "rgb( #{r},#{g},#{b})"

  createParticle: (x, y, color) ->
    x: x
    y: y
    alpha: 1
    color: color
    velocity:
      x: -1 + Math.random() * 2
      y: -3.5 + Math.random() * 2

  drawParticles: ->
    requestAnimationFrame @drawParticles.bind(this)
    @context.clearRect 0, 0, @canvas.width, @canvas.height

    for particle in @particles
      continue if particle.alpha <= 0.1

      particle.velocity.y += 0.075
      particle.x += particle.velocity.x
      particle.y += particle.velocity.y
      particle.alpha *= 0.96

      @context.fillStyle = "rgba(#{particle.color[4...-1]}, #{particle.alpha})"
      @context.fillRect(
        Math.round(particle.x - 1.5)
        Math.round(particle.y - 1.5)
        3, 3
      )

  toggle: ->
    console.log 'ActivatePowerMode was toggled!'
    @particlePointer = 0
    @particles = []
    requestAnimationFrame @drawParticles.bind(this)
