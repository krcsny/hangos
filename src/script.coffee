
Player = new Tone.Player().toMaster()

Mic = new Tone.UserMedia()

Visual = 
  mode : "wave" # "wave"
  waveform : null
  micform : null
  ctx : null
  hsl : (h, s, l, a) -> 
   "hsl(#{h * 360}, #{s * 100}%, #{l * 100}%, #{a})"
  slots : (w, h) ->
    sw = w / Slots
    hw = sw * 0.5
    for s in [0..Slots-1]
      if Recorder.slots[s]? and Recorder.slots[s].state is "started"
        @ctx.fillStyle = @hsl 0.9 + Math.random() * 0.2, 0.8 + Math.random() * 0.1, 0.3, 0.2 + Math.random() * 0.2
        @ctx.fillRect(s * sw, 0, sw, h)
        y = (1 - (Recorder.getEffectValue s)) * h
        @ctx.fillStyle = "#0004"
        @ctx.beginPath()
        @ctx.arc(s * sw + hw, y, hw, 0, 2 * Math.PI)
        @ctx.fill()
  drawWaveform : (values) ->
    w = @ctx.canvas.width
    h =  @ctx.canvas.height
    # @ctx.clearRect(0, 0, w, h)
    @ctx.fillStyle = "#76BED0"
    @ctx.fillRect(0, 0, w, h)
    @slots w, h
    @ctx.lineJoin = "bezel"

    @ctx.strokeStyle = "#000"
    @ctx.lineWidth = 1 + values[0] * (15 + Math.random() * 5)
    @ctx.beginPath()
    @ctx.moveTo(0, 0.5 * h)
    # console.log values
    for v, i in values
      x = (i / values.length) * w
      y = ((v + 1) / 2) * 2 * h - h * 0.5
      @ctx.lineTo(x, y)
    @ctx.lineTo(w, 0.5 * h)
    @ctx.stroke()
  draw : () ->
    @drawWaveform( if Recorder.recording then @micform.getValue() else @waveform.getValue());
    requestAnimationFrame(Visual.draw.bind(Visual));
  write : (text) ->
    # if @mode is "text"
    $("#text").html text
  resize : () ->
    @ctx.canvas.width = $("#screen").width()
    @ctx.canvas.height = $("#screen").height()
  init : () ->
    if @mode is "wave"
      @waveform = new Tone.Waveform(256)
      @micform = new Tone.Waveform(256)
      Tone.Master.fan @waveform
      Mic.connect @micform
      @ctx = $("canvas").get(0).getContext("2d")
      $(window).resize Visual.resize.bind(Visual)
      @resize()
      @draw()

Slots = 6

FX = 
  names : [
    "Tone"
    "PitchShift"
    "Freeverb"
    "Chorus"
    "PingPongDelay"
    "BitCrusher"
    "Distortion"
    "Reverse"
  ]
  create : (i, parent) ->
    r = null
    name = @names[i]
    switch name
      when "Tone"
        r = new Tone.Limiter(0).toMaster()
        r.sign = "%"
        r.parent = parent
        r.getVal = () ->
          if r.parent? 
            Math.sqrt(parent.playbackRate / 6)
          else
            -1
        r.setVal = (y) ->
          if r.parent? 
            parent.set "playbackRate", 0.1 + y * y * 6

      when "PitchShift"
        r = new Tone.PitchShift(-6).toMaster()
        r.sign = "*"
        r.getVal = () ->
          (10 + @pitch) / 36
        r.setVal = (y) ->
          r.set "pitch", -10 + 36 * y

      when "Freeverb"
        r = new Tone.Freeverb().toMaster()
        r.sign = "&"
        r.getVal = () ->
          (@roomSize.value - 0.5) / 0.45
        r.setVal = (y) ->
          r.set "roomSize", 0.5 + 0.45 * y

      when "Chorus"
        r = new Tone.Chorus().toMaster()
        r.sign = "~"
        r.getVal = () ->
          (@depth - 0.7) / 0.3
          # 1 - ((10 + @pitch) / 24)
        r.setVal = (y) ->
          @set "frequency", 0.1 + y * 50
          @depth = 0.7 + 0.3 * y
          # @delayTime = 1 + 9 * y

      when "Phaser"
        r = new Tone.Phaser().toMaster()
        r.sign = "~"
        r.getVal = () ->
          @depth
        r.setVal = (y) ->
          @set "frequency", 0.5 + y * 99.5
          @depth = 0.1 + 0.7 * y

      when "PingPongDelay"
        r = new Tone.PingPongDelay().toMaster()
        r.sign = ":"
        r.getVal = () ->
          @delayTime.value
          # 1 - ((10 + @pitch) / 24)
        r.setVal = (y) ->
          r.set "maxDelay", y
          r.set "delayTime", y

      when "BitCrusher"
        r = new Tone.BitCrusher(3).toMaster()
        r.sign = "#"
        r.getVal = () ->
          1 - ((@bits - 3) / 3)
        r.setVal = (y) ->
          @set "bits", 6 - Math.round(y * 3)

      when "Distortion"
        r = new Tone.Distortion().toMaster()
        r.sign = "!"
        r.getVal = () ->
          @distortion
        r.setVal = (y) ->
          @set "distortion", y

      when "Reverse"
        r = new Tone.Limiter(0).toMaster()
        r.sign = "<"
        r.getVal = () -> -1
        r.setVal = () ->
    r.index = i
    r
    
