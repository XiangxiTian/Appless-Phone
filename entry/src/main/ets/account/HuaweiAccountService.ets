import { bundleManager, common } from '@kit.AbilityKit';
import { authentication } from '@kit.AccountKit';
import { BusinessError } from '@kit.BasicServicesKit';
import util from '@ohos.util';

const HUAWEI_ID_NOT_LOGGED_IN: number = 1001502001;
const HUAWEI_APP_NOT_AUTHORIZED: number = 1001502002;
const HUAWEI_FINGERPRINT_INVALID: number = 1001500001;
const HUAWEI_PARAMETER_INVALID: number = 1001502003;

export enum HuaweiAuthorizationState {
  UNLOGGED_IN = 'unlogged_in',
  AUTHORIZED = 'authorized',
  UNAUTHORIZED = 'unauthorized'
}

export interface HuaweiAccountIdentity {
  unionId: string;
}

export interface HuaweiAccountProfile {
  nickName: string;
  avatarUri: string;
}

export interface HuaweiAccountService {
  login(clientId: string): Promise<HuaweiAccountIdentity>;
  authorizeProfile(expectedUnionId: string): Promise<HuaweiAccountProfile>;
  getAuthorizationState(unionId: string): Promise<HuaweiAuthorizationState>;
}

export class HuaweiAccountPublicError extends Error {
  constructor(message: string) {
    super(message);
  }
}

export function missingHuaweiClientIdMessage(): string {
  return '未配置华为账号 Client ID，无法登录。';
}

/**
 * Reads the same module metadata consumed by Account Kit, so adding the real AGC client_id to
 * module.json5 is the only configuration step. No duplicate client identifier lives in code.
 */
export function configuredHuaweiAccountClientId(): string {
  try {
    const flags: number = bundleManager.BundleFlag.GET_BUNDLE_INFO_WITH_HAP_MODULE |
      bundleManager.BundleFlag.GET_BUNDLE_INFO_WITH_METADATA;
    const info = bundleManager.getBundleInfoForSelfSync(flags);
    for (let moduleIndex = 0; moduleIndex < info.hapModulesInfo.length; moduleIndex += 1) {
      const metadata = info.hapModulesInfo[moduleIndex].metadata;
      for (let metadataIndex = 0; metadataIndex < metadata.length; metadataIndex += 1) {
        if (metadata[metadataIndex].name === 'client_id') {
          return metadata[metadataIndex].value.trim();
        }
      }
    }
  } catch (_error) {
  }
  return '';
}

function validateClientId(clientId: string): void {
  if (clientId.trim().length === 0) {
    throw new HuaweiAccountPublicError(missingHuaweiClientIdMessage());
  }
}

function validIdentity(unionId: string): HuaweiAccountIdentity {
  if (unionId.trim().length === 0) {
    throw new HuaweiAccountPublicError('华为账号未返回有效用户标识，请稍后重试。');
  }
  return { unionId: unionId };
}

export function validateHuaweiProfileAuthorizationResponse(
  expectedUnionId: string,
  expectedState: string,
  returnedState: string | undefined,
  returnedUnionIdValue: string | undefined,
  nickNameValue: string | undefined,
  avatarUriValue: string | undefined
): HuaweiAccountProfile {
  if (expectedState.length === 0 || returnedState !== expectedState) {
    throw new HuaweiAccountPublicError('华为账号资料授权校验失败，请稍后重试。');
  }
  const returnedUnionId = returnedUnionIdValue === undefined ? '' : returnedUnionIdValue.trim();
  if (returnedUnionId.length > 0 && returnedUnionId !== expectedUnionId) {
    throw new HuaweiAccountPublicError('华为账号资料与当前登录账号不匹配。');
  }
  return {
    nickName: nickNameValue === undefined ? '' : nickNameValue.trim(),
    avatarUri: avatarUriValue === undefined ? '' : avatarUriValue.trim()
  };
}

