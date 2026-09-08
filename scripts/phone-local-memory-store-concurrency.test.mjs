import assert from 'node:assert/strict';
import { readFileSync } from 'node:fs';
import { createRequire } from 'node:module';
import { dirname, resolve } from 'node:path';
import { fileURLToPath } from 'node:url';
import test from 'node:test';
import vm from 'node:vm';

// Run with a locally installed TypeScript or TYPESCRIPT_MODULE_PATH pointing at the SDK module.
const require = createRequire(import.meta.url);
const ts = require(process.env.TYPESCRIPT_MODULE_PATH || 'typescript');
const memoryRoot = resolve(dirname(fileURLToPath(import.meta.url)), '../entry/src/main/ets/memory');
const databases = new Map();
const modules = new Map();
let sequence = 0;
const key = (directory, name) => directory.replace(/\\/g, '/').replace(/\/+$/, '') + '/' + name;
const arkData = {
  relationalStore: {
    isVectorSupported: () => true,
    SecurityLevel: { S1: 1 },
    async getRdbStore(context, config) {
      const database = databases.get(key(context.databaseDir, config.name));
      assert.ok(database, 'fake database must be registered');
      database.opens += 1;
      return new FakeConnection(database);
    }
  }
};

function load(name) {
  const path = resolve(memoryRoot, name + '.ets');
  if (modules.has(path)) return modules.get(path).exports;
  const module = { exports: {} };
  modules.set(path, module);
  const { outputText, diagnostics } = ts.transpileModule(readFileSync(path, 'utf8'), {
    fileName: path,
    reportDiagnostics: true,
    compilerOptions: { module: ts.ModuleKind.CommonJS, target: ts.ScriptTarget.ES2020 }
  });
  assert.equal(diagnostics?.filter(item => item.category === ts.DiagnosticCategory.Error).length ?? 0, 0);
  const localRequire = name => {
    if (name === '@kit.ArkData') return arkData;
    if (name === '@ohos.util') return { default: { generateRandomUUID: () => 'history-' + ++sequence } };
    if (name.startsWith('.')) return load(name);
    throw new Error('Unexpected runtime import: ' + name);
  };
  vm.runInThisContext('(function(require, module, exports) {' + outputText + '\n})', { filename: path })(
    localRequire, module, module.exports);
  return module.exports;
}

const vector = load('PhoneLocalMemoryStore');
const blob = load('PhoneLocalMemoryBlobFallbackPort');

function deferred() {
  let resolve;
  const promise = new Promise(done => { resolve = done; });
  return { promise, resolve };
}

function gate() {
  const entered = deferred();
  const released = deferred();
  return { entered: entered.promise, release: released.resolve, async wait() {
    entered.resolve();
    await released.promise;
  } };
}

const tick = () => new Promise(done => setImmediate(done));
function record(fact = 'original') {
  return { memoryId: 'memory-1', ownerId: 'owner-1', sceneId: 'scene-1', personaTag: 'user',
    authority: 'leader', fact, normalizedFact: fact, factHash: fact, embedding: new Array(512).fill(0),
    embeddingProfileId: 'embedding-1', sourceTurnId: 'turn-1', createdAt: 1, updatedAt: 2 };
}

function makeDatabase() {
  return { row: record(), history: ['original'], metadata: new Map(), reads: 0, opens: 0,
    active: 0, maxActive: 0, commits: 0, rollbacks: 0, writes: [], pause: null, fail: null };
}

function result(row) {
  return { goToFirstRow: () => row !== null, goToNextRow: () => false,
    getColumnIndex: column => column, getString: column => row[column],
    getLong: column => row[column], getValue: column => row[column], getBlob: column => row[column],
    close() {} };
}

