import { describe, expect, it } from '@ohos/hypium';
import { BgeTokenizedInput, BgeTokenizerPort } from '../main/ets/memory/BgeEmbeddingTypes';
import {
  BGE_SMALL_ZH_EMBEDDING_DIMENSION,
  BGE_SMALL_ZH_MODEL_SHA256,
  BGE_SMALL_ZH_PROFILE_ID,
  BGE_SMALL_ZH_SEQUENCE_LENGTH,
  BgeInferenceOutput,
  BgeInferenceSessionPort,
  BgeMindSporeEmbeddingPort,
  BgeTensorSpec
} from '../main/ets/memory/BgeMindSporeEmbeddingPort';

function int32Values(length: number, value: number): Int32Array {
  const result = new Int32Array(length);
  result.fill(value);
  return result;
}

function validTokenizedInput(): BgeTokenizedInput {
  return {
    inputIds: int32Values(BGE_SMALL_ZH_SEQUENCE_LENGTH, 7),
    attentionMask: int32Values(BGE_SMALL_ZH_SEQUENCE_LENGTH, 1),
    tokenTypeIds: int32Values(BGE_SMALL_ZH_SEQUENCE_LENGTH, 0)
  };
}

class RecordingTokenizer implements BgeTokenizerPort {
  text: string = '';
  sequenceLength: number = 0;
  output: BgeTokenizedInput = validTokenizedInput();

  encode(text: string, sequenceLength: number): BgeTokenizedInput {
    this.text = text;
    this.sequenceLength = sequenceLength;
    return this.output;
  }
}

function inputSpec(name: string): BgeTensorSpec {
  return { name, shape: [1, BGE_SMALL_ZH_SEQUENCE_LENGTH], elementNum: BGE_SMALL_ZH_SEQUENCE_LENGTH, dtype: 34 };
}

function validInputSpecs(): BgeTensorSpec[] {
  return [inputSpec('attention_mask'), inputSpec('input_ids'), inputSpec('token_type_ids')];
}

function validOutput(): BgeInferenceOutput {
  const values = new Float32Array(BGE_SMALL_ZH_EMBEDDING_DIMENSION);
  values[0] = 0.25;
  values[BGE_SMALL_ZH_EMBEDDING_DIMENSION - 1] = -0.5;
  return {
    name: 'raw_cls',
    shape: [1, BGE_SMALL_ZH_EMBEDDING_DIMENSION],
    elementNum: BGE_SMALL_ZH_EMBEDDING_DIMENSION,
    dtype: 43,
    data: values.buffer as ArrayBuffer
  };
}

class FakeBgeSession implements BgeInferenceSessionPort {
  specs: BgeTensorSpec[] = validInputSpecs();
  outputs: BgeInferenceOutput[] = [validOutput()];
  received?: BgeTokenizedInput;

  getInputSpecs(): BgeTensorSpec[] {
    return this.specs;
  }

  async predict(input: BgeTokenizedInput): Promise<BgeInferenceOutput[]> {
    this.received = input;
    return this.outputs;
  }
}

export default function bgeMindSporeEmbeddingPortTest() {
  describe('BgeMindSporeEmbeddingPort', () => {
    it('uses the fixed tokenizer contract and returns the 512-dimensional FP32 output', 0, async () => {
      const tokenizer = new RecordingTokenizer();
      const session = new FakeBgeSession();
      const embedding = new BgeMindSporeEmbeddingPort(tokenizer, session);

      const result = await embedding.embed('  用户喜欢无糖咖啡。  ');

      expect(embedding.dimension).assertEqual(512);
      expect(embedding.profileId).assertEqual(BGE_SMALL_ZH_PROFILE_ID);
      expect(embedding.profileId.indexOf(BGE_SMALL_ZH_MODEL_SHA256) >= 0).assertTrue();
      expect(embedding.profileId.indexOf('seq=128') >= 0).assertTrue();
      expect(tokenizer.text).assertEqual('用户喜欢无糖咖啡。');
      expect(tokenizer.sequenceLength).assertEqual(128);
      expect(session.received !== undefined).assertTrue();
      expect(result.length).assertEqual(512);
      expect(result[0]).assertEqual(0.25);
      expect(result[511]).assertEqual(-0.5);
    });

    it('rejects a model whose three input tensors do not match the exported contract', 0, () => {
      const session = new FakeBgeSession();
      session.specs = [inputSpec('input_ids'), inputSpec('attention_mask'), {
        name: 'token_type_ids', shape: [1, 64], elementNum: 64, dtype: 34
      }];
      let message: string = '';

      try {
        new BgeMindSporeEmbeddingPort(new RecordingTokenizer(), session);
      } catch (error) {
        message = error instanceof Error ? error.message : 'unknown';
      }

      expect(message).assertEqual('BGE input shape mismatch: token_type_ids');
    });

    it('rejects tokenizer output that does not contain three fixed 128-element arrays', 0, async () => {
      const tokenizer = new RecordingTokenizer();
      tokenizer.output = {
        inputIds: int32Values(127, 7),
        attentionMask: int32Values(128, 1),
        tokenTypeIds: int32Values(128, 0)
      };
      const embedding = new BgeMindSporeEmbeddingPort(tokenizer, new FakeBgeSession());
      let message: string = '';

      try {
        await embedding.embed('用户喜欢无糖咖啡。');
      } catch (error) {
        message = error instanceof Error ? error.message : 'unknown';
      }

      expect(message).assertEqual('BGE tokenizer must return three 128-element INT32 arrays');
    });

    it('rejects a prediction output that is not one [1,512] FP32 tensor', 0, async () => {
      const session = new FakeBgeSession();
      const invalid = validOutput();
      invalid.dtype = 42;
      session.outputs = [invalid];
      const embedding = new BgeMindSporeEmbeddingPort(new RecordingTokenizer(), session);
      let message: string = '';

      try {
        await embedding.embed('用户喜欢无糖咖啡。');
      } catch (error) {
        message = error instanceof Error ? error.message : 'unknown';
      }

      expect(message).assertEqual('BGE output dtype mismatch');
    });

    it('rejects a prediction output whose exported tensor name changed', 0, async () => {
      const session = new FakeBgeSession();
      const invalid = validOutput();
      invalid.name = 'sentence_embedding';
      session.outputs = [invalid];
      const embedding = new BgeMindSporeEmbeddingPort(new RecordingTokenizer(), session);
      let message: string = '';

      try {
        await embedding.embed('用户喜欢无糖咖啡。');
      } catch (error) {
        message = error instanceof Error ? error.message : 'unknown';
      }

      expect(message).assertEqual('BGE output name mismatch: sentence_embedding');
    });
  });
}
