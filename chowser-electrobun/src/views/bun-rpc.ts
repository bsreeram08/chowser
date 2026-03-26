/**
 * RPC client for communicating with the Bun backend
 * This provides a type-safe wrapper around Electrobun's RPC mechanism
 */

export const rpc = {
  async call<K extends string>(
    method: K,
    params: any
  ): Promise<any> {
    // @ts-ignore - Electrobun provides window.Electrobun at runtime
    if (!window.Electrobun) {
      throw new Error('Electrobun RPC not available');
    }

    // @ts-ignore
    return window.Electrobun.invoke(method, params);
  },
};
