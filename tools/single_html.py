"""Empaqueta el build web de Godot (index.html + js + wasm + pck + worklets) en UN solo .html.

El .wasm y el .pck van comprimidos con gzip y en base64 dentro de etiquetas <script type="application/x-gz-b64">.
Un pequeño cargador intercepta fetch() y audioWorklet.addModule() para servir esos archivos desde memoria,
así el juego funciona con doble clic (file://) o subido a cualquier hosting estático, sin servidor especial.
"""
import base64, gzip, sys, os, re

src, out = sys.argv[1], sys.argv[2]
R = lambda f, m='r': open(os.path.join(src, f), m, **({} if 'b' in m else {'encoding': 'utf8'})).read()
html = R('index.html')

def b64(f):
    return base64.b64encode(R(f, 'rb')).decode()

def gzb64(f):
    return base64.b64encode(gzip.compress(R(f, 'rb'), 9)).decode()

# Iconos y splash como data URI
for f in ['index.icon.png', 'index.apple-touch-icon.png', 'index.png']:
    html = html.replace(f'"{f}"', f'"data:image/png;base64,{b64(f)}"')

CHUNK = 8 * 1024 * 1024  # varias etiquetas de 8 MB: el navegador las procesa sin problema
def blocks(name, data):
    parts = [data[i:i + CHUNK] for i in range(0, len(data), CHUNK)]
    return ''.join(f'<script type="application/x-gz-b64" data-file="{name}" data-part="{i}">{p}</script>\n' for i, p in enumerate(parts))

payload = blocks('index.wasm', gzb64('index.wasm')) + blocks('index.pck', gzb64('index.pck'))

loader = r"""<script>
// ---- Cargador de un solo archivo: sirve index.wasm, index.pck y los worklets de audio desde este HTML ----
(function () {
  const TYPES = { 'index.wasm': 'application/wasm', 'index.pck': 'application/octet-stream' };
  const WORKLETS = {
    'index.audio.worklet.js': %AW%,
    'index.audio.position.worklet.js': %APW%,
  };
  const cache = {};
  function partsOf(name) {
    return Array.from(document.querySelectorAll('script[type="application/x-gz-b64"][data-file="' + name + '"]'))
      .sort((a, b) => a.dataset.part - b.dataset.part);
  }
  async function bytes(name) {
    if (!cache[name]) cache[name] = (async () => {
      // base64 -> bytes con el decodificador nativo (fetch de data: URL), por partes
      const bufs = [];
      for (const el of partsOf(name)) {
        const t = el.textContent.trim();
        let buf;
        try {
          buf = await (await _fetch('data:application/octet-stream;base64,' + t)).arrayBuffer();
        } catch (e) {
          // respaldo: decodificar base64 a mano (navegadores que no permiten fetch de data:)
          const bin = atob(t); const u = new Uint8Array(bin.length);
          for (let i = 0; i < bin.length; i++) u[i] = bin.charCodeAt(i);
          buf = u.buffer;
        }
        bufs.push(buf);
        el.textContent = '';   // libera memoria
      }
      const gz = new Blob(bufs);
      try {
        if (!window.DecompressionStream) throw new Error('sin DecompressionStream');
        return await new Response(gz.stream().pipeThrough(new DecompressionStream('gzip'))).blob();
      } catch (e) {
        // respaldo: descompresor en JavaScript (fflate) para navegadores antiguos
        return new Blob([fflate.gunzipSync(new Uint8Array(await gz.arrayBuffer()))]);
      }
    })();
    return cache[name];
  }
  const _fetch = window.fetch.bind(window);
  window.fetch = async function (input, init) {
    const url = typeof input === 'string' ? input : (input && input.url) || '';
    const name = url.split('?')[0].split('/').pop();
    if (TYPES[name]) {
      const blob = await bytes(name);
      return new Response(blob, { status: 200, headers: { 'Content-Type': TYPES[name], 'Content-Length': String(blob.size) } });
    }
    return _fetch(input, init);
  };
  const urls = {};
  // data: URL (no blob:) para que los worklets de audio carguen también al abrir el archivo con doble clic (file://)
  for (const k in WORKLETS) urls[k] = 'data:text/javascript;base64,' + btoa(unescape(encodeURIComponent(WORKLETS[k])));
  try {
    if (location.protocol === 'file:' && navigator.serviceWorker)
      navigator.serviceWorker.getRegistration = () => Promise.resolve(undefined);
  } catch (e) {}
  if (window.AudioWorklet) {
    const add = AudioWorklet.prototype.addModule;
    AudioWorklet.prototype.addModule = function (path, opts) {
      const name = String(path).split('?')[0].split('/').pop();
      return add.call(this, urls[name] || path, opts);
    };
  }
})();
</script>
"""
import json
loader = loader.replace('%AW%', json.dumps(R('index.audio.worklet.js'))).replace('%APW%', json.dumps(R('index.audio.position.worklet.js')))

pre = open(os.path.join(os.path.dirname(os.path.abspath(__file__)), 'pre.html'), encoding='utf8').read().replace('%FFLATE%', open(os.path.join(os.path.dirname(os.path.abspath(__file__)), 'fflate.min.js'), encoding='utf8').read().replace('</script', '<\\/script'))
engine_js = R('index.js').replace('</script', '<\\/script')
html = html.replace('<script src="index.js"></script>', pre + payload + loader + '<script>\n' + engine_js + '\n</script>')
# Sin service worker ni comprobación de aislamiento: la build es de un solo hilo y no los necesita
html = html.replace('"ensureCrossOriginIsolationHeaders":true', '"ensureCrossOriginIsolationHeaders":false')
open(out, 'w', encoding='utf8').write(html)
print('ok', out, round(os.path.getsize(out) / 1e6, 1), 'MB')
