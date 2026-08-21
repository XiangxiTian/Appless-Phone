import { describe, it, expect } from '@ohos/hypium';
import { A2uiFoodData, A2uiSurfaceState } from '@loop/agent-core';
import {
  buildFoodStoreMapSnapshot,
  validFoodStoreLocation
} from '../main/ets/pages/A2uiHome/FoodStoreMapSnapshot';
import { favoriteFromFood } from '../main/ets/pages/A2uiHome/FoodFavoritesStore';
import { renderFoodStoreMapHtml } from '../main/ets/pages/A2uiHome/html/FoodStoreMapHtmlRenderer';

interface FoodMapTestModel {
  foods: A2uiFoodData[];
}

function foodSurface(): A2uiSurfaceState {
  const foods: A2uiFoodData[] = [{
    name: '有坐标门店',
    category: '餐饮',
    address: '深圳市龙岗区',
    distance: '200米',
    longitude: 114.063873,
    latitude: 22.631273,
    sourceTags: ['高德', '腾讯地图']
  }, {
    name: '无坐标门店',
    category: '餐饮',
    address: '深圳市龙华区',
    distance: '500米'
  }, {
    name: '非法坐标门店',
    category: '餐饮',
    address: '深圳市南山区',
    distance: '900米',
    location: 'not-a-coordinate'
  }];
  const model: FoodMapTestModel = { foods: foods };
  return {
    surfaceId: 'food-map-test',
    rootId: 'root',
    title: '附近餐饮',
    intent: 'food',
    status: 'ready',
    components: [{
      id: 'foods',
      component: 'FoodChoices',
      dataPath: '/foods'
    }],
    dataModelJson: JSON.stringify(model),
    error: '',
    sequence: 7
  };
}

export default function foodStoreMapTest() {
  describe('FoodStoreMap', () => {
    it('keeps coordinates optional and only creates valid map points', 0, () => {
      const snapshot = buildFoodStoreMapSnapshot(foodSurface(), 114.06, 22.63, '华为 D 区', '深圳市龙岗区');

      expect(snapshot.sequence).assertEqual(7);
      expect(snapshot.center.name).assertEqual('华为 D 区');
      expect(snapshot.center.address).assertEqual('深圳市龙岗区');
      expect(snapshot.points.length).assertEqual(1);
      expect(snapshot.points[0].name).assertEqual('有坐标门店');
      expect(snapshot.points[0].source).assertEqual('高德 · 腾讯地图');
      expect(snapshot.points[0].id.startsWith('food:')).assertTrue();
      expect(validFoodStoreLocation(undefined)).assertEqual('');
      expect(validFoodStoreLocation('181,22')).assertEqual('');
    });

    it('preserves coordinate-only food data when creating a favorite', 0, () => {
      const favorite = favoriteFromFood({
        name: '仅外层坐标门店',
        category: '餐饮',
        address: '深圳市福田区',
        distance: '300米',
        longitude: 114.057868,
        latitude: 22.543099
      });

      expect(favorite.longitude).assertEqual(114.057868);
      expect(favorite.latitude).assertEqual(22.543099);
      expect(favorite.location).assertUndefined();
    });

    it('renders a clean channel-only map with road labels and dot-only store markers', 0, () => {
      const html = renderFoodStoreMapHtml('test-key');

      expect(html.indexOf('window.forceWebGL = true')).assertLarger(-1);
      expect(html.indexOf('window.forceWebGL = true') < html.indexOf('webapi.amap.com/maps')).assertTrue();
      expect(html.indexOf("showLabel:true")).assertLarger(-1);
      expect(html.indexOf("viewMode:'2D'")).assertLarger(-1);
      expect(html.indexOf("setStatus({showLabel:true})")).assertLarger(-1);
      expect(html.indexOf("var channelOnly = false")).assertLarger(-1);
      expect(html.indexOf("zoom:14, showLabel:true, features:['bg','road','building','point']")).assertLarger(-1);
      expect(html.indexOf('class="channel-toggle"')).assertLarger(-1);
      expect(html.indexOf('aria-checked="false"')).assertLarger(-1);
      expect(html.indexOf("channelOnly?['bg','road']")).assertLarger(-1);
      expect(html.indexOf("['bg','road','building','point']")).assertLarger(-1);
      expect(html.indexOf('shop-marker-name')).assertEqual(-1);
      expect(html.indexOf("anchor:'center'")).assertLarger(-1);
      expect(html.indexOf('.shop-info-card')).assertLarger(-1);
      expect(html.indexOf('width:220px')).assertLarger(-1);
      expect(html.indexOf('shop-info-name')).assertLarger(-1);
      expect(html.indexOf('channelToggle')).assertLarger(-1);
      expect(html.indexOf('只看渠道店铺')).assertLarger(-1);
      expect(html.indexOf('class="coord"')).assertEqual(-1);
      expect(html.indexOf('id="coord"')).assertEqual(-1);
      expect(html.indexOf('.place-name')).assertLarger(-1);
      expect(html.indexOf('font-size:20px')).assertLarger(-1);
      expect(html.indexOf('__aiphoneApplyFoodMapSnapshot')).assertLarger(-1);
      expect(html.indexOf('markerById')).assertLarger(-1);
      expect(html.indexOf('selectedName = text(snapshotCenter.name)')).assertLarger(-1);
      expect(html.indexOf('selectedAddress = text(snapshotCenter.address)')).assertLarger(-1);
      expect(html.indexOf('if(channelOnly&&markers.length>0&&!fittedOnce)')).assertEqual(-1);
      expect(html.indexOf('map.setFitView')).assertEqual(-1);
      expect(html.indexOf("if(!window.AMap){ statusNode.textContent='地图服务加载失败'; statusNode.className='map-status'; return; }")).assertLarger(-1);
    });
  });
}
