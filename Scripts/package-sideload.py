"""Create an IPA that retains App Groups for SideStore to re-sign with the user's account.

The local ad-hoc code signature is NOT an Apple provisioning profile and cannot
install the app by itself. No Apple account or private signing key is used here.
"""
from pathlib import Path
import plistlib
import shutil
import subprocess

root = Path(__file__).resolve().parents[1]
original = root / 'build/Device/Build/Products/Release-iphoneos/WordReview.app'
payload = root / 'build/Sideload/Payload'
app = payload / 'WordReview.app'
payload.mkdir(parents=True, exist_ok=True)
shutil.copytree(original, app, dirs_exist_ok=True)
for binary in app.rglob('*.dylib'):
    subprocess.run(['codesign', '--force', '--sign', '-', str(binary)], check=True)
bundles = list(app.glob('PlugIns/*.appex')) + [app]
for bundle in bundles:
    info = plistlib.loads((bundle / 'Info.plist').read_bytes())
    group = info['ReviewAppGroup']
    assert group.startswith('group.') and '$' not in group
    entitlements = {'com.apple.security.application-groups': [group]}
    entitlements_path = payload.parent / (bundle.stem + '.entitlements')
    entitlements_path.write_bytes(plistlib.dumps(entitlements))
    subprocess.run(['codesign', '--force', '--sign', '-', '--entitlements', str(entitlements_path), str(bundle)], check=True)
    extracted = subprocess.check_output(['codesign', '-d', '--entitlements', ':-', str(bundle)])
    assert plistlib.loads(extracted)['com.apple.security.application-groups'] == [group]
    subprocess.run(['codesign', '--verify', '--strict', str(bundle)], check=True)
    print('Verified shared group:', info['CFBundleIdentifier'], group)
subprocess.run(['ditto', '-c', '-k', '--keepParent', str(payload), str(root / 'build/WordReview-0.1.0-SideStore.ipa')], check=True)
print('IPA prepared. SideStore must still sign it with the user account before installation.')
