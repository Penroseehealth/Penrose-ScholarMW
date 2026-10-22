/**
 * AudioWorklet that forwards live microphone PCM to the Flutter layer.
 *
 * Replaces the deprecated `ScriptProcessorNode`, which ran on the main thread,
 * could not be relied on to be pulled, and is on its way out of browsers. A
 * worklet runs on the audio rendering thread, so capture is not at the mercy of
 * UI jank.
 *
 * Every `process()` call posts a copy of the mono input block. The transfer
 * list hands the buffer over rather than copying it a second time, so the audio
 * thread does no allocation beyond the block the browser already gave it.
 *
 * The node deliberately outputs silence: the graph is only pulled while a node
 * reaches the destination, and a microphone must never reach the speakers.
 * Flutter wires it through a muted gain node for the same reason.
 */
class PcmTapProcessor extends AudioWorkletProcessor {
  constructor() {
    super();
    this._stopped = false;
    this.port.onmessage = (event) => {
      // The only message the UI sends is a stop request, so a live capture can
      // be ended without waiting for the next block boundary.
      if (event.data === 'stop') {
        this._stopped = true;
      }
    };
  }

  process(inputs, outputs) {
    if (this._stopped) {
      return false;
    }
    const input = inputs[0];
    if (!input || input.length === 0) {
      return true;
    }
    // Emit explicit silence. The graph is only pulled while a node reaches the
    // destination, and a microphone must never reach the speakers -- so the
    // output block is zeroed rather than copied from the input.
    const out = outputs[0];
    if (out) {
      for (let channel = 0; channel < out.length; channel++) {
        out[channel].fill(0);
      }
    }
    // Copy before transferring: the input block is owned by the browser and is
    // recycled after this call returns.
    const frame = new Float32Array(input[0]);
    this.port.postMessage(frame, [frame.buffer]);
    return true;
  }
}

registerProcessor('pcm-tap', PcmTapProcessor);
