import { common, Want } from '@kit.AbilityKit';
import { http } from '@kit.NetworkKit';
import util from '@ohos.util';
import { BaseReq, BaseResp, Log, LogLevel, SendAuthReq, SendAuthResp, WXApi, WXAPIFactory } from '@tencent/wechat_open_sdk';
import { HuaweiAccountPublicError } from './HuaweiAccountService';

export interface WechatLoginConfig {
  appId: string;
  exchangeUrl: string;
}

interface WechatTokenResponse {
  accessToken: string;
}

export function validWechatConfig(config: WechatLoginConfig): boolean {
  return /^wx[A-Za-z0-9]{16}$/.test(config.appId) &&
    /^https:\/\/[A-Za-z0-9.-]+(?::443)?\/[^\s?#]*$/.test(config.exchangeUrl);
}

export function validatedWechatCode(expectedState: string, state: string | undefined,
  code: string | undefined, errorCode: number): string {
  if (expectedState.length === 0 || state !== expectedState) {
    throw new HuaweiAccountPublicError('微信授权校验失败，请重新登录。');
  }
  if (errorCode === -2 || errorCode === -4) {
    throw new HuaweiAccountPublicError('已取消微信授权。');
  }
  if (errorCode !== 0 || code === undefined || !/^[A-Za-z0-9_-]{1,256}$/.test(code)) {
    throw new HuaweiAccountPublicError('微信授权失败，请重试。');
  }
  return code;
}

export class WechatAccountService {
  private api: WXApi | null = null;
  private state: string = '';
  private timer: number = -1;
  private resolve: ((code: string) => void) | null = null;
  private reject: ((error: Error) => void) | null = null;

  private readonly context: common.UIAbilityContext;
  constructor(context: common.UIAbilityContext) { this.context = context; }

  cancel(): void {
    const reject = this.reject;
    this.clear();
    if (reject !== null) reject(new HuaweiAccountPublicError('已取消微信登录，请重试。') as Error);
  }

  private clear(): void {
    if (this.timer >= 0) clearTimeout(this.timer);
    this.timer = -1;
    this.state = '';
    this.resolve = null;
    this.reject = null;
  }

  handleWant(want: Want): boolean {
    if (this.api === null || this.state.length === 0) return false;
    return this.api.handleWant(want, {
      onReq: (_request: BaseReq): void => {},
      onResp: (response: BaseResp): void => {
        if (!(response instanceof SendAuthResp)) return;
        const resolve = this.resolve;
        const reject = this.reject;
        try {
          const code = validatedWechatCode(this.state, response.state, response.code, response.errCode);
          this.clear();
          if (resolve !== null) resolve(code);
        } catch (error) {
          this.clear();
          if (reject !== null) reject(error as Error);
        }
      }
    });
  }

  async credential(config: WechatLoginConfig): Promise<string> {
    if (!validWechatConfig(config)) {
      throw new HuaweiAccountPublicError('微信登录暂未开通，请使用其他登录方式。');
    }
    if (this.state.length > 0) throw new HuaweiAccountPublicError('请先完成当前微信授权。');
    // SDK info logs include the raw authorization callback; do not send credentials to HiLog.
    Log.setLogImpl({ print: (_level: LogLevel, _tag: string, _message: string): void => {} });
    this.api = WXAPIFactory.createWXAPI(config.appId, this.context);
    this.api.setPayReportEnabled(false);
    if (!this.api.isWXAppInstalled()) throw new HuaweiAccountPublicError('请先安装微信，或使用其他登录方式。');
    this.state = util.generateRandomUUID(false);
    const request = new SendAuthReq();
    request.scope = 'snsapi_userinfo';
    request.state = this.state;
    request.callbackAbility = 'EntryAbility';
    const code = await new Promise<string>((resolve, reject) => {
      this.resolve = resolve;
      this.reject = reject;
      // Register the handler before sendReq: newer WeChat returns via the ability-result callback.
      this.handleWant({});
      this.timer = setTimeout(() => { this.cancel(); }, 120000);
      Promise.resolve(this.api!.sendReq(this.context, request)).then((sent: boolean) => {
        if (!sent) this.cancel();
      }).catch(() => { this.cancel(); });
    });
    const client = http.createHttp();
    try {
      const response = await client.request(config.exchangeUrl, {
        method: http.RequestMethod.POST,
        header: { 'Content-Type': 'application/json' },
        extraData: JSON.stringify({ code: code }),
        connectTimeout: 10000,
        readTimeout: 15000,
        usingCache: false
      });
      if (response.responseCode !== 200 || typeof response.result !== 'string' || response.result.length > 16384) {
        throw new Error('Invalid exchange response');
      }
      const data = JSON.parse(response.result) as WechatTokenResponse;
      if (typeof data.accessToken !== 'string' || !/^[A-Za-z0-9_+/=-]+\.[A-Za-z0-9_+/=-]+\.[A-Za-z0-9_-]+$/.test(data.accessToken)) {
        throw new Error('Missing credential');
      }
      return data.accessToken;
    } catch (_error) {
      throw new HuaweiAccountPublicError('微信登录服务暂不可用，请稍后重试。');
    } finally { client.destroy(); }
  }
}

let wechatService: WechatAccountService | null = null;
export function wechatAccountService(context: common.UIAbilityContext): WechatAccountService {
  if (wechatService === null) wechatService = new WechatAccountService(context);
  return wechatService;
}
export function handleWechatLoginWant(want: Want): boolean {
  return wechatService === null ? false : wechatService.handleWant(want);
}
export function cancelWechatLogin(): void {
  if (wechatService !== null) wechatService.cancel();
}
