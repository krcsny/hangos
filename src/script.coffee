
Player = new Tone.Player().toMaster()

Mic = new Tone.UserMedia()

Visual = 
  mode : "wave" # "wave"
  waveform : null
  micform : null
  ctx : null
  hsl : (h, s, l, a) -> 
   "hsl(#{h * 360}, #{s * 100}%, #{l * 100}%, #{a})"
  loops : (w, h) ->
    sw = w / 3
    sh = h / 3
    for l in [0..8]
      @ctx.fillStyle = 
        if Looper.tracks[l].player.mute
          "#6244"
        else
          @hsl 0.9 + Math.random() * 0.2, 0.8 + Math.random() * 0.1, 0.3, 0.2 + Math.random() * 0.2
      @ctx.fillRect((l % 3) * sw, Math.floor(l / 3) * sh, sw, sh)
  drawWaveform : (values) ->
    w = @ctx.canvas.width
    h =  @ctx.canvas.height
    # @ctx.clearRect(0, 0, w, h)
    @ctx.fillStyle = "#6244"
    @ctx.fillRect(0, 0, w, h)
    if Map.current? and Map.current.isLooper()
      @loops w, h
    @ctx.lineJoin = "bezel"

    @ctx.strokeStyle = @hsl 0.9 + Math.random() * 0.2, 0.8 + Math.random() * 0.1, 0.5, 0.5 # "d48"
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
      
    # segment = 128
    # for part in [0..7]
    #   @ctx.lineWidth = 1 + values[0] * (15 + Math.random() * 5)
    #   @ctx.strokeStyle = @hsl 0.9 + Math.random() * 0.2, 0.8 + Math.random() * 0.1, 0.5, 0.5 # "d48"
    #   @ctx.beginPath()
    #   @ctx.moveTo(0, 0.5 * h)
    #   for i in [0..segment - 1]    
    #     val = (values[part * segment + i] + 1) / 2
    #     x = w * ((i % segment) / segment)
    #     y = val * 2 * h - h * 0.5
    #     @ctx.lineTo(x, y)
    #   @ctx.lineTo(w, 0.5 * h)
    #   @ctx.stroke()
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

Recorder = 
  recording : false
  rec : null
  audioChunks : []
  audio : null
  url : null
  slots : []
  currentSlot : 0
  init : () ->
    @slots = 
      for s in [0..Slots - 1]
        new Tone.Player().toMaster()
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

  ready : (url) ->
    # console.log @audio
    console.log "setting buffer"
    new Tone.Buffer(url, @bufferReady.bind(@))
  bufferReady : (b) ->
    @slots[@currentSlot].buffer = b

  togglePlayer : (e) ->
    s = $(e.currentTarget).parent().index()
    @slots[s].start()

  toggleRecord : (e) ->
    s = $(e.currentTarget).parent().index()
    if @recording
      @stop()

    if s isnt @currentSlot or not @recording
      @currentSlot = s
      @start()



init = () ->
  slots = 
    for s in [0..Slots - 1]
      record = $("<button>", 
        html : "R"
        click : Recorder.toggleRecord.bind(Recorder)
      )
      play = $("<button>", 
        html : "P"
        click : Recorder.togglePlayer.bind(Recorder)
      )
      
      buttons = [record, play]
      $("<div>",
        class : "button-row"
        html : buttons
      )

  $("#buttons").html slots

  Visual.init()
  Recorder.init()


init()
