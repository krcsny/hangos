
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
    @ctx.fillStyle = if MasterRecorder? and MasterRecorder.isRecording() then "#F55D3E22" else "#76BED0"
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
        r.sign = "&sum;"
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
        r = new Tone.BitCrusher(5).toMaster()
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

MasterRecorder = null

Recorder = 
  muteOnRec : false
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
    @recording = false
    @ready @url
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
    Tone.Master.mute = @muteOnRec
    # navigator.mediaDevices.getUserMedia({ audio: true })
      # .then(@record.bind(Recorder))

  saveFile : (blob) ->
    a = $("<a style='display: none;'/>")
    # blob = new Blob(@audioChunks, {type: 'audio/ogg; codecs=opus'})
    url = window.URL.createObjectURL(blob)
    a.attr("href", url)
    date = new Date()
    name = "hangos " + date.toTimeString().substr(0,9).replace(/:/g, "-") + date.getDate() + "/" + date.getMonth() + "/" + date.getFullYear() 
    a.attr("download", name)
    $("body").append(a)
    a[0].click()
    window.URL.revokeObjectURL(url)
    a.remove()
    
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
    Tone.Master.mute = false

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

setMasterButtons = (show) ->
  for b in [1..3]
    $($("#master").children()[b])[show]()


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
  
  # $($($("#phone").children()[2]).children()[1]).html(if playing then "&#x25a0;" else "&#x25b6;")

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
    class :"numpad, masterbutton"
    click : (e) ->
      Tone.Master.volume.value = Math.clamp(Tone.Master.volume.value - 1, -64, 12)
  )
  volumeUp = $("<button>", 
    html : "+"
    class :"numpad, masterbutton"
    click : (e) ->
      Tone.Master.volume.value = Math.clamp(Tone.Master.volume.value + 1, -64, 12)
  )
  mainrec = $("<button>", 
    html : "&#x25cf;"
    # html : "&nbsp;"
    class :"numpad, masterbutton, masterrecord"
    click : (e) ->
      if MasterRecorder.isRecording()
        MasterRecorder.finishRecording()
        $("#master").removeClass "record"
        setMasterButtons "show"
      else
        MasterRecorder.startRecording()
        $("#master").addClass "record"
        setMasterButtons "hide"
  )
  mainplay = $("<button>", 
    html : "&#x25b6;"
    class :"numpad, masterbutton"
    click : (e) ->
      playing = Recorder.slots.reduce(((a, v) -> if a then a else v.state is "started"), false)
      for s in Recorder.slots
        if s.buffer.loaded
          if playing then s.stop() else s.start()        
  )
  muteonrec = $("<button>", 
    html : "h"
    class :"numpad, masterbutton"
    click : (e) ->
      Recorder.muteOnRec = not Recorder.muteOnRec
      $(@).html(if Recorder.muteOnRec then "f" else "h")
  )

  master = $("<div>",
    class : "buttonrow"
    id : "master"
    html : [mainrec, muteonrec, volumeDown, volumeUp]
  )

  $("#phone").append master

  touchmouse = (e) ->
    e.preventDefault()
    touchstart = e.type is 'touchstart' or e.type is 'touchmove'
    e = if touchstart then e.originalEvent else e
    w = Visual.ctx.canvas.width
    h = Visual.ctx.canvas.height
    x = if touchstart then e.targetTouches[0].offsetX else e.offsetX
    y = if touchstart then e.targetTouches[0].offsetY else e.offsetY
    if touchstart or e.type is "mousedown"
      Mouse.down = true
    if Mouse.down
      Recorder.setEffect(Math.floor((x / w) * Slots), 1 - (y / h))  

  $("canvas").on("touchstart mousedown mousemove touchmove", touchmouse)

  $("canvas").on("touchend mouseup", (e) -> 
    e.preventDefault()
    Mouse.down = false
  )
  
  # $(document).on("mouseup", () -> Mouse.down = false)

  # $("canvas").on("touchmove mousemove", (e) ->
  #   if Mouse.down
  #     $("#text").html e.offsetX
  #     w = Visual.ctx.canvas.width;
  #     h = Visual.ctx.canvas.height;
  #     x = e.offsetX
  #     y = e.offsetY
  #     Recorder.setEffect(Math.floor((x / w) * Slots), 1 - (y / h))
  #   else
  #     $("#text").html "NO MOUSE DOWN"
  # )

  Visual.init()
  Recorder.init()
  MasterRecorder = new WebAudioRecorder(Tone.Master, workerDir : "lib/", encoding : "mp3")
  MasterRecorder.onComplete = (rec, blob) ->
    Recorder.saveFile(blob)
  setInterval(checkstates, 100)

init()
