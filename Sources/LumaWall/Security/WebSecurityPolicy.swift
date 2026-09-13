import WebKit

enum WebSecurityPolicy {
  static func baseConfiguration() -> WKWebViewConfiguration {
    let config = WKWebViewConfiguration()
    config.websiteDataStore = .nonPersistent()
    config.preferences.javaScriptCanOpenWindowsAutomatically = false
    config.defaultWebpagePreferences.allowsContentJavaScript = true
    let bootstrap = """
      (() => {
        const listeners = new Map();
        const state = { paused:false, fps:60, renderScale:1, mouse:{x:.5,y:.5}, audio:{level:0,bass:0,mid:0,treble:0,spectrum:[]}, properties:{} };
        window.LumaWall = {
          state,
          on(type, cb){ if(!listeners.has(type)) listeners.set(type, []); listeners.get(type).push(cb); },
          postMessage(message){ window.webkit?.messageHandlers?.lumawall?.postMessage(message); },
          _receive(type, payload){ Object.assign(state, type === 'state' ? payload : {}); if(type==='mouse') state.mouse=payload; if(type==='audio') state.audio=payload; if(type==='properties') state.properties=payload; if(type==='pause') state.paused=true; if(type==='resume') state.paused=false; if(type==='fps') state.fps=payload; if(type==='scale') state.renderScale=payload; (listeners.get(type)||[]).forEach(fn=>{ try{fn(payload)}catch(e){} }); window.dispatchEvent(new CustomEvent('lumawall:'+type,{detail:payload})); },
          pause(){}, resume(){}, setFPS(){}, setRenderScale(){}, setMouse(){}
        };

        const nativeRAF = window.requestAnimationFrame.bind(window);
        const nativeCancelRAF = window.cancelAnimationFrame.bind(window);
        const callbacks = new Map();
        let nextRAF = 1;
        let masterRAF = 0;
        let lastDelivered = 0;
        function pump(timestamp) {
          masterRAF = 0;
          if (callbacks.size === 0) return;
          const minInterval = 1000 / Math.max(1, Number(state.fps) || 60);
          if (!state.paused && timestamp - lastDelivered >= minInterval - 0.5) {
            lastDelivered = timestamp;
            const batch = Array.from(callbacks.entries());
            callbacks.clear();
            for (const [, callback] of batch) { try { callback(timestamp); } catch (_) {} }
          }
          if (callbacks.size > 0) masterRAF = nativeRAF(pump);
        }
        window.requestAnimationFrame = callback => {
          const id = nextRAF++;
          callbacks.set(id, callback);
          if (!masterRAF) masterRAF = nativeRAF(pump);
          return id;
        };
        window.cancelAnimationFrame = id => {
          callbacks.delete(id);
          if (callbacks.size === 0 && masterRAF) {
            nativeCancelRAF(masterRAF);
            masterRAF = 0;
          }
        };
      })();
      """
    config.userContentController.addUserScript(
      WKUserScript(source: bootstrap, injectionTime: .atDocumentStart, forMainFrameOnly: false))
    return config
  }

  static func installNetworkBlocker(
    on controller: WKUserContentController, completion: @escaping (Bool) -> Void
  ) {
    let json = #"[{"trigger":{"url-filter":"^https?://"},"action":{"type":"block"}}]"#
    WKContentRuleListStore.default().compileContentRuleList(
      forIdentifier: "LumaWall.BlockRemoteNetwork.v1", encodedContentRuleList: json
    ) { list, error in
      DispatchQueue.main.async {
        if let list {
          controller.add(list)
          completion(true)
        } else {
          completion(false)
        }
      }
    }
  }
}
