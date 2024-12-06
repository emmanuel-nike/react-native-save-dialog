import { Platform, type ModalPropsIOS } from 'react-native';
import invariant from 'invariant';
import { NativeSaveDialog } from './NativeSaveDialog';

const mimeTypes = Object.freeze({
  allFiles: '*/*',
  audio: 'audio/*',
  csv: 'text/csv',
  doc: 'application/msword',
  docx: 'application/vnd.openxmlformats-officedocument.wordprocessingml.document',
  images: 'image/*',
  json: 'application/json',
  pdf: 'application/pdf',
  plainText: 'text/plain',
  ppt: 'application/vnd.ms-powerpoint',
  pptx: 'application/vnd.openxmlformats-officedocument.presentationml.presentation',
  video: 'video/*',
  xls: 'application/vnd.ms-excel',
  xlsx: 'application/vnd.openxmlformats-officedocument.spreadsheetml.sheet',
  zip: 'application/zip',
} as const);

const utis = Object.freeze({
  allFiles: 'public.item',
  audio: 'public.audio',
  csv: 'public.comma-separated-values-text',
  doc: 'com.microsoft.word.doc',
  docx: 'org.openxmlformats.wordprocessingml.document',
  images: 'public.image',
  json: 'public.json',
  pdf: 'com.adobe.pdf',
  plainText: 'public.plain-text',
  ppt: 'com.microsoft.powerpoint.ppt',
  pptx: 'org.openxmlformats.presentationml.presentation',
  video: 'public.movie',
  xls: 'com.microsoft.excel.xls',
  xlsx: 'org.openxmlformats.spreadsheetml.sheet',
  zip: 'public.zip-archive',
} as const);

const extensions = Object.freeze({
  allFiles: '*',
  audio:
    '.3g2 .3gp .aac .adt .adts .aif .aifc .aiff .asf .au .m3u .m4a .m4b .mid .midi .mp2 .mp3 .mp4 .rmi .snd .wav .wax .wma',
  csv: '.csv',
  doc: '.doc',
  docx: '.docx',
  images: '.jpeg .jpg .png',
  json: '.json',
  pdf: '.pdf',
  plainText: '.txt',
  ppt: '.ppt',
  pptx: '.pptx',
  video: '.mp4',
  xls: '.xls',
  xlsx: '.xlsx',
  zip: '.zip .gz',
} as const);

export type PlatformTypes = typeof mimeTypes | typeof utis | typeof extensions;

export const perPlatformTypes = {
  android: mimeTypes,
  ios: utis,
  windows: extensions,
  // unsupported, but added to make TS happy
  macos: extensions,
  web: extensions,
};

export const types = perPlatformTypes[Platform.OS];

export type SaveDialogResponse = {
  uri: string;
  name: string | null;
  copyError?: string;
  fileCopyUri: string | null;
  type: string | null;
  size: number | null;
};

export type TransitionStyle = 'coverVertical' | 'flipHorizontal' | 'crossDissolve' | 'partialCurl';

export type SaveDialogOptions = {
  saveTo?: 'cachesDirectory' | 'documentDirectory';
  transitionStyle?: TransitionStyle;
  path?: string;
  type?: string[];
} & Pick<ModalPropsIOS, 'presentationStyle'>;

export type DocumentPickerOptions = {
  type?: string | Array<PlatformTypes | string>;
  copyTo?: 'cachesDirectory' | 'documentDirectory';
  transitionStyle?: TransitionStyle;
} & Pick<ModalPropsIOS, 'presentationStyle'>;

type DoPickParams = DocumentPickerOptions & {
  type: Array<PlatformTypes | string>;
  presentationStyle: NonNullable<ModalPropsIOS['presentationStyle']>;
  transitionStyle: TransitionStyle;
};

export function saveFile(opts?: SaveDialogOptions): Promise<SaveDialogResponse[]> {
  const options = {
    ...opts,
    type: opts?.type ?? [],
  };

  if (
    'saveTo' in options &&
    !['cachesDirectory', 'documentDirectory'].includes(options.saveTo ?? '')
  ) {
    throw new TypeError('Invalid saveTo option: ' + options.saveTo);
  }

  return NativeSaveDialog.saveFile(options);
}

export function pick(opts?: DocumentPickerOptions): Promise<SaveDialogResponse[]> {
  const options = {
    type: [types.allFiles],
    ...opts,
  };

  const newOpts: DoPickParams = {
    presentationStyle: 'formSheet',
    transitionStyle: 'coverVertical',
    ...options,
    type: Array.isArray(options.type) ? options.type : [options.type],
  };

  return doPick(newOpts);
}

function doPick(options: DoPickParams): Promise<SaveDialogResponse[]> {
  invariant(
    !('filetype' in options),
    'A `filetype` option was passed to DocumentPicker.pick, the correct option is `type`'
  );
  invariant(
    !('types' in options),
    'A `types` option was passed to DocumentPicker.pick, the correct option is `type`'
  );

  invariant(
    options.type.every((type: unknown) => typeof type === 'string'),
    `Unexpected type option in ${options.type}, did you try using a DocumentPicker.types.* that does not exist?`
  );
  invariant(
    options.type.length > 0,
    '`type` option should not be an empty array, at least one type must be passed if the `type` option is not omitted'
  );

  if (
    'copyTo' in options &&
    !['cachesDirectory', 'documentDirectory'].includes(options.copyTo ?? '')
  ) {
    throw new TypeError('Invalid copyTo option: ' + options.copyTo);
  }

  return NativeSaveDialog.pick(options);
}

export function releaseSecureAccess(uris: Array<string>): Promise<void> {
  if (Platform.OS !== 'ios') {
    return Promise.resolve();
  }

  invariant(
    Array.isArray(uris) && uris.every((uri) => typeof uri === 'string'),
    `"uris" should be an array of strings, was ${uris}`
  );

  return NativeSaveDialog.releaseSecureAccess(uris);
}

const E_SAVE_DIALOG_CANCELED = 'SAVE_DIALOG_CANCELED';
const E_SAVE_DIALOG_IN_PROGRESS = 'ASYNC_OP_IN_PROGRESS';

export type NativeModuleErrorShape = Error & { code?: string };

export function isCancel(err: unknown): boolean {
  return isErrorWithCode(err, E_SAVE_DIALOG_CANCELED);
}

export function isInProgress(err: unknown): boolean {
  return isErrorWithCode(err, E_SAVE_DIALOG_IN_PROGRESS);
}

function isErrorWithCode(err: unknown, errorCode: string): boolean {
  if (err && typeof err === 'object' && 'code' in err) {
    const nativeModuleErrorInstance = err as NativeModuleErrorShape;
    return nativeModuleErrorInstance?.code === errorCode;
  }
  return false;
}

export default {
  isCancel,
  isInProgress,
  releaseSecureAccess,
  saveFile,
  pick,
  types,
};
