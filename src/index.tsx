import { Platform, type ModalPropsIOS } from 'react-native'
import invariant from 'invariant'
import { NativeSaveDialog } from './NativeSaveDialog'

export type SaveDialogResponse = {
  uri: string
  name: string | null
  copyError?: string
  fileCopyUri: string | null
  type: string | null
  size: number | null
}

export type TransitionStyle = 'coverVertical' | 'flipHorizontal' | 'crossDissolve' | 'partialCurl'

export type SaveDialogOptions = {
  saveTo?: 'cachesDirectory' | 'documentDirectory'
  transitionStyle?: TransitionStyle
  path?: string
} & Pick<ModalPropsIOS, 'presentationStyle'>

export function saveFile(opts?: SaveDialogOptions): Promise<SaveDialogResponse[]> {
  const options = {
    ...opts,
  }

  if (
    'copyTo' in options &&
    !['cachesDirectory', 'documentDirectory'].includes(options.saveTo ?? '')
  ) {
    throw new TypeError('Invalid copyTo option: ' + options.copyTo)
  }

  return NativeSaveDialog.saveFile(options)
}

export function releaseSecureAccess(uris: Array<string>): Promise<void> {
  if (Platform.OS !== 'ios') {
    return Promise.resolve()
  }

  invariant(
    Array.isArray(uris) && uris.every((uri) => typeof uri === 'string'),
    `"uris" should be an array of strings, was ${uris}`,
  )

  return NativeSaveDialog.releaseSecureAccess(uris)
}

const E_DOCUMENT_PICKER_CANCELED = 'DOCUMENT_PICKER_CANCELED'
const E_DOCUMENT_PICKER_IN_PROGRESS = 'ASYNC_OP_IN_PROGRESS'

export type NativeModuleErrorShape = Error & { code?: string }

export function isCancel(err: unknown): boolean {
  return isErrorWithCode(err, E_DOCUMENT_PICKER_CANCELED)
}

export function isInProgress(err: unknown): boolean {
  return isErrorWithCode(err, E_DOCUMENT_PICKER_IN_PROGRESS)
}

function isErrorWithCode(err: unknown, errorCode: string): boolean {
  if (err && typeof err === 'object' && 'code' in err) {
    const nativeModuleErrorInstance = err as NativeModuleErrorShape
    return nativeModuleErrorInstance?.code === errorCode
  }
  return false
}

export default {
  isCancel,
  isInProgress,
  releaseSecureAccess,
  saveFile,
}
