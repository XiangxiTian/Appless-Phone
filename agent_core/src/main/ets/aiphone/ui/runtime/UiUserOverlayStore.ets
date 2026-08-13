export interface UiUserOverlaySnapshot {
  surfaceId: string;
  revision: number;
  hiddenNodeKeys: string[];
  pinnedNodeKeys: string[];
  orderedNodeKeys: string[];
  orphanedNodeKeys: string[];
}

function unique(values: string[]): string[] {
  const seen: Set<string> = new Set<string>();
  const result: string[] = [];
  values.forEach((value: string): void => {
    if (value.length > 0 && !seen.has(value)) {
      seen.add(value);
      result.push(value);
    }
  });
  return result;
}

function emptyOverlay(surfaceId: string): UiUserOverlaySnapshot {
  return {
    surfaceId,
    revision: 0,
    hiddenNodeKeys: [],
    pinnedNodeKeys: [],
    orderedNodeKeys: [],
    orphanedNodeKeys: []
  };
}

/** User-owned presentation choices; these never mutate canonical nodes. */
export class UiUserOverlayStore {
  private readonly overlays: Map<string, UiUserOverlaySnapshot> = new Map<string, UiUserOverlaySnapshot>();

  ensure(surfaceId: string): UiUserOverlaySnapshot {
    const current = this.overlays.get(surfaceId);
    if (current !== undefined) return this.snapshotValue(current);
    const created = emptyOverlay(surfaceId);
    this.overlays.set(surfaceId, created);
    return this.snapshotValue(created);
  }

  setHidden(surfaceId: string, nodeKey: string, hidden: boolean, revision: number): void {
    const current = this.ensure(surfaceId);
    current.hiddenNodeKeys = hidden
      ? unique(current.hiddenNodeKeys.concat([nodeKey]))
      : current.hiddenNodeKeys.filter((value: string): boolean => value !== nodeKey);
    current.revision = revision;
    this.overlays.set(surfaceId, current);
  }

  setPinned(surfaceId: string, nodeKey: string, pinned: boolean, revision: number): void {
    const current = this.ensure(surfaceId);
    current.pinnedNodeKeys = pinned
      ? unique(current.pinnedNodeKeys.concat([nodeKey]))
      : current.pinnedNodeKeys.filter((value: string): boolean => value !== nodeKey);
    current.revision = revision;
    this.overlays.set(surfaceId, current);
  }

  move(surfaceId: string, nodeKey: string, afterNodeKey: string | undefined, revision: number): void {
    const current = this.ensure(surfaceId);
    const remaining = current.orderedNodeKeys.filter((value: string): boolean => value !== nodeKey);
    if (afterNodeKey === undefined || afterNodeKey.length === 0) {
      remaining.unshift(nodeKey);
    } else {
      const index = remaining.indexOf(afterNodeKey);
      if (index < 0) remaining.push(nodeKey);
      else remaining.splice(index + 1, 0, nodeKey);
    }
    current.orderedNodeKeys = unique(remaining);
    current.revision = revision;
    this.overlays.set(surfaceId, current);
  }

  retainOrphans(surfaceId: string, availableNodeKeys: string[], revision: number): void {
    const current = this.ensure(surfaceId);
    const available: Set<string> = new Set<string>(availableNodeKeys);
    const allUserKeys: string[] = current.hiddenNodeKeys.concat(current.pinnedNodeKeys, current.orderedNodeKeys);
    current.orphanedNodeKeys = unique(allUserKeys).filter((value: string): boolean => !available.has(value));
    current.revision = revision;
    this.overlays.set(surfaceId, current);
  }

  get(surfaceId: string): UiUserOverlaySnapshot | null {
    const current = this.overlays.get(surfaceId);
    return current === undefined ? null : this.snapshotValue(current);
  }

  remove(surfaceId: string): boolean {
    return this.overlays.delete(surfaceId);
  }

  private snapshotValue(value: UiUserOverlaySnapshot): UiUserOverlaySnapshot {
    return {
      surfaceId: value.surfaceId,
      revision: value.revision,
      hiddenNodeKeys: value.hiddenNodeKeys.slice(),
      pinnedNodeKeys: value.pinnedNodeKeys.slice(),
      orderedNodeKeys: value.orderedNodeKeys.slice(),
      orphanedNodeKeys: value.orphanedNodeKeys.slice()
    };
  }
}
