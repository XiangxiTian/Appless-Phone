import assert from 'node:assert/strict';
import { readFileSync } from 'node:fs';

const gateway = readFileSync('agent_core/src/main/ets/aiphone/runtime/ToolGatewayClient.ets', 'utf8');
const home = readFileSync('entry/src/main/ets/pages/A2uiHome/Index.ets', 'utf8');
const tag = '[AIPhone][LuckinOrderTrace]';

assert.match(gateway, /const LUCKIN_ORDER_TRACE_TAG: string = '\[AIPhone\]\[LuckinOrderTrace\]'/);
assert.match(home, /\[AIPhone\]\[LuckinOrderTrace\] stage=dispatch result=received toolId=/);

for (const stage of [
  'gateway_dispatch', 'blocked', 'error', 'preview_start', 'location_validation',
  'shop_query', 'awaiting_shop_selection', 'selected_shop', 'product_search_query',
  'product_query', 'prompt_preferences', 'preview_order', 'preview_ready',
  'create_start', 'create_validation', 'create_order', 'create_ready',
  'status_start', 'status_validation', 'status_provider', 'status_ready'
]) {
  assert.ok(gateway.includes(`luckinTrace('${stage}'`), `${tag} must retain stage=${stage}`);
}

assert.doesNotMatch(gateway, /LuckinOrder(Create|Status)[^\n]*orderId=/);
assert.doesNotMatch(gateway, /LuckinOrderCreateMissingPay[^\n]*payloadPreview=/);
console.log('Luckin order trace source contract passed.');
