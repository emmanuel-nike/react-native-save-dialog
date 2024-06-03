import * as React from 'react'

import { StyleSheet, View, Text, Button } from 'react-native'
import SaveDialog, { SaveDialogResponse, isCancel, isInProgress } from '../src'
import { useEffect } from 'react'

export default function App() {
  const [result, setResult] = React.useState<
    Array<SaveDialogResponse> | SaveDialogResponse | undefined | null
  >()

  useEffect(() => {
    console.log(JSON.stringify(result, null, 2))
  }, [result])

  const handleError = (err: unknown) => {
    if (isCancel(err)) {
      console.warn('cancelled')
      // User cancelled the picker, exit any dialogs or menus and move on
    } else if (isInProgress(err)) {
      console.warn('multiple pickers were opened, only the last will be considered')
    } else {
      throw err
    }
  }

  return (
    <View style={styles.container}>
      <Button
        title="open dialog to save text file selection"
        onPress={async () => {
          try {
            const res = await SaveDialog.saveFile({
              presentationStyle: 'fullScreen',
              saveTo: 'cachesDirectory',
              path: 'test.txt',
            })
            setResult(res)
          } catch (e) {
            handleError(e)
          }
        }}
      />

      <Button
        title="releaseSecureAccess"
        onPress={() => {
          SaveDialog.releaseSecureAccess([])
            .then(() => {
              console.warn('releaseSecureAccess: success')
            })
            .catch(handleError)
        }}
      />

      <Text selectable>Result: {JSON.stringify(result, null, 2)}</Text>
    </View>
  )
}

const styles = StyleSheet.create({
  container: {
    flex: 1,
    alignItems: 'center',
    justifyContent: 'center',
    backgroundColor: 'white',
  },
  box: {
    width: 60,
    height: 60,
    marginVertical: 20,
  },
})
