
# functions that override property gets and sets with function calls

Function::getter = (prop, get) ->
	Object.defineProperty @prototype, prop, {get, configurable: yes}
Function::setter = (prop, set) ->
	Object.defineProperty @prototype, prop, {set, configurable: yes}	
Function::classGetter = (prop, get) ->
	Object.defineProperty @, prop, {get, configurable: yes}
Function::classSetter = (prop, set) ->
	Object.defineProperty @, prop, {set, configurable: yes}	

# stub so all of kenta cho's games work
class RealtimeLeaderboard
	@initialize: ->
	@beginGame: ->
	@setScore: ->
	@setTmpScore: ->

# game state and utility functions
class Game
	# public functions
	@end: -> @e
	@classGetter 'e', ->
		return false if !@ib
		window.endGame?()
		@beginTitle()
		true
	@drawText: (args...) -> Display.drawText args...
	@dt: (args...) -> Display.drawText args...
	@fillRect: (args...) -> Display.fillRect args...
	@fr: (args...) -> Display.fillRect args...
	@getDifficulty: (args...) -> @df args...
	@df: (speed = 1, scale = 1) -> sqrt(@ticks * speed * 0.0001) * scale + 1
	@newDrawing: -> @nd
	@classGetter 'nd', -> new Drawing
	@newFiber: -> @nf
	@classGetter 'nf', ->
		f = new Fiber
		@fibers.push f
		f
	@newParticle: -> @np
	@classGetter 'np', -> new Particle
	@newRandom: -> @nr
	@classGetter 'nr', -> new Random
	@newSound: -> @ns
	@classGetter 'ns', -> new Sound
	@newText: (args...) -> @nt args...
	@nt: (text) -> new Text text
	@newVector: -> @nv
	@classGetter 'nv', -> new Vector
	@classGetter 't', -> @ticks
	@classGetter 'sc', -> @score
	@classSetter 'sc', (v) -> @score = v
	@classGetter 'isBeginning', -> @running
	@classGetter 'ib', -> @running
	@classGetter 'r', -> @random

	# private functions
	@initialize: ->
		@ticks = 0
		@score = 0
		@running = false
		@random = new Random
		@INTERVAL = 1000 / Config.fps
		@delta = 0
		@currentTime = @prevTime = 0
		@isPaused = false
		Display.initialize()
		Key.initialize()
		Mouse.initialize()
		Sound.initialize()
		window.onblur = (e) =>
			@isPaused = true
			Display.clear()
			Display.drawText 'PAUSED', 0.5, 0.5, 0, 0
		window.onfocus = (e) =>
			@onfocus()
		ca = Config.captureArgs
		Display.beginCapture.apply Display, ca if ca?
		window.initialize?()
		if Config.isDebuggingMode
			@beginGame()
			@lastFrameTime = new Date().getTime()
			@fps = @fpsCount = 0
		else
			@initializeGame()
			@beginTitle()
		requestAnimFrame @updateFrame
	@onfocus: ->
		return if !@isPaused
		@isPaused = false
		@postUpdate()
	@beginTitle: ->
		@running = false
		ty = if Config.title.length == 1 then .4 else .35
		new Text(Config.title[0]).xy(.5, ty).sc(3).df
		if Config.title.length > 1
			new Text(Config.title[1]).xy(.5, .45).sc(3).df
		new Text('[ CLICK / TOUCH ] TO START').xy(.5, .6).df
		Mouse.setPressedDisabledCount 10
	@beginGame: ->
		@running = true
		@score = 0
		window.beginGame?()
		@initializeGame()
	@initializeGame: ->
		Actor.clear()
		Sound.reset()
		@fibers = []
		@ticks = 0
		window.begin?()
	@preUpdate: (time) ->
		if time?
			@currentTime = time
		else
			@currentTime = new Date().getTime()
		@delta += (@currentTime - @prevTime) / @INTERVAL
		@prevTime = @currentTime
		return true if @delta >= 0.75
		requestAnimFrame @updateFrame
		false
	@updateFrame: (time) =>
		return if @isPaused
		return if !(@preUpdate time)
		Display.preUpdate()
		Mouse.update()
		window.update?()
		Actor.update()
		Sound.update()
		i = 0
		while true
			break if i >= @fibers.length
			f = @fibers[i]
			f.update() if !f.removing
			if f.removing
				@fibers.splice i, 1
			else
				i++
		Display.drawText "#{@score}", 1, 0, 1
		@postUpdate()
		@ticks++
		@updateTitle() if !@running
		if Config.isDebuggingMode
			@calcFps()
			Display.drawText "FPS:#{@fps}", 0, 0.97
			Display.drawText "ACTOR#:#{Actor.number}", 0.2, 0.97
	@postUpdate: ->
		@delta = 0
		requestAnimFrame @updateFrame
	@updateTitle: ->
		@beginGame() if Mouse.ipd
	@calcFps: ->
		@fpsCount++
		currentTime = new Date().getTime()
		delta = currentTime - @lastFrameTime
		if delta >= 1000
			@fps = floor @fpsCount * 1000 / delta
			@lastFrameTime = currentTime
			@fpsCount = 0

requestAnimFrameSystem =
	window.requestAnimationFrame	   ||
	window.webkitRequestAnimationFrame ||
	window.mozRequestAnimationFrame	   ||
	window.oRequestAnimationFrame	   ||
	window.msRequestAnimationFrame	   ||
	(callback) ->
		window.setTimeout callback, Game.INTERVAL / 2

