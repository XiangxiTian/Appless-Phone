import { Want } from '@kit.AbilityKit';
import { FormExtensionAbility, formBindingData, formInfo, formProvider } from '@kit.FormKit';
import { BusinessError } from '@kit.BasicServicesKit';
import { aiLogError, aiLogInfo } from '@loop/agent-core';
import {
  NAVIGATION_CARD_FORM_REGISTRY_STORE,
  NAVIGATION_CARD_STORE,
  PreferencesNavigationCardSnapshotStore,
  buildNavigationCardBindingData,
  navigationCardFormEventFromMessage
} from '@loop/agent-core';
import { activeAccountOwnerId } from '../account/ActiveAccountOwnerStore';
import { accountScopedStoreName } from '../account/AccountStorageScope';

function textParam(want: Want, key: string): string {
  if (want.parameters === undefined || want.parameters === null) {
    return '';
  }
  const value = want.parameters[key];
  if (value === undefined || value === null) {
    return '';
  }
  if (typeof value === 'string') {
    return value;
  }
  if (typeof value === 'number' || typeof value === 'boolean') {
    return value.toString();
  }
  return '';
}

function errorCodeOf(error: BusinessError): string {
  return error.code === undefined || error.code === null ? 'unknown' : error.code.toString();
}

export default class NavigationCardFormExtensionAbility extends FormExtensionAbility {
  private snapshotStore(): PreferencesNavigationCardSnapshotStore | null {
    const ownerId: string = activeAccountOwnerId(this.context);
    return ownerId.length === 0 ? null : new PreferencesNavigationCardSnapshotStore(
      this.context, accountScopedStoreName(NAVIGATION_CARD_STORE, ownerId), NAVIGATION_CARD_FORM_REGISTRY_STORE
    );
  }

  private formRegistryStore(): PreferencesNavigationCardSnapshotStore {
    return new PreferencesNavigationCardSnapshotStore(
      this.context, NAVIGATION_CARD_STORE, NAVIGATION_CARD_FORM_REGISTRY_STORE
    );
  }

  private bindingData(): formBindingData.FormBindingData {
    const store = this.snapshotStore();
    const snapshot = store === null ? null : store.getSnapshotSync();
    return formBindingData.createFormBindingData(buildNavigationCardBindingData(snapshot, Date.now()));
  }

  onAddForm(want: Want): formBindingData.FormBindingData {
    const formId = textParam(want, formInfo.FormParam.IDENTITY_KEY);
    if (formId.length > 0) {
      this.formRegistryStore().addFormIdSync(formId);
    }
    aiLogInfo('[AIPhone][NavigationCardFormAdd] formId=' + formId);
    return this.bindingData();
  }

  onCastToNormalForm(formId: string): void {
    this.formRegistryStore().addFormIdSync(formId);
    aiLogInfo('[AIPhone][NavigationCardFormCastNormal] formId=' + formId);
  }

  onUpdateForm(formId: string): void {
    const binding = this.bindingData();
    formProvider.updateForm(formId, binding).then(() => {
      aiLogInfo('[AIPhone][NavigationCardFormUpdate] formId=' + formId + ' ok=true');
    }).catch((error: BusinessError) => {
      aiLogError('[AIPhone][NavigationCardFormUpdate] formId=' + formId +
        ' ok=false code=' + errorCodeOf(error) + ' message=' + error.message);
    });
  }

  onFormEvent(formId: string, message: string): void {
    const event = navigationCardFormEventFromMessage(message);
    aiLogInfo('[AIPhone][NavigationCardFormEvent] formId=' + formId + ' event=' + event);
    if (event === 'refresh' || event === 'open_map' || event === 'open_agent') {
      this.onUpdateForm(formId);
    }
  }

  onRemoveForm(formId: string): void {
    this.formRegistryStore().removeFormIdSync(formId);
    aiLogInfo('[AIPhone][NavigationCardFormRemove] formId=' + formId);
  }

  onAcquireFormState(_want: Want): formInfo.FormState {
    return formInfo.FormState.READY;
  }
}
