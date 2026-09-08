interface DatabaseWriteWaiter {
  resolve: () => void;
}

/** Serializes writers in this ArkTS runtime; this is not a cross-process database lock. */
export class PhoneLocalMemoryDatabaseWriteMutex {
  private busy: boolean = false;
  private waiters: DatabaseWriteWaiter[] = [];

  async acquire(): Promise<void> {
    if (!this.busy) {
      this.busy = true;
      return;
    }
    await new Promise<void>((resolve: () => void): void => {
      this.waiters.push({ resolve });
    });
  }

  release(): void {
    const next = this.waiters.shift();
    if (next !== undefined) next.resolve();
    else this.busy = false;
  }
}

// Keep entries for the runtime lifetime so a recreated page cannot bypass queued writers.
const databaseWriteMutexes: Map<string, PhoneLocalMemoryDatabaseWriteMutex> = new Map();

export function phoneLocalMemoryDatabaseWriteMutex(databaseDir: string,
  databaseName: string): PhoneLocalMemoryDatabaseWriteMutex {
  const directory = databaseDir.replace(/\\/g, '/').replace(/\/+$/, '');
  const key = directory + '/' + databaseName;
  let mutex = databaseWriteMutexes.get(key);
  if (mutex === undefined) {
    mutex = new PhoneLocalMemoryDatabaseWriteMutex();
    databaseWriteMutexes.set(key, mutex);
  }
  return mutex;
}
