import { NativeModules } from "react-native";

export type SaveDialogResponse = {
  uri: string;
  name: string;
  copyError?: string;
  fileCopyUri: string | null;
  type: string | null;
  size: number | null;
};

export interface Spec {
  readonly getConstants: () => {};
  saveFile(options: Object): Promise<SaveDialogResponse[]>;
  releaseSecureAccess(uris: string[]): Promise<void>;
}

export const NativeSaveDialog = NativeModules.RNSaveDialog as Spec;
