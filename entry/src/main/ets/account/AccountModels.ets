export enum AccountSessionStatus {
  UNINITIALIZED = 'uninitialized',
  RESTORING = 'restoring',
  SIGNED_OUT = 'signed_out',
  AUTHENTICATED = 'authenticated',
  ACCOUNT_MISMATCH = 'account_mismatch',
  ERROR = 'error'
}

export interface AccountSessionSnapshot {
  status: AccountSessionStatus;
  ownerId: string;
  errorMessage: string;
}

export function emptyAccountSessionSnapshot(): AccountSessionSnapshot {
  return {
    status: AccountSessionStatus.UNINITIALIZED,
    ownerId: '',
    errorMessage: ''
  };
}

export function isAuthenticatedAccount(snapshot: AccountSessionSnapshot): boolean {
  return snapshot.status === AccountSessionStatus.AUTHENTICATED && snapshot.ownerId.length > 0;
}
