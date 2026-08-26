import { common } from '@kit.AbilityKit';
import { mindSporeLite } from '@kit.MindSporeLiteKit';
import { EmbeddingPort } from '@loop/agent-core';
import { BgeTokenizedInput, BgeTokenizerPort } from './BgeEmbeddingTypes';

export const BGE_SMALL_ZH_MODEL_RAWFILE: string = 'memory/bge-small-zh-v1.5.ms';
export const BGE_SMALL_ZH_MODEL_SHA256: string =
  '50e892695ab46c44393ce6e2bdc980a9ad9faf2b5ced380d076f1370847cbed6';
export const BGE_SMALL_ZH_SEQUENCE_LENGTH: number = 128;
export const BGE_SMALL_ZH_EMBEDDING_DIMENSION: number = 512;
export const BGE_SMALL_ZH_PROFILE_ID: string = 'bge-small-zh-v1.5:sha256=' +
  BGE_SMALL_ZH_MODEL_SHA256 + ':seq=128';

const BGE_INPUT_ELEMENT_COUNT: number = BGE_SMALL_ZH_SEQUENCE_LENGTH;
const BGE_INT32_DATA_TYPE: number = mindSporeLite.DataType.NUMBER_TYPE_INT32;
const BGE_FLOAT32_DATA_TYPE: number = mindSporeLite.DataType.NUMBER_TYPE_FLOAT32;
const INPUT_IDS_NAME: string = 'input_ids';
const ATTENTION_MASK_NAME: string = 'attention_mask';
const TOKEN_TYPE_IDS_NAME: string = 'token_type_ids';
const OUTPUT_NAME: string = 'raw_cls';

export interface BgeTensorSpec {
  name: string;
  shape: number[];
  elementNum: number;
  dtype: number;
}

export interface BgeInferenceOutput extends BgeTensorSpec {
  data: ArrayBuffer;
}

/** Small injectable boundary used to test the embedding contract without loading the real model. */
export interface BgeInferenceSessionPort {
  getInputSpecs(): BgeTensorSpec[];
  predict(input: BgeTokenizedInput): Promise<BgeInferenceOutput[]>;
}

function sameShape(actual: number[], expected: number[]): boolean {
  if (actual.length !== expected.length) return false;
  for (let index = 0; index < actual.length; index += 1) {
    if (actual[index] !== expected[index]) return false;
  }
  return true;
}

function expectedInputName(name: string): boolean {
  return name === INPUT_IDS_NAME || name === ATTENTION_MASK_NAME || name === TOKEN_TYPE_IDS_NAME;
}

function validateInputSpecs(specs: BgeTensorSpec[]): void {
  if (specs.length !== 3) throw new Error('BGE model must expose exactly three inputs');
  const seen: string[] = [];
  for (let index = 0; index < specs.length; index += 1) {
    const spec = specs[index];
    if (!expectedInputName(spec.name)) throw new Error('BGE model contains an unexpected input: ' + spec.name);
    if (seen.indexOf(spec.name) >= 0) throw new Error('BGE model contains a duplicate input: ' + spec.name);
    seen.push(spec.name);
    if (!sameShape(spec.shape, [1, BGE_SMALL_ZH_SEQUENCE_LENGTH]) ||
      spec.elementNum !== BGE_INPUT_ELEMENT_COUNT) {
      throw new Error('BGE input shape mismatch: ' + spec.name);
    }
    if (spec.dtype !== BGE_INT32_DATA_TYPE) throw new Error('BGE input dtype mismatch: ' + spec.name);
  }
}

function validateTokenizedInput(input: BgeTokenizedInput): void {
  if (input.inputIds.length !== BGE_SMALL_ZH_SEQUENCE_LENGTH ||
    input.attentionMask.length !== BGE_SMALL_ZH_SEQUENCE_LENGTH ||
    input.tokenTypeIds.length !== BGE_SMALL_ZH_SEQUENCE_LENGTH) {
    throw new Error('BGE tokenizer must return three 128-element INT32 arrays');
  }
}

function validateOutput(output: BgeInferenceOutput): void {
  if (output.name !== OUTPUT_NAME) throw new Error('BGE output name mismatch: ' + output.name);
  if (!sameShape(output.shape, [1, BGE_SMALL_ZH_EMBEDDING_DIMENSION]) ||
    output.elementNum !== BGE_SMALL_ZH_EMBEDDING_DIMENSION) {
    throw new Error('BGE output shape mismatch');
  }
  if (output.dtype !== BGE_FLOAT32_DATA_TYPE) throw new Error('BGE output dtype mismatch');
  if (output.data.byteLength !== BGE_SMALL_ZH_EMBEDDING_DIMENSION * 4) {
    throw new Error('BGE output byte length mismatch');
  }
}

function modelArrayBuffer(bytes: Uint8Array): ArrayBuffer {
  const source = bytes.buffer as ArrayBuffer;
  if (bytes.byteOffset === 0 && source.byteLength === bytes.byteLength) return source;
  const copy = new Uint8Array(bytes.length);
  copy.set(bytes);
  return copy.buffer as ArrayBuffer;
}