// Connections are deliberately independent. Only the production registry can serialize them.
class FakeConnection {
  constructor(database) { this.database = database; this.transaction = null; }
  beginTransaction() {
    const db = this.database;
    this.transaction = { row: structuredClone(db.row), history: [...db.history], metadata: new Map(db.metadata) };
    db.active += 1;
    db.maxActive = Math.max(db.maxActive, db.active);
  }
  async beginTrans() {
    this.beginTransaction();
    await this.pause('begin');
    return 1;
  }
  async pause(stage) {
    const pause = this.database.pause;
    if (pause && pause.stage === stage) {
      this.database.pause = null;
      await pause.gate.wait();
    }
  }
  async execute(sql, txOrArgs, values) {
    const db = this.database;
    const args = values ?? (Array.isArray(txOrArgs) ? txOrArgs : []);
    const stage = sql.startsWith('CREATE ') ? 'schema' : sql.includes('_metadata') ? 'metadata' :
      sql.includes('_history') ? 'history' : 'mutation';
    db.writes.push(stage);
    await this.pause(stage);
    if (db.fail === stage) { db.fail = null; throw new Error('injected ' + stage + ' failure'); }
    const target = this.transaction ?? db;
    if (stage === 'schema') return undefined;
    if (stage === 'metadata') target.metadata.set(args[0], args[1]);
    else if (stage === 'history') {
      if (sql.startsWith('DELETE')) target.history = [];
      else target.history.push(args[5]);
    } else if (sql.startsWith('UPDATE')) {
      target.row = { ...target.row, sceneId: args[0], personaTag: args[1], authority: args[2], fact: args[3],
        normalizedFact: args[4], factHash: args[5], embeddingProfileId: args[7], sourceTurnId: args[8], updatedAt: args[9] };
    } else if (sql.startsWith('DELETE')) target.row = null;
    else if (sql.startsWith('INSERT')) target.row = { ...record(args[5]), memoryId: args[0], ownerId: args[1] };
    // ArkData execute does not provide affected-row truth. Tests intentionally return undefined.
    return undefined;
  }
  commit() {
    assert.ok(this.transaction);
    Object.assign(this.database, this.transaction);
    this.transaction = null;
    this.database.active -= 1;
    this.database.commits += 1;
  }
  rollBack() {
    assert.ok(this.transaction);
    this.transaction = null;
    this.database.active -= 1;
    this.database.rollbacks += 1;
  }
  async rollback() { this.rollBack(); }
  async querySql(sql, args) {
    const db = this.database;
    if (sql.includes('_metadata')) {
      const value = db.metadata.get(args[0]);
      return result(value === undefined ? null : { metadata_value: value });
    }
    db.reads += 1;
    const value = db.row;
    const row = !value || value.ownerId !== args[0] || value.memoryId !== args[1] ? null : {
      memory_id: value.memoryId, owner_id: value.ownerId, scene_id: value.sceneId, persona_tag: value.personaTag,
      authority: value.authority, fact: value.fact, normalized_fact: value.normalizedFact, fact_hash: value.factHash,
      embedding: sql.includes('conversation_memory_blob') ? blob.encodePhoneLocalMemoryEmbeddingBlob(value.embedding) :
        new Float32Array(value.embedding), embedding_profile_id: value.embeddingProfileId,
      source_turn_id: value.sourceTurnId, created_at: value.createdAt, updated_at: value.updatedAt
    };
    await this.pause('read');
    return result(row);
  }
}

function wrapper(backend, directory, name) {
  const context = { databaseDir: directory };
  return backend === 'vector' ? new vector.ArkDataPhoneLocalMemoryStore(context) :
    new blob.ArkDataPhoneLocalMemoryBlobStore(context, name);
}

async function pair(backend) {
  const directory = '/test/memory-' + ++sequence;
  const name = backend === 'vector' ? vector.PHONE_LOCAL_MEMORY_VECTOR_DB_NAME : 'custom-memory.db';
  const db = makeDatabase();
  databases.set(key(directory, name), db);
  const first = wrapper(backend, directory + '/', name);
  const second = wrapper(backend, directory.replaceAll('/', '\\'), name);
  await Promise.all([first.initialize(), second.initialize()]);
  db.commits = 0;
  db.writes = [];
  return { db, first, second, directory, name };
}

