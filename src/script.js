// Generated by CoffeeScript 2.3.2
var Mic, Player, Recorder, Slots, Visual, init;

Player = new Tone.Player().toMaster();

Mic = new Tone.UserMedia();

Visual = {
  mode: "wave", // "wave"
  waveform: null,
  micform: null,
  ctx: null,
  hsl: function(h, s, l, a) {
    return `hsl(${h * 360}, ${s * 100}%, ${l * 100}%, ${a})`;
  },
  loops: function(w, h) {
    var j, l, results, sh, sw;
    sw = w / 3;
    sh = h / 3;
    results = [];
    for (l = j = 0; j <= 8; l = ++j) {
      this.ctx.fillStyle = Looper.tracks[l].player.mute ? "#6244" : this.hsl(0.9 + Math.random() * 0.2, 0.8 + Math.random() * 0.1, 0.3, 0.2 + Math.random() * 0.2);
      results.push(this.ctx.fillRect((l % 3) * sw, Math.floor(l / 3) * sh, sw, sh));
    }
    return results;
  },
  drawWaveform: function(values) {
    var h, i, j, len, v, w, x, y;
    w = this.ctx.canvas.width;
    h = this.ctx.canvas.height;
    // @ctx.clearRect(0, 0, w, h)
    this.ctx.fillStyle = "#6244";
    this.ctx.fillRect(0, 0, w, h);
    if ((Map.current != null) && Map.current.isLooper()) {
      this.loops(w, h);
    }
    this.ctx.lineJoin = "bezel";
    this.ctx.strokeStyle = this.hsl(0.9 + Math.random() * 0.2, 0.8 + Math.random() * 0.1, 0.5, 0.5); // "d48"
    this.ctx.lineWidth = 1 + values[0] * (15 + Math.random() * 5);
    this.ctx.beginPath();
    this.ctx.moveTo(0, 0.5 * h);
// console.log values
    for (i = j = 0, len = values.length; j < len; i = ++j) {
      v = values[i];
      x = (i / values.length) * w;
      y = ((v + 1) / 2) * 2 * h - h * 0.5;
      this.ctx.lineTo(x, y);
    }
    this.ctx.lineTo(w, 0.5 * h);
    return this.ctx.stroke();
  },
  
  // segment = 128
  // for part in [0..7]
  //   @ctx.lineWidth = 1 + values[0] * (15 + Math.random() * 5)
  //   @ctx.strokeStyle = @hsl 0.9 + Math.random() * 0.2, 0.8 + Math.random() * 0.1, 0.5, 0.5 # "d48"
  //   @ctx.beginPath()
  //   @ctx.moveTo(0, 0.5 * h)
  //   for i in [0..segment - 1]    
  //     val = (values[part * segment + i] + 1) / 2
  //     x = w * ((i % segment) / segment)
  //     y = val * 2 * h - h * 0.5
  //     @ctx.lineTo(x, y)
  //   @ctx.lineTo(w, 0.5 * h)
  //   @ctx.stroke()
  draw: function() {
    this.drawWaveform(Recorder.recording ? this.micform.getValue() : this.waveform.getValue());
    return requestAnimationFrame(Visual.draw.bind(Visual));
  },
  write: function(text) {
    // if @mode is "text"
    return $("#text").html(text);
  },
  resize: function() {
    this.ctx.canvas.width = $("#screen").width();
    return this.ctx.canvas.height = $("#screen").height();
  },
  init: function() {
    if (this.mode === "wave") {
      this.waveform = new Tone.Waveform(256);
      this.micform = new Tone.Waveform(256);
      Tone.Master.fan(this.waveform);
      Mic.connect(this.micform);
      this.ctx = $("canvas").get(0).getContext("2d");
      $(window).resize(Visual.resize.bind(Visual));
      this.resize();
      return this.draw();
    }
  }
};

Slots = 6;

Recorder = {
  recording: false,
  rec: null,
  audioChunks: [],
  audio: null,
  url: null,
  slots: [],
  currentSlot: 0,
  init: function() {
    var s;
    return this.slots = (function() {
      var j, ref, results;
      results = [];
      for (s = j = 0, ref = Slots - 1; (0 <= ref ? j <= ref : j >= ref); s = 0 <= ref ? ++j : --j) {
        results.push(new Tone.Player().toMaster());
      }
      return results;
    })();
  },
  stop: function() {
    return this.rec.stop();
  },
  pushdata: function(e) {
    return this.audioChunks.push(e.data);
  },
  convertData: function() {
    var audioBlob;
    console.log("stopped recording");
    audioBlob = new Blob(this.audioChunks);
    this.url = URL.createObjectURL(audioBlob);
    // @audio = new Audio(@url)
    this.ready(this.url);
    return this.recording = false;
  },
  // audio.play()
  record: function(mic) {
    var stream;
    stream = mic._stream;
    this.recording = true;
    console.log("started recording");
    this.audioChunks = [];
    this.rec = new MediaRecorder(stream);
    this.rec.start();
    this.audioChunks = [];
    this.rec.addEventListener("dataavailable", this.pushdata.bind(this));
    return this.rec.addEventListener("stop", this.convertData.bind(this));
  },
  // setTimeout((() -> Recorder.rec.stop()),3000)
  start: function() {
    return Mic.open().then(this.record.bind(this));
  },
  // navigator.mediaDevices.getUserMedia({ audio: true })
  // .then(@record.bind(Recorder))
  ready: function(url) {
    // console.log @audio
    console.log("setting buffer");
    return new Tone.Buffer(url, this.bufferReady.bind(this));
  },
  bufferReady: function(b) {
    return this.slots[this.currentSlot].buffer = b;
  },
  togglePlayer: function(e) {
    var s;
    s = $(e.currentTarget).parent().index();
    return this.slots[s].start();
  },
  toggleLooping: function(s) {
    return this.slots[s].loop = !this.slots[s].loop;
  },
  toggleRecord: function(e) {
    var s;
    s = $(e.currentTarget).parent().index();
    if (this.recording) {
      this.stop();
    }
    if (s !== this.currentSlot || !this.recording) {
      this.currentSlot = s;
      return this.start();
    }
  }
};

init = function() {
  var buttons, looper, play, record, s, slots;
  slots = (function() {
    var j, ref, results;
    results = [];
    for (s = j = 0, ref = Slots - 1; (0 <= ref ? j <= ref : j >= ref); s = 0 <= ref ? ++j : --j) {
      record = $("<button>", {
        html: "R",
        class: "numpad",
        click: Recorder.toggleRecord.bind(Recorder)
      });
      play = $("<button>", {
        html: "P",
        class: "numpad",
        click: Recorder.togglePlayer.bind(Recorder)
      });
      looper = $("<button>", {
        html: "-",
        class: "numpad",
        click: function(e) {
          s = $(e.currentTarget).parent().index();
          Recorder.toggleLooping(s).bind(Recorder);
          return $(this).html(Recorder.slots[s].loop ? "[]" : "-");
        }
      });
      buttons = [record, play, looper];
      results.push($("<div>", {
        class: "buttonrow",
        html: buttons
      }));
    }
    return results;
  })();
  $("#buttons").html(slots);
  Visual.init();
  return Recorder.init();
};

init();

//# sourceMappingURL=script.js.map