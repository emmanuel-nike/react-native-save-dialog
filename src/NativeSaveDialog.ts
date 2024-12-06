import { NativeModules } from 'react-native';

export type DialogResponse = {
  uri: string;
  name: string;
  copyError?: string;
  fileCopyUri: string | null;
  type: string | null;
  size: number | null;
};

export type DirectoryResponse = {
  uri: string;
};

export interface Spec {
  readonly getConstants: () => {};
  pick(options: Object): Promise<DialogResponse[]>;
  pickDirectory(): Promise<DirectoryResponse>;
  saveFile(options: Object): Promise<DialogResponse[]>;
  releaseSecureAccess(uris: string[]): Promise<void>;
}

export const NativeSaveDialog = NativeModules.RNSaveDialog as Spec;