for (const backend of ['vector', 'blob']) {
  test(backend + ': independent wrappers accept exactly one concurrent edit of the same expected record', async () => {
    const { db, first, second } = await pair(backend);
    const pause = gate();
    db.pause = { stage: 'mutation', gate: pause };
    const one = first.replaceIfCurrent('owner-1', record('first'), record());
    await pause.entered;
    const two = second.replaceIfCurrent('owner-1', record('second'), record());
    await tick();
    assert.equal(db.reads, 1, 'queued writer must not read before the first commit');
    pause.release();
    assert.equal((await one).status, 'success');
    assert.equal((await two).status, 'conflict');
    assert.equal(db.row.fact, 'first');
    assert.deepEqual(db.history, ['original', 'first']);
    assert.equal(db.maxActive, 1);
  });

  test(backend + ': ordinary update blocks stale conditional delete; a repeated delete is not_found', async () => {
    const { db, first, second } = await pair(backend);
    const pause = gate();
    db.pause = { stage: 'mutation', gate: pause };
    const edit = first.replace('owner-1', record('newer'));
    await pause.entered;
    const deletion = second.removeIfCurrent('owner-1', 'memory-1', record());
    await tick();
    pause.release();
    await edit;
    assert.equal((await deletion).status, 'conflict');
    assert.deepEqual(db.history, ['original', 'newer']);
    assert.equal((await second.removeIfCurrent('owner-1', 'memory-1', record('newer'))).status, 'success');
    assert.equal((await first.removeIfCurrent('owner-1', 'memory-1', record('newer'))).status, 'not_found');
    assert.equal(db.row, null);
    assert.deepEqual(db.history, []);
  });

  test(backend + ': guard invalidated while waiting for the shared lock prevents writes and releases the queue', async () => {
    const { db, first, second } = await pair(backend);
    const pause = gate();
    db.pause = { stage: 'metadata', gate: pause };
    const holder = first.setMetadata('busy', '1');
    await pause.entered;
    let active = true;
    const pending = second.replaceIfCurrent('owner-1', record('stale'), record(), { isActive: () => active });
    const rejected = assert.rejects(pending, /memory_operation_canceled/);
    await tick();
    active = false;
    pause.release();
    await holder;
    await rejected;
    assert.equal(db.row.fact, 'original');
    assert.equal(db.commits, 1);
    await first.replace('owner-1', record('fresh'));
    assert.equal(db.row.fact, 'fresh');
  });

  test(backend + ': cancellation during the fresh read prevents starting a transaction', async () => {
    const { db, first, second } = await pair(backend);
    const pause = gate();
    db.pause = { stage: 'read', gate: pause };
    let active = true;
    const pending = first.replaceIfCurrent('owner-1', record('stale'), record(), { isActive: () => active });
    const rejected = assert.rejects(pending, /memory_operation_canceled/);
    await pause.entered;
    active = false;
    pause.release();
    await rejected;
    assert.deepEqual(db.writes, []);
    assert.equal(db.active, 0);
    assert.equal(db.rollbacks, 0);
    await second.replace('owner-1', record('fresh'));
    assert.equal(db.row.fact, 'fresh');
  });

  test(backend + ': every expected field is checked even when timestamps are unchanged', async () => {
    const { db, first } = await pair(backend);
    for (const field of ['fact', 'personaTag', 'authority', 'createdAt', 'updatedAt']) {
      const expected = record();
      expected[field] = typeof expected[field] === 'number' ? 99 : 'changed';
      assert.equal((await first.replaceIfCurrent('owner-1', record('stale'), expected)).status, 'conflict');
      assert.equal((await first.removeIfCurrent('owner-1', 'memory-1', expected)).status, 'conflict');
    }
    assert.equal(db.commits, 0);
    assert.deepEqual(db.writes, []);
  });

  for (const operation of ['insert', 'replace', 'replaceIfCurrent', 'remove', 'removeIfCurrent']) {
    test(backend + ': ' + operation + ' rolls back when canceled after SQL and before commit', async () => {
      const { db, first, second } = await pair(backend);
      const pause = gate();
      db.pause = { stage: 'history', gate: pause };
      let active = true;
      const guard = { isActive: () => active };
      const pending = operation === 'insert' ? first.insert(record('stale'), guard) :
        operation === 'replace' ? first.replace('owner-1', record('stale'), guard) :
        operation === 'replaceIfCurrent' ? first.replaceIfCurrent('owner-1', record('stale'), record(), guard) :
        operation === 'remove' ? first.remove('owner-1', 'memory-1', guard) :
        first.removeIfCurrent('owner-1', 'memory-1', record(), guard);
      const rejected = assert.rejects(pending, /memory_operation_canceled/);
      await pause.entered;
      active = false;
      pause.release();
      await rejected;
      assert.equal(db.commits, 0);
      assert.equal(db.rollbacks, 1);
      assert.equal(db.row.fact, 'original');
      assert.deepEqual(db.history, ['original']);
      await second.replace('owner-1', record('fresh'));
      assert.equal(db.row.fact, 'fresh');
    });
  }

  test(backend + ': history exception rolls back the record and releases the shared lock', async () => {
    const { db, first, second } = await pair(backend);
    db.fail = 'history';
    await assert.rejects(first.replaceIfCurrent('owner-1', record('failed'), record()), /injected history failure/);
    assert.equal(db.row.fact, 'original');
    assert.deepEqual(db.history, ['original']);
    assert.equal(db.rollbacks, 1);
    assert.equal((await second.replaceIfCurrent('owner-1', record('fresh'), record())).status, 'success');
  });

  test(backend + ': a database in a different directory progresses while another is locked', async () => {
    const { db, first } = await pair(backend);
    const independent = await pair(backend);
    const pause = gate();
    db.pause = { stage: 'metadata', gate: pause };
    const pending = first.setMetadata('busy', '1');
    await pause.entered;
    try {
      await independent.first.replace('owner-1', record('independent'));
      assert.equal(independent.db.row.fact, 'independent');
    } finally { pause.release(); }
    await pending;
  });

  test(backend + ': opening another wrapper waits for in-flight writes before schema migration', async () => {
    const { db, first, directory, name } = await pair(backend);
    const pause = gate();
    db.pause = { stage: 'metadata', gate: pause };
    const pending = first.setMetadata('busy', '1');
    await pause.entered;
    const opens = db.opens;
    const third = wrapper(backend, directory, name);
    const opening = third.initialize();
    await tick();
    assert.equal(db.opens, opens);
    pause.release();
    await Promise.all([pending, opening]);
    assert.equal(db.maxActive, 1);
  });

  test(backend + ': failed schema initialization releases the registry lock and can be retried', async () => {
    const { db, directory, name } = await pair(backend);
    const failing = wrapper(backend, directory, name);
    const following = wrapper(backend, directory, name);
    db.fail = 'schema';
    const rejected = assert.rejects(failing.initialize(), /injected schema failure/);
    await following.initialize();
    await rejected;
    await failing.replace('owner-1', record('retry'));
    assert.equal(db.row.fact, 'retry');
  });
}

