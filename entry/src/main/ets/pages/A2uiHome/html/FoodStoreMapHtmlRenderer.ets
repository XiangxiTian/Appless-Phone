function escapeHtmlAttribute(value: string): string {
  return value
    .replace(/&/g, '&amp;')
    .replace(/"/g, '&quot;')
    .replace(/</g, '&lt;')
    .replace(/>/g, '&gt;');
}

export function renderFoodStoreMapHtml(amapKey: string): string {
  const key = escapeHtmlAttribute(amapKey.trim());
  return `<!DOCTYPE html>
<html lang="zh-CN">
<head>
<meta charset="UTF-8">
<meta name="viewport" content="width=device-width,initial-scale=1,maximum-scale=1,user-scalable=no">
<title>店铺地图</title>
<style>
html,body,#map{width:100%;height:100%;margin:0;overflow:hidden;background:#f2eee8;font-family:-apple-system,BlinkMacSystemFont,"HarmonyOS Sans SC",sans-serif}
.map-tools{position:absolute;z-index:20;left:12px;right:12px;top:12px;display:grid;gap:8px}
.map-search{display:flex;gap:7px;padding:7px;border-radius:15px;background:rgba(255,253,249,.96);box-shadow:0 4px 18px rgba(71,48,34,.18)}
.map-search input{min-width:0;flex:1;height:38px;border:0;outline:0;padding:0 11px;border-radius:10px;background:#f2eee8;color:#332821;font-size:14px}
.map-search button{width:58px;border:0;border-radius:10px;background:#397a62;color:#fff;font-size:13px;font-weight:700}
.channel-toggle{display:flex;align-items:center;gap:9px;width:100%;min-height:42px;padding:7px 10px;border:1px solid rgba(73,63,56,.1);border-radius:14px;background:rgba(255,253,249,.96);box-shadow:0 4px 18px rgba(71,48,34,.14);color:#5e4d43;text-align:left}
.channel-toggle-copy{min-width:0;flex:1}.channel-toggle-copy strong{display:block;font-size:13px}.channel-toggle-copy small{display:block;margin-top:2px;color:#8b7d73;font-size:10px}
.channel-switch{position:relative;width:42px;height:24px;flex:0 0 auto;border-radius:999px;background:#c7beb8}.channel-switch:after{content:'';position:absolute;left:3px;top:3px;width:18px;height:18px;border-radius:50%;background:#fff;box-shadow:0 1px 4px rgba(35,25,20,.25);transition:transform 150ms ease}.channel-toggle.active .channel-switch{background:#995f4c}.channel-toggle.active .channel-switch:after{transform:translateX(18px)}
.map-status{position:absolute;z-index:20;left:50%;top:116px;transform:translateX(-50%);max-width:calc(100% - 32px);padding:7px 12px;border-radius:999px;background:rgba(255,253,249,.94);box-shadow:0 3px 14px rgba(71,48,34,.15);color:#675d56;font-size:12px;white-space:nowrap;pointer-events:none}
.map-status.hidden{display:none}
.center-pin{position:absolute;z-index:12;left:50%;top:50%;width:27px;height:37px;transform:translate(-50%,-100%);pointer-events:none}.center-pin:before{content:'';display:block;width:24px;height:24px;border:3px solid #fff;border-radius:50% 50% 50% 0;transform:rotate(-45deg);background:#b45f49;box-shadow:0 4px 12px rgba(47,30,25,.3)}.center-pin:after{content:'';position:absolute;left:9px;top:8px;width:7px;height:7px;border-radius:50%;background:#fff}
.place-panel{position:absolute;z-index:20;left:12px;right:12px;bottom:12px;padding:13px;border-radius:17px;background:rgba(255,253,249,.97);box-shadow:0 7px 24px rgba(55,38,28,.2)}
.place-hint{color:#847970;font-size:11px}.place-name{min-height:25px;margin-top:4px;color:#332821;font-size:20px;font-weight:800;line-height:1.25}.place-address{min-height:18px;margin-top:3px;overflow:hidden;color:#756f66;font-size:12px;text-overflow:ellipsis;white-space:nowrap}.place-confirm{width:100%;height:43px;margin-top:10px;border:0;border-radius:11px;background:#a75d49;color:#fff;font-size:15px;font-weight:700}.place-confirm:disabled{opacity:.45}
.shop-marker{width:14px;height:14px;border:3px solid #fff;border-radius:50%;background:#995f4c;box-shadow:0 2px 9px rgba(79,45,32,.38),0 0 0 1px rgba(153,95,76,.32)}
.amap-info-content{padding:12px 14px!important;border-radius:14px!important}
.shop-info-card{box-sizing:border-box;width:220px;max-width:calc(100vw - 96px)}
.shop-info-name{overflow-wrap:anywhere;color:#2d221d;font-size:16px;font-weight:800;line-height:1.35}
.shop-info-detail{margin-top:5px;overflow-wrap:anywhere;color:#776d66;font-size:12px;line-height:1.45}
</style>
<script>window.forceWebGL = true;</script>
<script src="https://webapi.amap.com/maps?v=2.0&key=${key}"></script>
</head>
<body>
<div id="map"></div>
<div class="map-tools"><div class="map-search"><input id="keyword" placeholder="搜索地点，例如：深圳北站"><button id="searchButton">搜索</button></div><button id="channelToggle" class="channel-toggle" role="switch" aria-checked="false"><span class="channel-toggle-copy"><strong>只看渠道店铺</strong><small>关闭时显示高德默认地图信息</small></span><span class="channel-switch"></span></button></div>
<div id="status" class="map-status hidden"></div><div class="center-pin"></div>
<div class="place-panel"><div class="place-hint">移动地图或点击地图选择位置</div><div id="placeName" class="place-name">等待地图加载</div><div id="placeAddress" class="place-address"></div><button id="confirm" class="place-confirm" disabled>使用这个位置</button></div>
<script>
(function(){
  'use strict';
  var map = null;
  var markerById = Object.create(null);
  var pointById = Object.create(null);
  var pendingSnapshot = null;
  var lastSequence = -1;
  var centerApplied = false;
  var channelOnly = false;
  var infoWindow = null;
  var selected = null;
  var selectedName = '';
  var selectedAddress = '';
  var preserveNextName = false;
  var reverseTimer = 0;
  var jsonpSequence = 0;
  var statusNode = document.getElementById('status');

  function text(value){ return value === undefined || value === null ? '' : String(value); }
  function escapeHtml(value){ return text(value).replace(/[&<>"']/g,function(ch){ return {'&':'&amp;','<':'&lt;','>':'&gt;','"':'&quot;',"'":'&#39;'}[ch]; }); }
  function locationOf(point){
    var parts = text(point && point.location).split(',');
    if(parts.length !== 2){ return null; }
    var longitude = Number(parts[0]);
    var latitude = Number(parts[1]);
    if(!isFinite(longitude)||longitude < -180||longitude > 180||!isFinite(latitude)||latitude < -90||latitude > 90){ return null; }
    return [longitude, latitude];
  }
  function markerContent(point){
    return '<div class="shop-marker" aria-label="'+escapeHtml(point.name)+'"></div>';
  }
  function showInfo(point, marker){
    if(!map || !window.AMap){ return; }
    if(!infoWindow){ infoWindow = new AMap.InfoWindow({ offset:new AMap.Pixel(0,-24), closeWhenClickMap:true }); }
    var detail = [text(point.address), text(point.source)].filter(function(item){return item.length>0;}).join('<br>');
    infoWindow.setContent('<div class="shop-info-card"><div class="shop-info-name">'+escapeHtml(point.name)+'</div>'+(detail?'<div class="shop-info-detail">'+escapeHtml(detail).replace(/&lt;br&gt;/g,'<br>')+'</div>':'')+'</div>');
    infoWindow.open(map, marker.getPosition());
  }
  function setMarkerVisibility(marker, visible){ if(!map||!marker){return;} if(visible){map.add(marker);}else{map.remove(marker);} }
  function applyChannelMode(){
    if(!map){return;}
    map.setStatus({showLabel:true});
    map.setFeatures(channelOnly?['bg','road']:['bg','road','building','point']);
    Object.keys(markerById).forEach(function(id){setMarkerVisibility(markerById[id],channelOnly);});
    var toggle=document.getElementById('channelToggle');
    toggle.className='channel-toggle'+(channelOnly?' active':'');
    toggle.setAttribute('aria-checked',channelOnly?'true':'false');
    toggle.querySelector('small').textContent=channelOnly?'已隐藏高德 POI 与建筑，渠道结果增量更新中':'关闭时显示高德默认地图信息';
    var markers=Object.keys(markerById).map(function(id){return markerById[id];});
    statusNode.textContent=channelOnly&&markers.length===0?'当前结果暂无可用坐标':'';
    statusNode.className=channelOnly&&markers.length===0?'map-status':'map-status hidden';
  }
  function reconcile(snapshot){
    if(!map){ pendingSnapshot = snapshot; return; }
    var sequence = Number(snapshot && snapshot.sequence);
    if(isFinite(sequence) && sequence < lastSequence){ return; }
    if(isFinite(sequence)){ lastSequence = sequence; }
    var snapshotCenter = snapshot && snapshot.center;
    if(!centerApplied && snapshotCenter && isFinite(Number(snapshotCenter.longitude)) && isFinite(Number(snapshotCenter.latitude))){
      selectedName = text(snapshotCenter.name) || '地图中心点';
      selectedAddress = text(snapshotCenter.address);
      selected = {longitude:Number(snapshotCenter.longitude),latitude:Number(snapshotCenter.latitude)};
      preserveNextName = true;
      showSelection();
      document.getElementById('confirm').disabled=false;
      map.setCenter([Number(snapshotCenter.longitude),Number(snapshotCenter.latitude)]);
      centerApplied = true;
    }
    var desired = Object.create(null);
    var points = Array.isArray(snapshot && snapshot.points) ? snapshot.points : [];
    points.forEach(function(point){
      var id = text(point && point.id);
      var position = locationOf(point);
      if(!id || !position){ return; }
      desired[id] = true;
      var marker = markerById[id];
      var previous = pointById[id];
      if(!marker){
        marker = new AMap.Marker({ position:position, anchor:'center', content:markerContent(point), title:text(point.name), zIndex:120 });
        marker.on('click',function(){ showInfo(pointById[id], marker); });
        markerById[id] = marker;
        if(channelOnly){ map.add(marker); }
      } else {
        if(!previous || previous.location !== point.location){ marker.setPosition(position); }
        if(!previous || previous.name !== point.name){ marker.setContent(markerContent(point)); marker.setTitle(text(point.name)); }
      }
      pointById[id] = point;
    });
    Object.keys(markerById).forEach(function(id){
      if(desired[id]){ return; }
      map.remove(markerById[id]);
      delete markerById[id];
      delete pointById[id];
    });
    var markers = Object.keys(markerById).map(function(id){ return markerById[id]; });
    if(channelOnly && markers.length > 0){
      statusNode.className = 'map-status hidden';
    } else if(channelOnly) {
      statusNode.textContent = '当前结果暂无可用坐标'; statusNode.className = 'map-status';
      if(snapshotCenter && isFinite(Number(snapshotCenter.longitude)) && isFinite(Number(snapshotCenter.latitude))){ map.setCenter([Number(snapshotCenter.longitude),Number(snapshotCenter.latitude)]); }
    }
  }
  function post(payload){try{if(window.AIPhoneFoodStoreMap&&typeof AIPhoneFoodStoreMap.postMessage==='function'){AIPhoneFoodStoreMap.postMessage(JSON.stringify(payload));}}catch(_error){}}
  function jsonp(url,done){jsonpSequence+=1;var callbackName='__aiphoneFoodMapCallback'+jsonpSequence;var script=document.createElement('script');var finished=false;function cleanup(){if(script.parentNode){script.parentNode.removeChild(script);}try{delete window[callbackName];}catch(_error){window[callbackName]=undefined;}}window[callbackName]=function(payload){if(finished){return;}finished=true;cleanup();done(payload||null,'');};script.onerror=function(){if(finished){return;}finished=true;cleanup();done(null,'network_error');};script.src=url+'&output=JSON&callback='+encodeURIComponent(callbackName);document.head.appendChild(script);}
  function showSelection(){document.getElementById('placeName').textContent=selectedName||'地图选点';document.getElementById('placeAddress').textContent=selectedAddress;}
  function reverseGeocode(){if(!selected){return;}var location=selected.longitude.toFixed(6)+','+selected.latitude.toFixed(6);var url='https://restapi.amap.com/v3/geocode/regeo?extensions=all&radius=300&location='+encodeURIComponent(location)+'&key='+encodeURIComponent(${JSON.stringify(key)});jsonp(url,function(result,error){if(error||!result||String(result.status)!=='1'||!result.regeocode){document.getElementById('placeAddress').textContent='地点名称反查失败';return;}var regeocode=result.regeocode;var pois=Array.isArray(regeocode.pois)?regeocode.pois:[];selectedAddress=regeocode.formatted_address?String(regeocode.formatted_address):'';if(!selectedName||selectedName==='地图中心点'||selectedName==='地图点击位置'){selectedName=pois.length>0&&pois[0].name?String(pois[0].name):(selectedAddress||'地图选点');}showSelection();});}
  function updateSelection(name){if(!map){return;}var center=map.getCenter();selected={longitude:center.getLng(),latitude:center.getLat()};if(name){selectedName=name;}selectedAddress='';showSelection();document.getElementById('confirm').disabled=false;if(reverseTimer){clearTimeout(reverseTimer);}reverseTimer=setTimeout(reverseGeocode,350);}
  function searchPlace(){var keyword=document.getElementById('keyword').value.trim();if(!keyword){return;}document.getElementById('placeName').textContent='正在搜索…';var url='https://restapi.amap.com/v3/place/text?extensions=base&offset=1&page=1&keywords='+encodeURIComponent(keyword)+'&key='+encodeURIComponent(${JSON.stringify(key)});jsonp(url,function(result,error){var pois=result&&Array.isArray(result.pois)?result.pois:[];if(error||String(result&&result.status)!=='1'||pois.length===0||!pois[0].location){document.getElementById('placeName').textContent='没有找到该地点';return;}var poi=pois[0];var parts=String(poi.location).split(',');selectedName=String(poi.name||'地图选点');selectedAddress=String(poi.address||'');preserveNextName=true;map.setZoomAndCenter(17,[Number(parts[0]),Number(parts[1])]);});}
  window.__aiphoneApplyFoodMapSnapshot = function(snapshot){ pendingSnapshot = snapshot || {}; reconcile(pendingSnapshot); };
  window.__aiphoneDestroyFoodStoreMap = function(){ if(map){ map.destroy(); map = null; } };
  function initialize(){
    if(!window.AMap){ statusNode.textContent='地图服务加载失败'; statusNode.className='map-status'; return; }
    map = new AMap.Map('map',{ resizeEnable:true, viewMode:'2D', zoom:14, showLabel:true, features:['bg','road','building','point'] });
    map.on('complete',function(){applyChannelMode();if(!centerApplied){updateSelection('地图中心点');}});
    map.on('movestart',function(){if(!preserveNextName){selectedName='地图中心点';}});
    map.on('moveend',function(){updateSelection(preserveNextName?'':'地图中心点');preserveNextName=false;});
    map.on('click',function(event){selectedName='地图点击位置';preserveNextName=true;map.setCenter(event.lnglat);});
    document.getElementById('channelToggle').addEventListener('click',function(){channelOnly=!channelOnly;applyChannelMode();});
    document.getElementById('searchButton').addEventListener('click',searchPlace);
    document.getElementById('keyword').addEventListener('keydown',function(event){if(event.key==='Enter'){searchPlace();}});
    document.getElementById('confirm').addEventListener('click',function(){if(!selected){return;}post({type:'confirm',longitude:selected.longitude,latitude:selected.latitude,name:selectedName||'地图选点',address:selectedAddress});});
    if(pendingSnapshot){ reconcile(pendingSnapshot); }
  }
  if(document.readyState === 'loading'){ document.addEventListener('DOMContentLoaded',initialize); } else { initialize(); }
})();
</script>
</body>
</html>`;
}