function int32ArrayBuffer(values: Int32Array): ArrayBuffer {
  const copy = new Int32Array(values.length);
  copy.set(values);
  return copy.buffer as ArrayBuffer;
}

class MindSporeBgeInferenceSession implements BgeInferenceSessionPort {
  private model: mindSporeLite.Model;

  constructor(model: mindSporeLite.Model) {
    this.model = model;
  }

  getInputSpecs(): BgeTensorSpec[] {
    const inputs = this.model.getInputs();
    const specs: BgeTensorSpec[] = [];
    for (let index = 0; index < inputs.length; index += 1) {
      specs.push({
        name: inputs[index].name,
        shape: inputs[index].shape.slice(),
        elementNum: inputs[index].elementNum,
        dtype: inputs[index].dtype
      });
    }
    return specs;
  }

  async predict(input: BgeTokenizedInput): Promise<BgeInferenceOutput[]> {
    const tensors = this.model.getInputs();
    for (let index = 0; index < tensors.length; index += 1) {
      const tensor = tensors[index];
      if (tensor.name === INPUT_IDS_NAME) tensor.setData(int32ArrayBuffer(input.inputIds));
      else if (tensor.name === ATTENTION_MASK_NAME) tensor.setData(int32ArrayBuffer(input.attentionMask));
      else if (tensor.name === TOKEN_TYPE_IDS_NAME) tensor.setData(int32ArrayBuffer(input.tokenTypeIds));
      else throw new Error('BGE model contains an unexpected input: ' + tensor.name);
    }
    const outputs = await this.model.predict(tensors);
    const result: BgeInferenceOutput[] = [];
    for (let index = 0; index < outputs.length; index += 1) {
      result.push({
        name: outputs[index].name,
        shape: outputs[index].shape.slice(),
        elementNum: outputs[index].elementNum,
        dtype: outputs[index].dtype,
        data: outputs[index].getData()
      });
    }
    return result;
  }
}

export class BgeMindSporeEmbeddingPort implements EmbeddingPort {
  readonly profileId: string = BGE_SMALL_ZH_PROFILE_ID;
  readonly dimension: number = BGE_SMALL_ZH_EMBEDDING_DIMENSION;
  private tokenizer: BgeTokenizerPort;
  private session: BgeInferenceSessionPort;
  private inferenceTail: Promise<void> = Promise.resolve();

  constructor(tokenizer: BgeTokenizerPort, session: BgeInferenceSessionPort) {
    validateInputSpecs(session.getInputSpecs());
    this.tokenizer = tokenizer;
    this.session = session;
  }

  static async fromRawfile(context: common.Context, tokenizer: BgeTokenizerPort): Promise<BgeMindSporeEmbeddingPort> {
    let modelBytes: Uint8Array;
    try {
      modelBytes = await context.resourceManager.getRawFileContent(BGE_SMALL_ZH_MODEL_RAWFILE);
    } catch (_error) {
      throw new Error('BGE model rawfile is missing or unreadable: ' + BGE_SMALL_ZH_MODEL_RAWFILE);
    }
    if (modelBytes.length === 0) {
      throw new Error('BGE model rawfile is empty: ' + BGE_SMALL_ZH_MODEL_RAWFILE);
    }
    let model: mindSporeLite.Model;
    try {
      model = await mindSporeLite.loadModelFromBuffer(modelArrayBuffer(modelBytes), {
        target: ['cpu'],
        cpu: { threadNum: 2, threadAffinityMode: mindSporeLite.ThreadAffinityMode.NO_AFFINITIES }
      });
    } catch (_error) {
      throw new Error('BGE model could not be loaded from rawfile: ' + BGE_SMALL_ZH_MODEL_RAWFILE);
    }
    return new BgeMindSporeEmbeddingPort(tokenizer, new MindSporeBgeInferenceSession(model));
  }

  embed(text: string): Promise<number[]> {
    const task = this.inferenceTail.then((): Promise<number[]> => this.embedOnce(text));
    this.inferenceTail = task.then((): void => {}, (_error: Object): void => {});
    return task;
  }

  private async embedOnce(text: string): Promise<number[]> {
    const normalizedText = text.trim();
    if (normalizedText.length === 0) throw new Error('BGE embedding text must not be empty');
    const tokenized = this.tokenizer.encode(normalizedText, BGE_SMALL_ZH_SEQUENCE_LENGTH);
    validateTokenizedInput(tokenized);
    const outputs = await this.session.predict(tokenized);
    if (outputs.length !== 1) throw new Error('BGE model must expose exactly one output');
    validateOutput(outputs[0]);
    const values = new Float32Array(outputs[0].data);
    const result: number[] = [];
    for (let index = 0; index < values.length; index += 1) result.push(values[index]);
    return result;
  }
}
