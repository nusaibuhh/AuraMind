// ignore_for_file: avoid_web_libraries_in_flutter
import 'dart:js' as js;
import 'audio_engine_stub.dart';

class WebAudioEngine implements AudioEngine {
  bool _initialized = false;

  void _ensureInitialized() {
    if (_initialized) return;
    _initialized = true;

    // Inject Web Audio Synthesizer JavaScript functions into the window
    js.context.callMethod('eval', [r'''
(function() {
  if (window._auraMindAudio) return;

  var AudioCtx = window.AudioContext || window.webkitAudioContext;
  var ctx = null;
  var masterGain = null;
  var currentSource = null;
  var lfoTimer = null;
  var bowlTimer = null;
  var activeSound = 'silent';

  function initCtx() {
    if (!ctx) {
      ctx = new AudioCtx();
      masterGain = ctx.createGain();
      masterGain.gain.value = 0.7;
      masterGain.connect(ctx.destination);
    }
    if (ctx.state === 'suspended') {
      ctx.resume();
    }
  }

  function createPinkNoiseBuffer(context) {
    var bufferSize = context.sampleRate * 4;
    var buffer = context.createBuffer(1, bufferSize, context.sampleRate);
    var data = buffer.getChannelData(0);
    var b0 = 0, b1 = 0, b2 = 0, b3 = 0, b4 = 0, b5 = 0, b6 = 0;
    for (var i = 0; i < bufferSize; i++) {
      var white = Math.random() * 2.0 - 1.0;
      b0 = 0.99886 * b0 + white * 0.0555179;
      b1 = 0.99332 * b1 + white * 0.0750759;
      b2 = 0.96900 * b2 + white * 0.1538520;
      b3 = 0.86650 * b3 + white * 0.3104856;
      b4 = 0.55000 * b4 + white * 0.5329522;
      b5 = -0.7616 * b5 - white * 0.0168980;
      data[i] = (b0 + b1 + b2 + b3 + b4 + b5 + b6 + white * 0.5362) * 0.12;
      b6 = white * 0.115926;
    }
    return buffer;
  }

  function stopAmbient() {
    if (lfoTimer) { clearInterval(lfoTimer); lfoTimer = null; }
    if (bowlTimer) { clearInterval(bowlTimer); bowlTimer = null; }
    if (currentSource) {
      try {
        currentSource.gainNode.gain.setTargetAtTime(0.0001, ctx.currentTime, 0.1);
        setTimeout(function() {
          try { currentSource.source.stop(); } catch(e) {}
        }, 150);
      } catch(e) {}
      currentSource = null;
    }
  }

  function strikeSingingBowl() {
    if (!ctx) return;
    var now = ctx.currentTime;
    var harmonics = [432.0, 864.0, 1296.0, 1728.0];
    var weights = [0.4, 0.22, 0.12, 0.06];

    for (var i = 0; i < harmonics.length; i++) {
      var osc = ctx.createOscillator();
      var gain = ctx.createGain();
      osc.type = 'sine';
      osc.frequency.value = harmonics[i];

      gain.gain.setValueAtTime(weights[i], now);
      gain.gain.exponentialRampToValueAtTime(0.0001, now + 5.5);

      osc.connect(gain);
      gain.connect(masterGain);
      osc.start(now);
      osc.stop(now + 5.6);
    }
  }

  window._auraMindAudio = {
    start: function(soundId, vol) {
      initCtx();
      stopAmbient();
      activeSound = soundId;
      if (masterGain) masterGain.gain.setValueAtTime(vol, ctx.currentTime);

      if (soundId === 'silent') return;

      if (soundId === 'bowl') {
        strikeSingingBowl();
        bowlTimer = setInterval(function() {
          if (activeSound === 'bowl') strikeSingingBowl();
        }, 6000);
        return;
      }

      var buffer = createPinkNoiseBuffer(ctx);
      var src = ctx.createBufferSource();
      src.buffer = buffer;
      src.loop = true;

      var filter = ctx.createBiquadFilter();
      var gain = ctx.createGain();

      if (soundId === 'ocean') {
        filter.type = 'lowpass';
        filter.frequency.value = 350;
        filter.Q.value = 2.0;
        gain.gain.value = 0.35;

        var step = 0;
        lfoTimer = setInterval(function() {
          step++;
          var wave = (Math.sin(step * 0.1 * 2 * Math.PI / 4.8) + 1.0) / 2.0;
          filter.frequency.setTargetAtTime(160 + wave * 650, ctx.currentTime, 0.08);
          gain.gain.setTargetAtTime(0.15 + wave * 0.65, ctx.currentTime, 0.08);
        }, 100);
      } else if (soundId === 'rain') {
        filter.type = 'lowpass';
        filter.frequency.value = 1100;
        gain.gain.value = 0.45;
      } else if (soundId === 'forest') {
        filter.type = 'bandpass';
        filter.frequency.value = 900;
        filter.Q.value = 1.8;
        gain.gain.value = 0.40;

        var fStep = 0;
        lfoTimer = setInterval(function() {
          fStep++;
          filter.frequency.setTargetAtTime(880 + Math.sin(fStep * 0.5) * 80, ctx.currentTime, 0.1);
        }, 150);
      } else if (soundId === 'wind') {
        filter.type = 'lowpass';
        filter.frequency.value = 240;
        filter.Q.value = 2.5;
        gain.gain.value = 0.40;

        var wStep = 0;
        lfoTimer = setInterval(function() {
          wStep++;
          var wind = (Math.sin(wStep * 0.15) + 1.0) / 2.0;
          filter.frequency.setTargetAtTime(180 + wind * 140, ctx.currentTime, 0.18);
        }, 200);
      }

      src.connect(filter);
      filter.connect(gain);
      gain.connect(masterGain);
      src.start();

      currentSource = { source: src, filter: filter, gainNode: gain };
    },

    stop: function() {
      stopAmbient();
    },

    setVolume: function(vol) {
      if (masterGain && ctx) {
        masterGain.gain.setTargetAtTime(vol, ctx.currentTime, 0.05);
      }
    },

    chime: function(freq) {
      initCtx();
      if (!ctx || !masterGain) return;
      var now = ctx.currentTime;
      var osc1 = ctx.createOscillator();
      var osc2 = ctx.createOscillator();
      var gain = ctx.createGain();

      osc1.type = 'sine';
      osc1.frequency.value = freq;
      osc2.type = 'sine';
      osc2.frequency.value = freq * 2.0;

      gain.gain.setValueAtTime(0.35, now);
      gain.gain.exponentialRampToValueAtTime(0.0001, now + 0.9);

      osc1.connect(gain);
      osc2.connect(gain);
      gain.connect(masterGain);

      osc1.start(now);
      osc2.start(now);
      osc1.stop(now + 0.95);
      osc2.stop(now + 0.95);
    },

    chord: function() {
      initCtx();
      if (!ctx || !masterGain) return;
      var now = ctx.currentTime;
      var notes = [523.25, 659.25, 783.99];

      for (var i = 0; i < notes.length; i++) {
        var osc = ctx.createOscillator();
        var gain = ctx.createGain();
        osc.type = 'sine';
        osc.frequency.value = notes[i];

        gain.gain.setValueAtTime(0.28, now);
        gain.gain.exponentialRampToValueAtTime(0.0001, now + 2.2);

        osc.connect(gain);
        gain.connect(masterGain);

        osc.start(now);
        osc.stop(now + 2.3);
      }
    }
  };
})();
''']);
  }