Math.clamp = (x, min, max) ->
  Math.min(Math.max(x, min), max)

Recorder = 
  recording : false
  rec : null
  audioChunks : []
  audio : null
  url : null
  slots : []
  currentSlot : 0
  # effects : [
  #   Tone.Master
  #   new Tone.PitchShift(-7).toMaster()
  #   new Tone.PitchShift(12).toMaster()
  #   new Tone.BitCrusher(3).toMaster()
  # ]
  init : () ->
    @slots = 
      for s in [0..Slots - 1]
        slot = new Tone.Player()
        slot.effect = FX.create 0, slot
        slot.connect slot.effect
        slot.loop = true
        slot
  stop : () -> @rec.stop()

  pushdata : (e) ->
    @audioChunks.push(e.data)
  convertData : () ->
    console.log "stopped recording"
    audioBlob = new Blob(@audioChunks)
    @url = URL.createObjectURL(audioBlob)
    # @audio = new Audio(@url)
    @ready @url
    @recording = false
    # audio.play()
    
  record : (mic) ->
    stream = mic._stream
    @recording = true
    console.log "started recording"
    @audioChunks = []
    @rec = new MediaRecorder stream
    @rec.start()

    @audioChunks = []
    @rec.addEventListener("dataavailable", @pushdata.bind(@))

    @rec.addEventListener("stop", @convertData.bind(@))

    # setTimeout((() -> Recorder.rec.stop()),3000)
  start : () ->
    Mic.open().then(@record.bind(@))
    # navigator.mediaDevices.getUserMedia({ audio: true })
      # .then(@record.bind(Recorder))

  # saveFile : (name, blob) ->
  #   if (data != null && navigator.msSaveBlob)
  #       return navigator.msSaveBlob(new Blob([data], { type: type }), name);
  #   var a = $("<a style='display: none;'/>");
  #   var url = window.URL.createObjectURL(new Blob([data], {type: type}));
  #   a.attr("href", url);
  #   a.attr("download", name);
  #   $("body").append(a);
  #   a[0].click();
  #   window.URL.revokeObjectURL(url);
  #   a.remove();
  # }
    
  ready : (url, blob) ->
    # console.log @audio
    # if @currentSlot is -1
    console.log "setting buffer"
    new Tone.Buffer(url, @bufferReady.bind(@))
  bufferReady : (b) ->
    slot = @slots[@currentSlot]
    slot.buffer = b
    slot.buffer.reverse = slot.effect.sign is "<"
    @togglePlayer @currentSlot

  togglePlayer : (s) ->
    if Recorder.slots[s].buffer.loaded
      if @slots[s].state is "started"
        @slots[s].stop()
      else 
        @slots[s].start()

  toggleLooping : (s) ->
    @slots[s].loop = not @slots[s].loop

  toggleRecord : (s) ->
    # if s is -1
    #   @currentSlot = -1
    if @recording
      setbuttons @currentSlot, "show"
      @stop()
    else
      @currentSlot = s
      setbuttons @currentSlot, "hide"
      @start()

  cycleEffect : (s) ->
    slot = @slots[s]
    slot.disconnect slot.effect
    slot.effect.dispose()
    slot.effect = FX.create((slot.effect.index + 1) % FX.names.length, slot)
    slot.connect slot.effect
    slot.buffer.reverse = slot.effect.sign is "<"
    slot.playbackRate = 1

  getEffectValue : (s) ->
    e = @slots[s].effect.index
    fx = @slots[s].effect
    fx.getVal()
    
  setEffect : (s, y) ->
    s = Math.clamp(s, 0, Slots)
    slot = @slots[s]
    if slot.state is "started"
      slot.effect.setVal y

        
      





