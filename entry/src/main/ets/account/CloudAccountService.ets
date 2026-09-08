import { common } from '@kit.AbilityKit';
import util from '@ohos.util';
import { hilog } from '@kit.PerformanceAnalysisKit';
import { BusinessError } from '@kit.BasicServicesKit';
import auth, { AuthUser, CredentialInfo, VerifyCodeAction } from '@hw-agconnect/auth';
import { HuaweiAccountPublicError } from './HuaweiAccountService';
import { WechatLoginConfig, wechatAccountService } from './WechatAccountService';

export interface CloudAccountIdentity {
  uid: string;
  displayName: string;
}

export interface CloudAccountService {
  requestPhoneCode(phone: string): Promise<number>;
  loginPhone(phone: string, code: string): Promise<CloudAccountIdentity>;
  loginWechat(): Promise<CloudAccountIdentity>;
  loginHuawei(): Promise<CloudAccountIdentity>;
  restore(): Promise<CloudAccountIdentity | null>;
  linkPhone(uid: string, phone: string, code: string): Promise<CloudAccountIdentity>;
  linkWechat(uid: string): Promise<CloudAccountIdentity>;
  signOut(): Promise<void>;
}

export function validatedPhone(phone: string): string {
  const normalized = phone.trim();
  if (!/^1[3-9][0-9]{9}$/.test(normalized)) {
    throw new HuaweiAccountPublicError('请输入正确的中国大陆手机号。');
  }
  return normalized;
}
export function validatedPhoneCode(code: string): string {
  const normalized = code.trim();
  if (!/^[0-9]{4,8}$/.test(normalized)) throw new HuaweiAccountPublicError('请输入短信验证码。');
  return normalized;
}

function identity(user: AuthUser): CloudAccountIdentity {
  const uid = user.getUid();
  if (typeof uid !== 'string' || uid.trim().length === 0 || uid.length > 1024 || user.isAnonymous()) {
    throw new HuaweiAccountPublicError('账号验证失败，请重新登录。');
  }
  return { uid: uid, displayName: user.getDisplayName() || 'Appless 用户' };
}

export class AgcCloudAccountService implements CloudAccountService {
  private initialized: boolean = false;
  private readonly context: common.Context;
  constructor(context: common.Context) { this.context = context; }

  private initialize(): void {
    if (this.initialized) return;
    try {
      const bytes = this.context.resourceManager.getRawFileContentSync('agconnect-services.json');
      auth.init(this.context, util.TextDecoder.create('utf-8').decodeToString(bytes));
      this.initialized = true;
    } catch (_error) {
      throw new HuaweiAccountPublicError('手机号登录暂不可用，请使用华为账号。');
    }
  }

  async requestPhoneCode(phone: string): Promise<number> {
    const normalized = validatedPhone(phone);
    this.initialize();
    const result = await auth.requestVerifyCode({
      verifyCodeType: { kind: 'phone', countryCode: '86', phoneNumber: normalized },
      action: VerifyCodeAction.REGISTER_LOGIN, lang: 'zh_CN', sendInterval: 60
    });
    const interval = Number(result.getShortestInterval());
    return Number.isFinite(interval) ? Math.max(60, Math.min(3600, interval)) : 60;
  }

  private phoneCredential(phone: string, code: string): CredentialInfo {
    return { kind: 'phone', countryCode: '86', phoneNumber: validatedPhone(phone), verifyCode: validatedPhoneCode(code) };
  }

  private async wechatCredential(): Promise<CredentialInfo> {
    this.initialize();
    let config: WechatLoginConfig;
    try {
      const bytes = this.context.resourceManager.getRawFileContentSync('account_login_config.json');
      config = JSON.parse(util.TextDecoder.create('utf-8').decodeToString(bytes)) as WechatLoginConfig;
    } catch (_error) {
      throw new HuaweiAccountPublicError('微信登录暂未开通，请使用其他登录方式。');
    }
    const token = await wechatAccountService(this.context as common.UIAbilityContext).credential(config);
    return { kind: 'selfBuild', accessToken: token };
  }

  private async signIn(credential: CredentialInfo): Promise<CloudAccountIdentity> {
    this.initialize();
    try {
      await this.signOut();
      return identity((await auth.signIn({ credentialInfo: credential, autoCreateUser: true })).getUser());
    } catch (error) {
      const code = typeof error === 'object' && error !== null ? (error as BusinessError).code : -1;
      const category = error === 'authCode is null' ? 'missing_authorization_code' :
        error === 'hwid login state error!' ? 'authorization_state_mismatch' : 'provider_error';
      hilog.error(0x0000, 'ApplessAuth', 'Sign-in failed: %{public}s, code=%{public}s', category, String(code));
      throw error instanceof Error ? error : new Error(category);
    }
  }
  async loginPhone(phone: string, code: string): Promise<CloudAccountIdentity> {
    return this.signIn(this.phoneCredential(phone, code));
  }
  async loginWechat(): Promise<CloudAccountIdentity> { return this.signIn(await this.wechatCredential()); }
  async loginHuawei(): Promise<CloudAccountIdentity> { return this.signIn({ kind: 'hwid' }); }

  async restore(): Promise<CloudAccountIdentity | null> {
    this.initialize();
    const user = await auth.getCurrentUser();
    if (user === null) return null;
    // Restore the SDK's persisted session for local data; remote login/link operations still authenticate with AGC.
    return identity(user);
  }

  private async link(uid: string, credential: CredentialInfo): Promise<CloudAccountIdentity> {
    this.initialize();
    const user = await auth.getCurrentUser();
    if (user === null || user.getUid() !== uid) throw new HuaweiAccountPublicError('登录状态已变化，请重新登录后绑定。');
    const linked = identity((await user.link(credential)).getUser());
    if (linked.uid !== uid) throw new HuaweiAccountPublicError('账号绑定校验失败。');
    return linked;
  }
  async linkPhone(uid: string, phone: string, code: string): Promise<CloudAccountIdentity> {
    return this.link(uid, this.phoneCredential(phone, code));
  }
  async linkWechat(uid: string): Promise<CloudAccountIdentity> { return this.link(uid, await this.wechatCredential()); }
  async signOut(): Promise<void> {
    // With no config, the existing Huawei-only login does not depend on AGC.
    if (this.initialized && await auth.getCurrentUser() !== null) await auth.signOut();
  }
}
