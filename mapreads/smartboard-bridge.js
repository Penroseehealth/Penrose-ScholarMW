// Small, platform-neutral bridge between the existing smartboard and its host.
(function (root) {
  function emit(name, payload) {
    const message = { source: 'mapreads-smartboard', name, payload };
    root.dispatchEvent(new CustomEvent('mapreads:event', { detail: message }));
    if (root.parent !== root) root.parent.postMessage(message, '*');
    const channel = root.flutter_inappwebview;
    if (channel && typeof channel.callHandler === 'function') {
      channel.callHandler('mapreadsEvent', message);
    }
  }

  function attach(api) {
    const generate = api.generate;
    api.generate = function (config) {
      const result = generate(config);
      emit('mapUpdated', api.getState());
      return result;
    };

    const pick = api.pick;
    api.pick = function (x, y) {
      const result = pick(x, y);
      emit('pointSelected', { x, y, state: api.getState() });
      return result;
    };

    const loadAnnotations = api.loadAnnotations;
    api.loadAnnotations = function (annotations) {
      const result = loadAnnotations(annotations);
      emit('annotationsChanged', { annotations: JSON.parse(api.annotations()) });
      return result;
    };

    root.MapReadsBridge = {
      emit,
      attach,
      request(name, payload) {
        return new Promise((resolve, reject) => {
          const id = `request-${Date.now()}-${Math.random()}`;
          const onResponse = event => {
            if (event.detail.id !== id) return;
            root.removeEventListener('mapreads:response', onResponse);
            if (event.detail.error) reject(new Error(event.detail.error));
            else resolve(event.detail.result);
          };
          root.addEventListener('mapreads:response', onResponse);
          root.dispatchEvent(new CustomEvent('mapreads:request', {
            detail: { id, name, payload }
          }));
        });
      }
    };
  }

  root.MapReadsBridge = { emit, attach };
})(window);
