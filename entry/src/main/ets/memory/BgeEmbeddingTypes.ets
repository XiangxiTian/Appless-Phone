/** Fixed input contract exported by bge-small-zh-v1.5 for phone inference. */
export interface BgeTokenizedInput {
  inputIds: Int32Array;
  attentionMask: Int32Array;
  tokenTypeIds: Int32Array;
}

/** Tokenizer boundary kept independent from the MindSpore runtime adapter. */
export interface BgeTokenizerPort {
  encode(text: string, sequenceLength: number): BgeTokenizedInput;
}
