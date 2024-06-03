import type { TurboModule } from "react-native";
import { TurboModuleRegistry } from "react-native";

export type SaveDialogResponse = {
  uri: string;
  name: string;
  copyError?: string;
  fileCopyUri: string | null;
  type: string | null;
  size: number | null;
};

export interface Spec extends TurboModule {
  readonly getConstants: () => {};
  saveFile(options: Object): Promise<SaveDialogResponse[]>;
  releaseSecureAccess(uris: string[]): Promise<void>;
}

export const NativeSaveDialog =
  TurboModuleRegistry.getEnforcing<Spec>("RNSaveDialog");
