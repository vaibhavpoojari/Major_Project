import 'dart:js' as js;

void startPlatformBuzzer() {
  try {
    js.context.callMethod('eval', ["""
      if (window.buzzerInterval) clearInterval(window.buzzerInterval);
      var audioCtx = new (window.AudioContext || window.webkitAudioContext)();
      window.webAudioCtx = audioCtx;
      
      // Setup ticking buzzer alarm
      window.buzzerInterval = setInterval(function() {
        var osc = audioCtx.createOscillator();
        var gain = audioCtx.createGain();
        osc.connect(gain);
        gain.connect(audioCtx.destination);
        
        osc.type = 'sawtooth';
        osc.frequency.setValueAtTime(880, audioCtx.currentTime); // High pitch alarm beep
        gain.gain.setValueAtTime(0.2, audioCtx.currentTime);
        
        osc.start();
        setTimeout(function() {
          try { osc.stop(); } catch(e) {}
        }, 150);
      }, 300);
    """]);
  } catch (e) {
    print("BuzzerServiceWeb: Web Audio API synthesis failed: $e");
  }
}

void stopPlatformBuzzer() {
  try {
    js.context.callMethod('eval', ["""
      if (window.buzzerInterval) {
        clearInterval(window.buzzerInterval);
        window.buzzerInterval = null;
      }
      if (window.webAudioCtx) {
        try { window.webAudioCtx.close(); } catch(e) {}
        window.webAudioCtx = null;
      }
    """]);
  } catch (e) {
    print("BuzzerServiceWeb: Web Audio API stop failed: $e");
  }
}