  @override
  void startAmbient(String soundId, double volume) {
    try {
      _ensureInitialized();
      final audio = js.context['_auraMindAudio'];
      if (audio != null) {
        audio.callMethod('start', [soundId, volume]);
      }
    } catch (_) {}
  }

  @override
  void stopAmbient() {
    try {
      final audio = js.context['_auraMindAudio'];
      if (audio != null) {
        audio.callMethod('stop');
      }
    } catch (_) {}
  }

  @override
  void setVolume(double volume) {
    try {
      final audio = js.context['_auraMindAudio'];
      if (audio != null) {
        audio.callMethod('setVolume', [volume]);
      }
    } catch (_) {}
  }

  @override
  void playChime({double frequency = 528.0}) {
    try {
      _ensureInitialized();
      final audio = js.context['_auraMindAudio'];
      if (audio != null) {
        audio.callMethod('chime', [frequency]);
      }
    } catch (_) {}
  }

  @override
  void playCompletionChord() {
    try {
      _ensureInitialized();
      final audio = js.context['_auraMindAudio'];
      if (audio != null) {
        audio.callMethod('chord');
      }
    } catch (_) {}
  }

  @override
  void dispose() {
    stopAmbient();
  }
}

AudioEngine createAudioEngine() => WebAudioEngine();
