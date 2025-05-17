xcodebuild docbuild -scheme shortcut-detection-kit -destination 'generic/platform=macOS' -derivedDataPath "$PWD/.derivedData"
$(xcrun --find docc) process-archive \
  transform-for-static-hosting "$PWD/.derivedData/Build/Products/Debug/ShortcutDetectionKit.doccarchive" \
  --output-path docs \
  --hosting-base-path "shortcut-detection-kit"

echo "<script>window.location.href += \"/documentation/shortcutdetectionkit\"</script>" > docs/index.html;