export function huaweiLoginErrorMessage(code: number): string {
  if (code === HUAWEI_FINGERPRINT_INVALID) {
    return '应用签名与 AGC 配置不匹配，请检查证书指纹。';
  }
  if (code === 1001502012) {
    return '登录已取消。';
  }
  if (code === HUAWEI_ID_NOT_LOGGED_IN) {
    return '设备尚未登录华为账号。';
  }
  if (code === HUAWEI_APP_NOT_AUTHORIZED) {
    return '当前应用尚未获得华为账号授权。';
  }
  if (code === HUAWEI_PARAMETER_INVALID) {
    return '华为账号参数无效，请检查 Client ID 与 AGC 应用配置。';
  }
  if (code === 1001502005) {
    return '华为账号登录网络异常，请稍后重试。';
  }
  return '华为账号登录失败（错误码 ' + code.toString() + '）。';
}

function publicLoginError(error: Error | Object | string | number | boolean | null | undefined): HuaweiAccountPublicError {
  if (error instanceof HuaweiAccountPublicError) {
    return error;
  }
  let code: number = -1;
  if (typeof error === 'object' && error !== null) {
    const businessError = error as BusinessError;
    code = typeof businessError.code === 'number' ? businessError.code : -1;
  }
  return new HuaweiAccountPublicError(huaweiLoginErrorMessage(code));
}

export class AccountKitHuaweiAccountService implements HuaweiAccountService {
  private readonly provider: authentication.HuaweiIDProvider;
  private readonly controller: authentication.AuthenticationController;

  constructor(context: common.Context) {
    this.provider = new authentication.HuaweiIDProvider();
    this.controller = new authentication.AuthenticationController(context);
  }

  async login(clientId: string): Promise<HuaweiAccountIdentity> {
    // Account Kit does not accept clientId on LoginWithHuaweiIDRequest. This check only prevents an
    // unconfigured build from pretending login is available; AGC/module metadata is still required on device.
    validateClientId(clientId);
    try {
      const request = this.provider.createLoginWithHuaweiIDRequest();
      request.forceLogin = true;
      const response = await this.controller.executeRequest(request) as authentication.LoginWithHuaweiIDResponse;
      if (response.data === undefined) {
        throw new HuaweiAccountPublicError('华为账号未返回登录凭据，请稍后重试。');
      }
      return validIdentity(response.data.unionID);
    } catch (error) {
      throw publicLoginError(error);
    }
  }

  async authorizeProfile(expectedUnionId: string): Promise<HuaweiAccountProfile> {
    try {
      const state = 'appless-profile-' + util.generateRandomUUID(false);
      const request = this.provider.createAuthorizationWithHuaweiIDRequest();
      request.scopes = ['profile'];
      request.forceAuthorization = true;
      request.state = state;
      const response = await this.controller.executeRequest(request) as authentication.AuthorizationWithHuaweiIDResponse;
      if (response.data === undefined) {
        throw new HuaweiAccountPublicError('华为账号未返回用户资料。');
      }
      return validateHuaweiProfileAuthorizationResponse(
        expectedUnionId,
        state,
        response.state,
        response.data.unionID,
        response.data.nickName,
        response.data.avatarUri
      );
    } catch (error) {
      throw publicLoginError(error);
    }
  }

  async getAuthorizationState(unionId: string): Promise<HuaweiAuthorizationState> {
    if (unionId.trim().length === 0) {
      return HuaweiAuthorizationState.UNLOGGED_IN;
    }
    try {
      const result = await this.provider.getHuaweiIDState({
        idType: authentication.IdType.UNION_ID,
        idValue: unionId
      });
      if (result.state === authentication.State.AUTHORIZED) {
        return HuaweiAuthorizationState.AUTHORIZED;
      }
      if (result.state === authentication.State.UNAUTHORIZED) {
        return HuaweiAuthorizationState.UNAUTHORIZED;
      }
      return HuaweiAuthorizationState.UNLOGGED_IN;
    } catch (error) {
      throw publicLoginError(error);
    }
  }
}