requestAnimFrame = (callback) ->
	requestAnimFrameSystem ->
		try
			callback()
		catch e
			if ErrorReporter?
				ErrorReporter.handleError e
			else
				console.log(e)

class Display
	@initialize: ->
		@element = $('#display')[0]
		Letter.initialize()
		@size = new Vector
		@setSize()
		window.onresize = =>
			clearTimeout @resizeTimer if @resizeTimer?
			@resizeTimer = setTimeout @setSize, 200
	@setSize: =>
		cw = $('#displayDiv')[0].clientWidth
		@element.width = @element.height = cw
		@size.xy cw, cw
		@context = @element.getContext '2d'
		Letter.setSize @size
	@clear: ->
		@context.fillStyle = Config.backgroundColor
		@context.fillRect 0, 0, @size.x, @size.y
	@drawText: (text, x, y, alignX = -1, alignY = -1,
				color = Color.white, scale = 1) ->
		Letter.draw text, x, y, alignX, alignY, color, scale
	@fillRect: (x, y, width, height, color = Color.white) ->
		return if color.rv < 0
		@context.fillStyle = color.toString()
		@context.fillRect floor((x - width / 2) * @size.x),
			floor((y - height / 2)* @size.y),
			floor(width * @size.x),
			floor(height * @size.y)
	@fillRectDirect: (x, y, width, height, color = Color.white) ->
		return if color.rv < 0
		@context.fillStyle = color.toString()
		@context.fillRect x, y, width, height
	@beginCapture: (scale = 1, durationSec = 3, intervalSec = 0.05) ->
		@captureDuration = floor durationSec / intervalSec
		@captureInterval = floor intervalSec * 1000
		@captureIntervalTick = floor intervalSec * Config.fps
		@captureContexts = []
		@isCaptured = []
		for i in [1..@captureDuration]
			cvs = document.createElement 'canvas'
			cvs.width = @size.x * scale
			cvs.height = @size.y * scale
			ctx = cvs.getContext "2d"
			ctx.scale scale, scale
			@captureContexts.push ctx
			@isCaptured.push false
		@captureCanvasIndex = 0
		@isEndCapturing = false
		@isCapturing = true
	@capture: ->
		@captureContexts[@captureCanvasIndex].drawImage @element, 0, 0
		@isCaptured[@captureCanvasIndex] = true
		@captureCanvasIndex =
			(@captureCanvasIndex + 1).lr 0, @captureDuration
	@endCapture: ->
		@isCapturing = false
		encoder = new GIFEncoder
		encoder.setRepeat 0
		encoder.setDelay @captureInterval
		encoder.start()
		idx = @captureCanvasIndex
		for i in [1..@captureDuration]
			encoder.addFrame @captureContexts[idx] if @isCaptured[idx]
			idx = (idx + 1).lr 0, @captureDuration
		encoder.finish()
		binaryGif = encoder.stream().getData()
		window.location.href =
			'data:image/gif;base64,' + (encode64 binaryGif)
	@preUpdate: ->
		@endCapture() if @isEndCapturing
		@capture() if @isCapturing && G.t % @captureIntervalTick == 0
		@clear()
		if @isCapturing && Key.ip[67]
			@drawText 'CAPTURING...', .5, .5, 0
			@isEndCapturing = true