setbuttons = (s, show) ->
  for ss in [0..Slots-1]
    if ss isnt s
      $($("#buttons").children()[ss])[show]()
  for x in [1..4]
    $($($("#buttons").children()[s]).children()[x])[show]()
    # $("#buttons:nth-child(#{s}):nth-child(#{x})").hide()

checkstates = () ->
  playing = false
  for s in [0..Slots-1]
    h = "&empty;"
    if Recorder.slots[s].state is "started"
      playing = true
      h = "&#x25a0;"
    else if Recorder.slots[s].buffer.loaded
      h = "&#x25b6;"
    $($($("#buttons").children()[s]).children()[1]).html(h)
  
  $($($("#phone").children()[2]).children()[1]).html(if playing then "&#x25a0;" else "&#x25b6;")
    # if Recorder.currentSlot is s
    #   $($("#buttons").children()[s]).addClass "current"
    # else
    #   $($("#buttons").children()[s]).removeClass "current"

Mouse =
  down : false

init = () ->
  slots = 
    for s in [0..Slots - 1]
      record = $("<button>", 
        html : "&#x25cf;"
        # html : "&nbsp&#x25cf;&nbsp"
        class :"numpad, record"
        click : (e) ->
          Tone.context.resume()
          s = $(e.currentTarget).parent().index()
          Recorder.toggleRecord(s)
      )
      play = $("<button>", 
        html : ""
        class :"numpad, play"
        click : (e) ->
          s = $(e.currentTarget).parent().index()
          Recorder.currentSlot = s
          Recorder.togglePlayer(s)
      )
      looper = $("<button>", 
        html : "&infin;"
        class :"numpad, loop"
        click : (e) ->
          s = $(e.currentTarget).parent().index()
          Recorder.currentSlot = s
          Recorder.toggleLooping(s)
          $(@).html(if Recorder.slots[s].loop then "&infin;" else "&#x21e5;")
      )
      fx = $("<button>", 
        html : "%"
        class :"numpad, effect"
        click : (e) ->
          s = $(e.currentTarget).parent().index()
          Recorder.currentSlot = s
          Recorder.cycleEffect(s)
          $(@).html(Recorder.slots[s].effect.sign)
      )
      buttons = [record, play, looper, fx]
      $("<div>",
        class : "buttonrow"
        html : buttons
      )

  $("#buttons").html slots

  volumeDown = $("<button>", 
    html : "-"
    class :"numpad"
    click : (e) ->
      Tone.Master.volume.value = Math.clamp(Tone.Master.volume.value - 1, -64, 12)
  )
  volumeUp = $("<button>", 
    html : "+"
    class :"numpad"
    click : (e) ->
      Tone.Master.volume.value = Math.clamp(Tone.Master.volume.value + 1, -64, 12)
  )
  mainrec = $("<button>", 
    # html : "&#x25cf;"
    html : "&nbsp;"
    class :"numpad"
    click : (e) ->
      # Recorder.toggleRecord -1
  )
  mainplay = $("<button>", 
    html : "&#x25b6;"
    class :"numpad"
    click : (e) ->
      playing = Recorder.slots.reduce(((a, v) -> if a then a else v.state is "started"), false)
      for s in Recorder.slots
        if s.buffer.loaded
          if playing then s.stop() else s.start()        
  )

  master = $("<div>",
    class : "buttonrow"
    html : [mainrec, mainplay, volumeDown, volumeUp]
  )

  $("#phone").append master

  $(window).mousedown(() -> Mouse.down = true)
  $(window).mouseup(() -> Mouse.down = false)

  $("#screen").mousemove((e) ->
    if Mouse.down
      w = Visual.ctx.canvas.width;
      h = Visual.ctx.canvas.height;
      x = e.offsetX
      y = e.offsetY
      Recorder.setEffect(Math.floor((x / w) * Slots), 1 - (y / h))
  )

  Visual.init()
  Recorder.init()
  setInterval(checkstates, 100)

init()
