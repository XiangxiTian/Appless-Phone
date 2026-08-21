export interface FoodLocationPickerHtmlOptions {
  amapKey: string;
  amapSecurityJsCode: string;
  initialLongitude: number;
  initialLatitude: number;
}

function jsonString(value: string): string {
  return JSON.stringify(value).split('<').join('\\u003c');
}

export function renderFoodLocationPickerHtml(options: FoodLocationPickerHtmlOptions): string {
  const key = options.amapKey.trim();
  const securityScript = options.amapSecurityJsCode.trim().length > 0 ?
    'window._AMapSecurityConfig={securityJsCode:' + jsonString(options.amapSecurityJsCode.trim()) + '};' : '';
  const scriptUrl = 'https://webapi.amap.com/maps?v=2.0&key=' + encodeURIComponent(key);
  const mapScript = key.length > 0 ? '<script src="' + scriptUrl + '"></script>' : '';

  return `<!DOCTYPE html>
<html lang="zh-CN">
<head>
  <meta charset="UTF-8">
  <meta name="viewport" content="width=device-width,initial-scale=1,maximum-scale=1,user-scalable=no">
  <title>选择地址</title>
  <style>
    * { box-sizing: border-box; }
    html, body, #map { width: 100%; height: 100%; margin: 0; }
    body { overflow: hidden; background: #f4f1eb; color: #211f1b; font-family: -apple-system, BlinkMacSystemFont, "PingFang SC", sans-serif; }
    #map { position: absolute; inset: 0; }
    .search { position: absolute; left: 14px; right: 14px; top: 14px; z-index: 5; display: flex; gap: 8px; padding: 8px; border-radius: 16px; background: rgba(255,255,255,.96); box-shadow: 0 8px 24px rgba(31,28,24,.18); }
    .search input { min-width: 0; flex: 1; height: 40px; border: 0; outline: 0; padding: 0 12px; border-radius: 11px; background: #f3f0ea; font-size: 15px; }
    .search button, .confirm { border: 0; border-radius: 11px; font-weight: 700; }
    .search button { width: 64px; color: #fff; background: #397a62; }
    .results { position: absolute; left: 14px; right: 14px; top: 78px; z-index: 6; display: none; max-height: 42%; overflow-y: auto; padding: 6px; border-radius: 16px; background: rgba(255,255,255,.98); box-shadow: 0 8px 24px rgba(31,28,24,.18); }
    .result { width: 100%; padding: 11px 12px; border: 0; border-bottom: 1px solid #ece7df; text-align: left; background: transparent; }
    .result:last-child { border-bottom: 0; }
    .result-name { display: block; overflow: hidden; color: #27231f; font-size: 15px; font-weight: 700; text-overflow: ellipsis; white-space: nowrap; }
    .result-address { display: block; overflow: hidden; margin-top: 3px; color: #777066; font-size: 12px; text-overflow: ellipsis; white-space: nowrap; }
    .pin { position: absolute; z-index: 4; left: 50%; top: 50%; width: 28px; height: 38px; transform: translate(-50%,-100%); pointer-events: none; }
    .pin:before { content: ''; display: block; width: 25px; height: 25px; border: 3px solid #fff; border-radius: 50% 50% 50% 0; transform: rotate(-45deg); background: #b45f49; box-shadow: 0 4px 12px rgba(47,30,25,.3); }
    .pin:after { content: ''; position: absolute; left: 9px; top: 8px; width: 7px; height: 7px; border-radius: 50%; background: #fff; }
    .panel { position: absolute; z-index: 5; left: 14px; right: 14px; bottom: 16px; padding: 14px; border-radius: 18px; background: rgba(255,255,255,.97); box-shadow: 0 8px 26px rgba(31,28,24,.2); }
    .hint { color: #706a62; font-size: 12px; }
    .name { min-height: 25px; margin-top: 5px; color: #37322d; font-size: 20px; font-weight: 800; line-height: 1.25; }
    .address { min-height: 18px; margin-top: 2px; overflow: hidden; color: #756f66; font-size: 12px; text-overflow: ellipsis; white-space: nowrap; }
    .confirm { width: 100%; height: 46px; margin-top: 12px; color: #fff; background: #a75d49; font-size: 16px; }
    .confirm:disabled { opacity: .45; }
    .error { position: absolute; z-index: 8; inset: 0; display: none; padding: 28px; align-items: center; justify-content: center; text-align: center; background: #f6f1e9; color: #983f32; font-size: 14px; line-height: 1.7; }
  </style>
  <script>${securityScript}</script>
  ${mapScript}
</head>
<body>
  <div id="map"></div>
  <div class="search"><input id="keyword" placeholder="搜索地点，例如：深圳北站"><button id="searchButton">搜索</button></div>
  <div class="results" id="results"></div>
  <div class="pin"></div>
  <div class="panel">
    <div class="hint">移动地图或点击地图选择圆心</div>
    <div class="name" id="name">等待地图加载</div>
    <div class="address" id="address"></div>
    <button class="confirm" id="confirm" disabled>使用这个位置</button>
  </div>
  <div class="error" id="error"></div>
  <script>
    (function () {
      var selected = null;
      var selectedName = '';
      var selectedAddress = '';
      var reverseTimer = 0;
      var jsonpSequence = 0;
      var preserveNextName = false;
      function post(payload) {
        var deliveredToParent = false;
        try {
          if (window.parent && window.parent !== window) {
            if (typeof window.parent.AIPhoneFoodLocationPickerBridge === 'function') {
              window.parent.AIPhoneFoodLocationPickerBridge(payload);
            } else {
              window.parent.postMessage({ source: 'AIPhoneFoodLocationPicker', payload: payload }, '*');
            }
            deliveredToParent = true;
          }
        } catch (_parentError) {}
        try {
          if (!deliveredToParent && window.AIPhoneFoodLocationPicker &&
            typeof AIPhoneFoodLocationPicker.postMessage === 'function') {
            AIPhoneFoodLocationPicker.postMessage(JSON.stringify(payload));
          }
        } catch (_error) {}
      }
      function fail(message) {
        var node = document.getElementById('error');
        node.textContent = message;
        node.style.display = 'flex';
        post({ type: 'loadError', message: message });
      }
      function jsonp(url, done) {
        jsonpSequence += 1;
        var callbackName = '__aiphoneAmapCallback' + jsonpSequence;
        var script = document.createElement('script');
        var finished = false;
        function cleanup() {
          if (script.parentNode) script.parentNode.removeChild(script);
          try { delete window[callbackName]; } catch (_error) { window[callbackName] = undefined; }
        }
        window[callbackName] = function (payload) {
          if (finished) return;
          finished = true;
          cleanup();
          done(payload || null, '');
        };
        script.onerror = function () {
          if (finished) return;
          finished = true;
          cleanup();
          done(null, 'network_error');
        };
        script.src = url + '&output=JSON&callback=' + encodeURIComponent(callbackName);
        document.head.appendChild(script);
      }
      if (!${key.length > 0 ? 'true' : 'false'}) {
        fail('没有配置高德 JS API Key');
        return;
      }
      if (!window.AMap) {
        fail('高德地图加载失败，请检查 JS API Key、securityJsCode 或网络。');
        return;
      }
      var map = new AMap.Map('map', {
        viewMode: '2D',
        zoom: 15,
        center: [${options.initialLongitude}, ${options.initialLatitude}]
      });
      function showSelection() {
        document.getElementById('name').textContent = selectedName || '地图选点';
        document.getElementById('address').textContent = selectedAddress;
      }
      function reverseGeocode() {
        if (!selected) return;
        var location = selected.longitude.toFixed(6) + ',' + selected.latitude.toFixed(6);
        var url = 'https://restapi.amap.com/v3/geocode/regeo?extensions=all&radius=300&location=' +
          encodeURIComponent(location) + '&key=' + encodeURIComponent(${jsonString(key)});
        jsonp(url, function (result, error) {
          if (error || !result || String(result.status) !== '1' || !result.regeocode) {
            document.getElementById('address').textContent = '地点名称反查失败';
            post({ type: 'regeoError', message: error || (result && result.info) || 'invalid_response' });
            return;
          }
          var regeocode = result.regeocode;
          var pois = Array.isArray(regeocode.pois) ? regeocode.pois : [];
          var poiName = pois.length > 0 && pois[0].name ? String(pois[0].name) : '';
          selectedAddress = regeocode.formatted_address ? String(regeocode.formatted_address) : '';
          if (!selectedName || selectedName === '地图中心点' || selectedName === '地图点击位置') {
            selectedName = poiName || selectedAddress || '地图选点';
          }
          showSelection();
          post({ type: 'reverseGeocode', longitude: selected.longitude, latitude: selected.latitude,
            name: selectedName, address: selectedAddress });
        });
      }
      function scheduleReverseGeocode() {
        if (reverseTimer) window.clearTimeout(reverseTimer);
        reverseTimer = window.setTimeout(reverseGeocode, 350);
      }
      function update(name) {
        var center = map.getCenter();
        selected = { longitude: center.getLng(), latitude: center.getLat() };
        if (typeof name === 'string' && name.length > 0) selectedName = name;
        selectedAddress = '';
        showSelection();
        document.getElementById('confirm').disabled = false;
        post({ type: 'selectionChanged', longitude: selected.longitude, latitude: selected.latitude, name: selectedName });
        scheduleReverseGeocode();
      }
      map.on('complete', function () { update('地图中心点'); });
      map.on('movestart', function () {
        if (!preserveNextName) selectedName = '地图中心点';
      });
      map.on('moveend', function () {
        update(preserveNextName ? '' : '地图中心点');
        preserveNextName = false;
      });
      map.on('click', function (event) {
        selectedName = '地图点击位置';
        preserveNextName = true;
        map.setCenter(event.lnglat);
      });
      document.getElementById('confirm').addEventListener('click', function () {
        if (!selected) return;
        post({ type: 'confirm', longitude: selected.longitude, latitude: selected.latitude,
          name: selectedName || '地图选点', address: selectedAddress });
      });
      function hideResults() {
        var node = document.getElementById('results');
        node.style.display = 'none';
        node.innerHTML = '';
      }
      function showResults(pois) {
        var node = document.getElementById('results');
        node.innerHTML = '';
        pois.forEach(function (poi) {
          if (!poi || !poi.location) return;
          var parts = String(poi.location).split(',');
          if (parts.length !== 2) return;
          var lng = Number(parts[0]);
          var lat = Number(parts[1]);
          if (!Number.isFinite(lng) || !Number.isFinite(lat)) return;
          var button = document.createElement('button');
          button.type = 'button';
          button.className = 'result';
          var title = document.createElement('span');
          title.className = 'result-name';
          title.textContent = poi.name || '未命名地点';
          var subtitle = document.createElement('span');
          subtitle.className = 'result-address';
          subtitle.textContent = poi.address || poi.pname || poi.cityname || '';
          button.appendChild(title);
          button.appendChild(subtitle);
          button.addEventListener('click', function () {
            selectedName = String(poi.name || '地图选点');
            selectedAddress = String(poi.address || '');
            preserveNextName = true;
            hideResults();
            map.setZoomAndCenter(17, [lng, lat]);
          });
          node.appendChild(button);
        });
        node.style.display = node.children.length > 0 ? 'block' : 'none';
      }
      document.getElementById('searchButton').addEventListener('click', function () {
        var keyword = document.getElementById('keyword').value.trim();
        if (!keyword) return;
        document.getElementById('name').textContent = '正在搜索…';
        document.getElementById('address').textContent = '';
        hideResults();
        var url = 'https://restapi.amap.com/v3/place/text?extensions=base&offset=10&page=1&keywords=' +
          encodeURIComponent(keyword) + '&key=' + encodeURIComponent(${jsonString(key)});
        jsonp(url, function (result, error) {
          var pois = result && Array.isArray(result.pois) ? result.pois : [];
          if (error || !result || String(result.status) !== '1' || pois.length === 0) {
            document.getElementById('name').textContent = '没有找到该地点';
            post({ type: 'searchError', message: error || (result && result.info) || 'no_result' });
            return;
          }
          showResults(pois);
          document.getElementById('name').textContent = '请选择一个搜索结果';
          post({ type: 'searchResults', count: pois.length });
        });
      });
      document.getElementById('keyword').addEventListener('keydown', function (event) {
        if (event.key === 'Enter') document.getElementById('searchButton').click();
      });
      post({ type: 'ready' });
    })();
  </script>
</body>
</html>`;
}