# object in the game updated on every frame
class Actor
	# public functions
	@s: (targetClass) ->
		className = ('' + targetClass)
			.replace /^\s*function\s*([^\(]*)[\S\s]+$/im, '$1'
		for g in Actor.groups
			if g.name == className
				return g.s
		[]
	@scroll: (targetClasses, ox, oy = 0,
		  minX = 0, maxX = 0, minY = 0, maxY = 0) ->
		tcs =
			if (targetClasses instanceof Array)
				targetClasses
			else
				[targetClasses]
		for tc in tcs
			actors = @s tc
			for a in actors
				a.p.x += ox
				a.p.y += oy
				a.p.x = a.p.x.lr minX, maxX if minX < maxX
				a.p.y = a.p.y.lr minY, maxY if minY < maxY
	@clear: (targetClasses = null) ->
		Actor.groups = [] if !Actor.groups?
		if targetClasses == null
			g.clear() for g in Actor.groups
			return
		tcs =
			if (targetClasses instanceof Array)
				targetClasses
			else
				[targetClasses]
		for tc in tcs
			className = ('' + tc)
				.replace /^\s*function\s*([^\(]*)[\S\s]+$/im, '$1'
			for g in Actor.groups
				g.clear() if g.name == className
	removeGroups: -> Actor.groups = []

	# hmm, just noticed an issue with this:
	# basically in the original, the shorthand versions used the getter call style
	# and the longhand versions used function call style :/ not a fan
	
	remove: -> @isRemoving = true
	setDisplayPriority: (displayPriority) ->
		@group.displayPriority = displayPriority
		Actor.sortGroups()
	onCollision: (targetClass, handler = null) ->
		isCollided = false
		collideCheckedActors = Actor.s targetClass
		for cca in collideCheckedActors
			if @d.isCollided cca.d
				isCollided = true
				handler? cca
		isCollided
	@getter 'newDrawing', -> new Drawing
	@getter 'newFiber', ->
		f = new Fiber
		f.a = @
		@fibers.push f
		f
	@getter 'newParticle', ->
		p = new Particle
		p.p @p
		p
	@getter 'newRandom', -> new Random
	newSound: -> new Sound
	newText: (text) ->
		t = new Text text
		t.p @pos
		t
	@getter 'newVector', -> new Vector

	# functions should be overrided
	# initialize (called once per class)
	initialize: ->
	# begin (called after the Actor is instanced)
	begin: (args...) ->
	# update (called on every frame)
	update: ->

	# private functions
	@update: ->
		if Config.isDebuggingMode
			Actor.number = 0
			for g in Actor.groups
				g.update()
				Actor.number += g.s.length
		else
			g.update() for g in Actor.groups
		return
	@sortGroups: ->
		Actor.groups.sort (v1, v2) ->
			v1.displayPriority - v2.displayPriority
	constructor: (args...) ->
		@pos = new Vector
		@vel = new Vector
		@way = 0
		@speed = 0
		@ticks = 0
		@drawing = new Drawing
		@fibers = []
		@isRemoving = false
		className = ('' + @constructor)
			.replace /^\s*function\s*([^\(]*)[\S\s]+$/im, '$1'
		for group in Actor.groups
			if group.name == className
				@group = group
				break
		if !@group?
			@group = new ActorGroup className
			Actor.groups.push @group
			Actor.sortGroups()
			@initialize()
		@group.s.push @
		@begin args...
	postUpdate: ->
		@pos.add @vel
		@pos.addWay @way, @speed
		fiber.update() for fiber in @fibers
		@drawing.setPos(@pos).setWay(@way).draw
		@ticks++

class ActorShorthand extends Actor	
	#shorthand functions
	@sc: (args...) -> @scroll args...
	@getter 't', -> @ticks
	@setter 't', (v) -> @ticks = v
	@getter 'ir', -> @isRemoving
	@cl: (args...) -> @clear args...
	@getter 'r', -> @remove()
	dp: (args...) -> @setDisplayPriority args...
	oc: (args...) -> @onCollision args...
	@getter 'nd': -> @newDrawing
	@getter 'nf', -> @newFiber
	@getter 'np', -> @newParticle
	@getter 'nr', -> @newRandom
	@getter 'ns', -> @newSound()
	nt: (args...) -> @newText args...
	@getter 'p', -> @pos
	@setter 'p', (v) -> @pos = v
	@getter 'v', -> @vel
	@setter 'v', (v) -> @vel = v
	@getter 's', -> @speed
	@setter 's', (v) -> @speed = v
	@getter 'w', -> @way
	@setter 'w', (v) -> @way = v
	@getter 'd', -> @drawing
	@setter 'd', (v) -> @drawing = v
	@getter 'nv': -> @newVector

	constructor: (args...) ->
		@initialize = @i if @i?
		@begin = @b if @b?
		@update = @u if @u?
		super args...

class ActorGroup
	constructor: (@name) ->
		@clear()
		@displayPriority = 1
	clear: ->
		@s = []
	update: ->
		i = 0
		while true
			break if i >= @s.length
			a = @s[i]
			a.update() if !a.isRemoving
			if a.isRemoving
				@s.splice i, 1
			else
				a.postUpdate()
				i++
		return


# drawn character consists of rects
#
# Example drawing, draws a yellow square with inset black square
# ```
# @drawing
# 	# set the initial color
# 	.setColor Color.yellow
# 	# 'addRect' args: width, height, offsetX, offsetY
# 	.addRect 0.04, 0.04, 0, 0
# 	# set the black color
# 	.setColor Color.dark
# 	# add an inset square
# 	.addRect 0.012, 0.012, 0,0
# ```
#


class Drawing
	# sets the current drawing color
	# all rects added after this will use the current color
	setColor: (@color) -> @

	# add a single rect
	addRect: (width, height = 0, ox = 0, oy = 0) ->
		@lastAdded =
			type: 'rect'
			width: width
			height: height
			offsetX: ox
			offsetY: oy
		height = width if height == 0
		@shapes.push new DrawingRect @color, width, height,
			ox, oy, @hasCollision
		@

	# adds a set of rects that simulates a rotated square
	addRects: (width, height, ox = 0, oy = 0, way = 0) ->
		@lastAdded =
			type: 'rects'
			width: width
			height: height
			offsetX: ox
			offsetY: oy
			way: way
		w = way * PI / 180
		if width > height
			w += PI / 2
			tw = width
			width = height
			height = tw
		return @ if width < 0.01
		n = floor height / width
		o = -width * (n - 1) / 2
		vo = width
		width *= 1.05
		for i in [1..n]
			@shapes.push new DrawingRect @color, width, width,
				sin(w) * o + ox, cos(w) * o + oy, @hasCollision
			o += vo
		@
	addRotate: (angle, number = 1) ->
		o = new Vector().xy @lastAdded.offsetX, @lastAdded.offsetY
		w = @lastAdded.way
		for i in [1..number]
			o.rt angle
			switch @lastAdded.type
				when 'rect'
					@addRect @lastAdded.width, @lastAdded.height, o.x, o.y
				when 'rects'
					w -= angle
					@addRects @lastAdded.width, @lastAdded.height, o.x, o.y, w
		@
	@getter 'addMirrorX', ->
		switch @lastAdded.type
			when 'rect'
				@addRect @lastAdded.width, @lastAdded.height,
					-@lastAdded.offsetX, @lastAdded.offsetY
			when 'rects'
				@addRects @lastAdded.width, @lastAdded.height,
					-@lastAdded.offsetX, @lastAdded.offsetY,
					-@lastAdded.way
		@
	@getter 'addMirrorY', ->
		switch @lastAdded.type
			when 'rect'
				@addRect @lastAdded.width, @lastAdded.height,
					@lastAdded.offsetX, -@lastAdded.offsetY
			when 'rects'
				@addRects @lastAdded.width, @lastAdded.height,
					@lastAdded.offsetX, -@lastAdded.offsetY,
					-@lastAdded.way
		@
	setPos: (p) ->
		@pos.v p
		@
	setXy: (x, y) ->
		@pos.xy x, y
		@
	setWay: (w) ->
		@way = w
		@
	setScale: (x, y = -9999999) ->
		y = x if y == -9999999 
		@scale.xy x, y
		@
	@getter 'draw', ->
		r.draw @ for r in @shapes
		@
	@getter 'enableCollision', ->
		@hasCollision = true
		@
	@getter 'disableCollision', ->
		@hasCollision = false
		@
	onCollision: (targetClass, handler = null) ->
		@updateState()
		isCollided = false
		collideCheckedActors = Actor.s targetClass
		for cca in collideCheckedActors
			if @isCollided cca.d
				isCollided = true
				handler? cca
		isCollided
	@getter 'clear', ->
		@shapes = []
		@
		
	# private functions
	constructor: ->
		@shapes = []
		@pos = new Vector
		@way = 0
		@scale = new Vector 1, 1
		@hasCollision = true
		@color = Color.white
	updateState: -> 
		r.updateState @ for r in @shapes
		@
	isCollided: (d) ->
		isCollided = false
		#check each of our drawing rects
		for r in @shapes
			#against each of the other drawings rects
			for dr in d.shapes
				isCollided = true if r.isCollided dr
		isCollided

class DrawingShorthand extends Drawing
	# shorthand functions
	# grouped so that we can delete them easier later
	c: (args...) -> @setColor args...
	r: (args...) -> @addRect args...
	rs: (args...) -> @addRects args...
	rt: (args...) -> @addRotate args...
	p: (args...) -> @setPos args...
	xy: (args...) -> @setXy args...
	w: (args...) -> @setWay args...
	sc: (args...) -> @setScale args...
	oc: (args...) -> @onCollision args...

	# i think this may be a bug in the original mgl,
	# if you have a shorthand pointing to a getter, it must also be a getter
	@getter 'd', -> @draw
	@getter 'ec', -> @enableCollision
	@getter 'dc', -> @disableCollision
	@getter 'mx', -> @addMirrorX
	@getter 'my', -> @addMirrorY
	@getter 'cl', -> @clear

class DrawingRect
	constructor: (@color, width, height, ox, oy, @hasCollision) ->
		@size = new Vector width, height
		@offset = new Vector ox, oy
		@currentPos = new Vector
		@currentSize = new Vector
	updateState: (d) ->
		@currentPos.v @offset
		@currentPos.x *= d.scale.x
		@currentPos.y *= d.scale.y
		@currentPos.rt d.way
		@currentPos.a d.pos
		@currentSize.xy @size.x * d.scale.x, @size.y * d.scale.y
	draw: (d) ->
		@updateState d
		Display.fillRect @currentPos.x, @currentPos.y,
			@currentSize.x, @currentSize.y, @color
	isCollided: (r) ->
		return false if !@hasCollision || !r.hasCollision
		(abs @currentPos.x - r.currentPos.x) <
			(@currentSize.x + r.currentSize.x) / 2 &&
			(abs @currentPos.y - r.currentPos.y) <
			(@currentSize.y + r.currentSize.y) / 2

# lightweight thread
class Fiber
	# public functions
	doRepeat: (func) ->
		@funcs.push func
		@
	doOnce: (func) ->
		@funcs.push =>
			func.call @
			@n
		@
	wait: (ticks) ->
		@funcs.push =>
			@ticks = ticks
			@n
		@funcs.push =>
			@n if --@ticks < 0
		@
	@getter 'next', ->
		@funcIndex = 0 if ++@funcIndex >= @funcs.length
		@
	@getter 'remove', -> @removing = true

	# private functions
	constructor: ->
		@funcs = []
		@funcIndex = 0
		@removing = false
	update: ->
		@funcs[@funcIndex].call @

class FiberShorthand extends Fiber
	#shorthand/compatibility functions
	dr: (args...) -> @doRepeat args...
	d: (args...) -> @doOnce args...
	w: (args...) -> @wait args...
	@getter 'n', -> @next
	@getter 'r', -> @remove
	@getter 'isRemoving', -> @removing
	@getter 'ir', -> @removing

# rgb color
class Color
	# public functions
	constructor: (@rv, @gv, @bv) ->
	@d: new Color 0, 0, 0
	@dark: new Color 0, 0, 0
	@r: new Color 1, 0, 0
	@red: new Color 1, 0, 0
	@g: new Color 0, 1, 0
	@green: new Color 0, 1, 0
	@b: new Color 0, 0, 1
	@blue: new Color 0, 0, 1
	@y: new Color 1, 1, 0
	@yellow: new Color 1, 1, 0
	@m: new Color 1, 0, 1
	@magenta: new Color 1, 0, 1
	@c: new Color 0, 1, 1
	@cyan: new Color 0, 1, 1
	@w: new Color 1, 1, 1
	@white: new Color 1, 1, 1
	@ticks: new Color -1, -1, -1
	@transparent: new Color -1, -1, -1

	# private functions
	toString: ->
		v1 = 250
		v0 = 0
		r = floor(@rv * v1 + v0)
		g = floor(@gv * v1 + v0)
		b = floor(@bv * v1 + v0)
		"rgb(#{r},#{g},#{b})"

# letters drawn on the display
class Text
	# public functions
	setPos: (args...) -> @p args...
	p: (pos) ->
		@a.pos.v pos
		@
	setXy: (args...) -> @xy args...
	xy: (x, y) ->
		@a.pos.xy x, y
		@
	setVelocity: (args...) -> @v args...
	v: (x, y) ->
		@a.vel.xy x, y
		@
	setDuration: (args...) -> @d args...
	d: (duration) ->
		@a.duration = duration
		@
	displayedForever: -> @df
	@getter 'df', ->
		@a.duration = 9999999
		@
	alignLeft: -> @al
	@getter 'al', ->
		@a.xAlign = -1
		@
	alignRight: -> @ar
	@getter 'ar', ->
		@a.xAlign = 1
		@
	setColor: (args...) -> @c args...
	c: (color) ->
		@a.color = color
		@
	setScale: (args...) -> @sc args...
	sc: (scale) ->
		@a.scale = scale
		@
	showOnce: -> @so
	@getter 'so', ->
		if (Text.shownTexts.indexOf @a.text) >= 0
			@a.text = ''
			@a.remove()
		else
			Text.shownTexts.push @a.text
		@
	remove: -> @r
	@getter 'r', -> @a.remove()

	# private functions
	constructor: (text) ->
		@a = new TextActor
		@a.text = text
	@shownTexts: []
class TextActor extends Actor
	initialize: ->
		@setDisplayPriority 2
	begin: ->
		@duration = 1
		@xAlign = 0
		@color = Color.white
		@scale = 1
	update: ->
		@vel.d @duration if @ticks == 0
		Display.drawText @text, @pos.x, @pos.y, @xAlign, 0, @color, @scale
		@remove() if @ticks >= @duration - 1
class Letter
	@initialize: ->
		@COUNT = 66
		patterns = [
			0x4644AAA4, 0x6F2496E4, 0xF5646949, 0x167871F4, 0x2489F697,
			0xE9669696, 0x79F99668, 0x91967979, 0x1F799976, 0x1171FF17,
			0xF99ED196, 0xEE444E99, 0x53592544, 0xF9F11119, 0x9DDB9999,
			0x79769996, 0x7ED99611, 0x861E9979, 0x994444E7, 0x46699699,
			0x6996FD99, 0xF4469999, 0x2224F248, 0x26244424, 0x64446622,
			0x84284248, 0x40F0F024, 0x0F0044E4, 0x480A4E40, 0x9A459124,
			0x000A5A16, 0x640444F0, 0x80004049, 0x40400004, 0x44444040,
			0x0AA00044, 0x6476E400, 0xFAFA61D9, 0xE44E4EAA, 0x24F42445,
			0xF244E544, 0x00000042
			]
		p = 0
		d = 32
		pIndex = 0
		@dotPatterns = []
		for i in [1..@COUNT]
			dots = []
			for j in [1..5]
				for k in [1..4]
					if ++d >= 32
						p = patterns[pIndex++]
						d = 0
					dots.push new Vector().xy k, j if p & 1 > 0
					p >>= 1
			@dotPatterns.push dots
		charStr = "()[]<>=+-*/%&_!?,.:|'\"$@#\\urdl"
		@charToIndex = []
		for c in [0..127]
			li = if c == 32
				-1
			else if 48 <= c < 58
				c - 48
			else if 65 <= c < 90
				c - 65 + 10
			else
				ci = charStr.indexOf (String.fromCharCode c)
				if ci >= 0 then ci + 36 else -2
			@charToIndex.push li
	@setSize: (size) ->
		@baseDotSize = floor((min size.x, size.y) / 250 + 1).c 1, 20
	@draw: (text, x, y, xAlign, yAlign, color, scale) ->
		tx = floor x * Display.size.x
		ty = floor y * Display.size.y
		size = @baseDotSize * scale
		lw = size * 5
		if xAlign == 0
			tx -= floor text.length * lw / 2
		else if xAlign == 1
			tx -= floor text.length * lw
		ty -= floor size * 3.5 if yAlign == 0
		for c in text
			li = @charToIndex[c.charCodeAt 0]
			if li >= 0
				@drawDots li, tx, ty, color, size
			else if li == -2
				throw "invalid char: #{c}"
			tx += lw
		return
	@drawDots: (li, x, y, color, size) ->
		for p in @dotPatterns[li]
			Display.fillRectDirect x + p.x * size, y + p.y * size,
				size, size, color
		return

# particle effect
class Particle
	# public functions
	setPos: (args...) -> @p args...
	p: (@pos) -> @
	setXy: (args...) -> @xy args...
	xy: (x, y) ->
		@pos = new Vector().xy x, y
		@
	setNumber: (args...) -> @n args...
	n: (@number) -> @
	setWay: (args...) -> @w args...
	w: (@way, @wayWidth) -> @
	setSpeed: (args...) -> @s args...
	s: (@speed) -> @
	setColor: (args...) -> @c args...
	c: (@color) -> @
	setSize: (args...) -> @sz args...
	sz: (@size) -> @
	setDuration: (args...) -> @d args...
	d: (@duration) -> @
	# private functions
	constructor: ->
		@a = new ParticleActor
		@a.particle = @
		@number = 1
		@way = 0
		@wayWidth = 360
		@speed = 0.01
		@color = Color.white
		@size = 0.02
		@duration = 30
class ParticleActor extends Actor
	initialize: ->
		@setDisplayPriority 0
	update: ->
		if @particle?
			@remove()
			pp = @particle
			return if pp.number < 1
			ww = pp.wayWidth / 2
			for i in [1..pp.number]
				p = new ParticleActor
				p.pos.v pp.pos
				p.vel.aw pp.way + ((-ww).rr ww),
					pp.speed * (0.5.rr 1.5)
				p.color = pp.color
				p.size = pp.size
				p.duration = pp.duration * (0.5.rr 1.5)
			return
		Display.fillRect @pos.x, @pos.y, @size, @size, @color
		if @ticks >= @duration - 1
			@remove()

# mouse/touch position and event
class Mouse
	# public functions
	@classGetter 'pos', -> @p
	@classGetter 'isPressing', -> @ip
	@classGetter 'isPressed', -> @ipd
	@classGetter 'isMoving', -> @im

	# private functions
	@initialize: ->
		@p = new Vector().n .5
		@ip = @ipd = @wasPressing = @im = @wasMoving = false
		@pressedDisabledCount = 0
		Display.element.addEventListener 'mousedown', @onMouseDown
		Display.element.addEventListener 'mousemove', @onMouseMove
		Display.element.addEventListener 'mouseup', @onMouseUp
		Display.element.addEventListener 'touchstart', @onTouchStart
		Display.element.addEventListener 'touchmove', @onTouchMove
		Display.element.addEventListener 'touchend', @onTouchEnd
	@onMouseMove: (e) =>
		e.preventDefault()
		@wasMoving = true
		rect = e.target.getBoundingClientRect()
		@p.x = ((e.pageX - rect.left) / Display.size.x).c 0, 1
		@p.y = ((e.pageY - rect.top) / Display.size.y).c 0, 1
	@onMouseDown: (e) =>
		@ip = true
		@onMouseMove e
		G.onfocus()
	@onMouseUp: (e) =>
		@ip = false
	@onTouchMove: (e) =>
		e.preventDefault()
		@wasMoving = true
		rect = e.target.getBoundingClientRect()
		touch = e.touches[0]
		@p.x = ((touch.pageX - rect.left) / Display.size.x).c 0, 1
		@p.y = ((touch.pageY - rect.top) / Display.size.y).c 0, 1
	@onTouchStart: (e) =>
		@ip = true
		@onTouchMove e
		G.onfocus()
	@onTouchEnd: (e) =>
		@ip = false		
	@update: ->
		@ipd = false
		if @ip
			if !@wasPressing
				@ipd = true if @pressedDisabledCount <= 0
		else
			@pressedDisabledCount--
		@wasPressing = @ip
		if @wasMoving
			@im = true
			@wasMoving = false
		else
			@im = false
	@setPressedDisabledCount: (c) ->
		@pressedDisabledCount = c
		@ipd = false

# key pressing event
class Key
	# public functions
	@classGetter 'isPressing', -> @ip
	
	# private functions
	@initialize: ->
		@ip = (false for [0..255])
		window.onkeydown = (e) =>
			@ip[e.keyCode] = true
			e.preventDefault() if 37 <= e.keyCode <= 40
		window.onkeyup = (e) =>
			@ip[e.keyCode] = false

# sound effect and bgm
class Sound
	# public functions
	@setSeed: (seed) ->
		@random.setSeed seed
	@setQuantize: (@quantize = 1) ->
	constructor: ->
		@s = [] if !@s?
		@s.push @
		@volume = 1
	setVolume: (@volume) -> @
	setParam: (@param) ->
		return @ if !Sound.isEnabled
		@param[2] *= @volume
		@buffer = WebAudiox.getBufferFromJsfx Sound.c, @param
		@
	changeParam: (index, ratio) ->
		return @ if !Sound.isEnabled
		@param[index] *= ratio		
		@buffer = WebAudiox.getBufferFromJsfx Sound.c, @param
		@
	setDrum: (seed = 0) ->
		@pr (Sound.generateDrumParam seed)
		@
	setPattern: (@pattern, @patternInterval = 0.25) -> @
	setDrumPattern: (seed = 0, patternInterval = 0.25) ->
		@setPattern (Sound.generateDrumPattern seed), patternInterval
		@
	play: -> 
		return @ if !Game.running || !Sound.isEnabled
		@isPlayingOnce = true
		@
	playNow: -> 
		return @ if !Game.running || !Sound.isEnabled
		@playLater 0
		@
	playPattern: ->
		return @ if !Game.running || !Sound.isEnabled
		@isPlayingLoop = true
		@scheduledTime = null
		@
	@generateParam: (seed, params, mixRatio = 0.5) ->
		random = if seed != 0 then new Random(seed) else @random
		psl = params.length
		i = random.ri 0, psl - 1
		p = params[i].concat()
		pl = p.length
		while random.r() < mixRatio
			ci = random.ri 0, psl - 1
			cp = params[ci]
			for i in [1..pl - 1]
				rt = random.r()
				p[i] = p[i] * rt + cp[i] * (1 - rt)
		p
	#shorthand
	@getter 'pn', -> @playNow()
	@getter 'pp', -> playPattern()
	@getter 'p', -> @play()
	d: (args...) -> @setDrum args...
	pt: (args...) -> @setPattern args...
	dp: (args...) -> @setDrumPattern args...
	cpr: (args...) -> @changeParam args...
	@sd: (args...) -> @setSeed args...
	@q: (args...) -> @setQuantize args...
	v: (args...) -> @setVolume args...
	pr: (args...) -> @setParam args...

	# private functions
	@initialize: ->
		try
			@c = new AudioContext
			@gn = Sound.c.createGain()
			@gn.gain.value = Config.soundVolume
			@gn.connect Sound.c.destination
			@isEnabled = true
		catch error
			@isEnabled = false
		@playInterval = 60 / Config.soundTempo
		@scheduleInterval = 1 / Config.fps * 2
		@quantize = 0.5
		@clear()
		@initDrumParams()
		@initDrumPatterns()
		@random = new Random
	@clear: ->
		@s = []
	@reset: ->
		s.reset() for s in @s
	@update: ->
		return if Game.isPaused || !Game.running || !@isEnabled
		ct = @c.currentTime
		tt = ct + @scheduleInterval
		s.update ct, tt for s in @s
	@initDrumParams: ->
		@drumParams = [
			["sine",0,3,0,0.1740,0.1500,0.2780,20,528,2400,-0.6680,0,0,0.0100,0.0003,0,0,0,0.5000,-0.2600,0,0.1000,0.0900,1,0,0,0.1240,0]
			["square",0,2,0,0,0,0.1,20,400,2000,-1,0,0,0,0.5,0,0,0,0.5,-0.5,0,0,0.5,1,0,0,0.75,-1]
			["noise",0,2,0,0,0,0.1,1300,500,2400,1,-1,1,40,1,0,1,0,0,0,0,0.75,0.25,1,-1,1,0.25,-1]
			["noise",0,2,0,0,0,0.05,2400,2400,2400,0,-1,0,0,0,-1,0,0,0,0,0,-0.15,0.1,1,1,0,1,1]
			["noise",0,2,0,0.0360,0,0.2860,20,986,2400,-0.6440,0,0,0.0100,0.0003,0,0,0,0,0,0,0,0,1,0,0,0,0]
			["saw",0,1,0,0.1140,0,0.2640,20,880,2400,-0.6000,0,0,0.0100,0.0003,0,0,0,0.5000,-0.3620,0,0,0,1,0,0,0,0]
			["synth",0,2,0,0.2400,0.0390,0.1880,328,1269,2400,-0.8880,0,0,0.0100,0.0003,0,0,0,0.4730,0.1660,0,0.1700,0.1880,1,0,0,0.1620,0]
		]
	@initDrumPatterns: ->
		@drumPatterns = [
			'0000010000000001'
			'0000100000001000'
			'0000100100001000'
			'0000100001001000'
			'0000101111001000'
			'0000100100101000'
			'0000100000001010'
			'0001000001000101'
			'0010001000100010'
			'0010001000100010'
			'0100000010010000'			
			'1000100010001000'
			'1010010010100101'
			'1101000001110111'
			'1000100000100010'
			'1010101010101010'
			'1000100011001000'
			'1111000001110110'
			'1111101010111010'
		]
	@generateDrumParam: (seed) ->
		@generateParam seed, @drumParams
	@generateSeParam: (type, seed) ->
		@generateParam seed, @seParams[type], 0.75
	@generateDrumPattern: (seed) ->
		random = if seed != 0 then new Random(seed) else @random
		dpsl = @drumPatterns.length
		i = random.ri 0, dpsl - 1
		dp = @drumPatterns[i]
		dpl = dp.length
		dpa = []
		for i in [0..dpl - 1]
			d = dp.charAt i
			dpa.push if d == '1' then true else false
		while random.r() < .5
			ci = random.ri 0, dpsl - 1
			cdp = @drumPatterns[ci]
			for i in [0..dpl - 1]
				cd = cdp.charAt i
				c = if cd == '1' then true else false
				dpa[i] = (!dpa[i]) != (!c)
		gdp = ''
		for d in dpa
			gdp += if d then '1' else '0'
		gdp
	reset: ->
		@isPlayingOnce = @isPlayingLoop = null
	update: (ct, tt) ->
		if @isPlayingOnce?
			@isPlayingOnce = null
			pi = Sound.playInterval * Sound.quantize
			pt = ceil(ct / pi) * pi
			if !@playedTime? || pt > @playedTime
				@playLater pt
				@playedTime = pt
		return if !@isPlayingLoop?
		if !@scheduledTime?
			@scheduledTime =
				ceil(ct / Sound.playInterval) * Sound.playInterval -
				Sound.playInterval * @patternInterval
			@patternIndex = 0
			@calcNextScheduledTime()
		@calcNextScheduledTime() while @scheduledTime < ct
		while @scheduledTime <= tt
			@playLater @scheduledTime
			@calcNextScheduledTime()
		return
	calcNextScheduledTime: ->
		pn = @pattern.length
		sti = Sound.playInterval * @patternInterval
		for i in [0..99]
			@scheduledTime += sti
			p = @pattern.charAt @patternIndex
			@patternIndex = (@patternIndex + 1).lr 0, pn
			break if p == '1'
		return
	playLater: (delay) ->
		s = Sound.c.createBufferSource()
		s.buffer = @buffer
		s.connect Sound.gn
		s.start = s.start || s.noteOn
		s.start delay

# random number generator
class Random
	# public functions
	r: (args...) -> @range args...
	range: (from = 0, to = 1) ->
		@get0to1() * (to - from) + from
	ri: (args...) -> @rangeInt args...
	rangeInt: (from = 0, to = 1) ->
		floor(@range from, to + 1)
	pm: (args...) -> @plusMinus args...
	@getter 'plusMinus', ->
		(@rangeInt 0, 1) * 2 - 1
	sd: (args...) -> @setSeed args...
	setSeed: (seed = -0x7fffffff) ->
		seedValue = if seed == -0x7fffffff
			floor Math.random() * 0x7fffffff
		else
			seed
		@x = seedValue = 1812433253 * (seedValue ^ (seedValue >> 30))
		@y = seedValue = 1812433253 * (seedValue ^ (seedValue >> 30)) + 1
		@z = seedValue = 1812433253 * (seedValue ^ (seedValue >> 30)) + 2
		@w = seedValue = 1812433253 * (seedValue ^ (seedValue >> 30)) + 3
		@
	# private functions
	constructor: -> @setSeed()
	get0to1: -> 
		t = @x ^ (@x << 11)
		@x = @y
		@y = @z
		@z = @w
		@w = (@w ^ (@w >> 19)) ^ (t ^ (t >> 8))
		@w / 0x7fffffff

# 2d vector
class Vector
	# public functions
	setXy: (@x = 0, @y = 0) ->
		@
	setNumber: (v = 0) ->
		@xy v, v
		@
	setValue: (v) ->
		@x = v.x
		@y = v.y
		@
	add: (v) ->
		@x += v.x
		@y += v.y
		@
	sub: (v) ->
		@x -= v.x
		@y -= v.y
		@
	mul: (v) ->
		@x *= v
		@y *= v
		@
	div: (v) ->
		@x /= v
		@y /= v
		@
	addWay: (way, speed) ->
		rw = way * PI / 180
		@x += (sin rw) * speed
		@y -= (cos rw) * speed
		@
	rotate: (way) ->
		return @ if way == 0
		w = way * PI / 180
		px = @x
		@x = @x * (cos w) - @y * (sin w)
		@y = px * (sin w) + @y * (cos w)
		@
	distanceTo: (pos) ->
		ox = pos.x - @x
		oy = pos.y - @y
		sqrt ox * ox + oy * oy
	wayTo: (pos) ->
		(atan2 pos.x - @x, -(pos.y - @y)) * 180 / PI
	isIn: (spacing = 0, minX = 0, maxX = 1, minY = 0, maxY = 1) ->
		minX - spacing <= @x <= maxX + spacing && 
		minY - spacing <= @y <= maxY + spacing
	getWay: ->
		(atan2 @x, -@y) * 180 / PI
	getLength: (args...) -> sqrt @x * @x + @y * @y
	# private functions
	constructor: (@x = 0, @y = 0) ->

class VectorShorthand extends Vector
	@getter 'l', (args...)-> @getLength()
	@getter 'w', (args...) -> @getWay args...
	wt: (args...) -> @wayTo args...
	aw: (args...) -> @addWay args...
	rt: (args...) -> @rotate args...
	xy: (args...) -> @setXy args...
	n: (args...) -> @setNumber args...
	v: (args...) -> @setValue args...
	ii: (args...) -> @isIn args...
	dt: (args...) -> @distanceTo args...
	a: (args...) -> @add args...
	d: (args...) -> @div args...
	m: (args...) -> @mul args...
	s: (args...) -> @sub args...

# game settings
class Config
	@fps: 60
	@backgroundColor: '#000'
	@soundTempo: 120
	@soundVolume: 0.02
	@title: ['MGL.', 'COFFEE']
	@lineNoise: true
	@getter 'allowLineNoise', -> @lineNoise
	@setter 'allowLineNoise', (value) ->
		@lineNoise = value
		if(!@lineNoise)
			DisableLineNoise()
		else
			EnableLineNoise()

	#@isDebuggingMode: true
	#@captureArgs: [1, 3, 0.05]

# functions to allow for the line noise style
# of programming from the original MGL

# store the original settings so we can drop back to them
# depending on configuration
DrawingCore = Drawing
ActorCore = Actor
FiberCore = Fiber
VectorCore = Vector
A = ""
C = ""
G = ""
M = ""

EnableLineNoise = ->
	Drawing = DrawingShorthand
	Actor = ActorShorthand
	Vector = VectorShorthand
	Fiber = FiberShorthand
	# short name aliases for classes
	A = Actor
	C = Color
	G = Game
	M = Mouse
DisableLineNoise = ->
	Drawing = DrawingCore
	Actor = ActorCore
	Fiber = FiberCore
	Vector = VectorCore
	# short name aliases for classes
	A = AOriginal
	C = COriginal
	G = GOriginal
	M = MOriginal


EnableLineNoise()

# aliases for functions
PI = Math.PI
sin = Math.sin
cos = Math.cos
atan2 = Math.atan2
abs = Math.abs
sqrt = Math.sqrt
floor = Math.floor
ceil = Math.ceil
max = Math.max
min = Math.min
# utility functions for Number
Number::clamp = (args...) -> @.c args...
Number::c = (min = 0, max = 1) ->
	if @ < min then min else if @ > max then max else @
Number::loopRange = (args...) -> @.lr args...
Number::lr = (min = 0, max = 1) ->
	w = max - min
	v = @
	v -= min
	if v >= 0
		v % w + min
	else
		w + v % w + min
Number::normalizeWay = -> @.nw
Number.getter 'nw', ->
	(@ % 360).lr -180, 180
Number::randomRange = (args...) -> @.rr args...
Number::rr = (to = 1) ->
	Game.r.r @, to
Number::randomRangeInt = (args...) -> @.rri args...
Number::rri = (to = 1) ->
	Game.r.ri @, to