test('vector: cancellation while beginTrans awaits rolls back without executing mutation SQL', async () => {
  const { db, first } = await pair('vector');
  const pause = gate();
  db.pause = { stage: 'begin', gate: pause };
  let active = true;
  const pending = first.replaceIfCurrent('owner-1', record('stale'), record(), { isActive: () => active });
  const rejected = assert.rejects(pending, /memory_operation_canceled/);
  await pause.entered;
  active = false;
  pause.release();
  await rejected;
  assert.deepEqual(db.writes, []);
  assert.equal(db.rollbacks, 1);
});

test('custom BLOB filenames stay independent in the same directory', async () => {
  const { db, first, directory } = await pair('blob');
  const other = makeDatabase();
  databases.set(key(directory, 'another.db'), other);
  const independent = wrapper('blob', directory, 'another.db');
  const pause = gate();
  db.pause = { stage: 'metadata', gate: pause };
  const pending = first.setMetadata('busy', '1');
  await pause.entered;
  try {
    await independent.replace('owner-1', record('independent'));
    assert.equal(other.row.fact, 'independent');
  } finally { pause.release(); }
  await pending;
});

test('both backends use the same registry when explicitly targeting the same database file', async () => {
  const { db, first, directory, name } = await pair('vector');
  const second = wrapper('blob', directory, name);
  await second.initialize();
  const pause = gate();
  db.pause = { stage: 'metadata', gate: pause };
  const pending = first.setMetadata('vector-key', '1');
  await pause.entered;
  const commits = db.commits;
  const other = second.setMetadata('blob-key', '2');
  await tick();
  assert.equal(db.commits, commits);
  assert.equal(db.active, 1);
  pause.release();
  await Promise.all([pending, other]);
  assert.equal(db.metadata.get('vector-key'), '1');
  assert.equal(db.metadata.get('blob-key'), '2');
  assert.equal(db.maxActive, 1);
});
