import base64
import os
import pathlib
import plistlib
import subprocess

temporary = pathlib.Path(os.environ['RUNNER_TEMP']) / 'bubblequest.mobileprovision'
temporary.write_bytes(base64.b64decode(os.environ['PROFILE_BASE64']))
profile = plistlib.loads(subprocess.check_output(['security', 'cms', '-D', '-i', str(temporary)]))
team = profile['TeamIdentifier'][0]
bundle = os.environ['BUNDLE_ID']
application = profile['Entitlements']['application-identifier']
if application.split('.', 1)[1] != bundle:
    raise SystemExit('Provisioning profile does not match the configured bundle ID')
if 'ProvisionedDevices' in profile or profile.get('ProvisionsAllDevices'):
    raise SystemExit('TestFlight requires an App Store distribution profile')
destination = pathlib.Path.home() / 'Library/MobileDevice/Provisioning Profiles'
destination.mkdir(parents=True, exist_ok=True)
(destination / (profile['UUID'] + '.mobileprovision')).write_bytes(temporary.read_bytes())
with open(os.environ['GITHUB_OUTPUT'], 'a') as output:
    output.write('team=' + team + '\nprofile=' + profile['UUID'] + '\n')
pathlib.Path('build').mkdir(exist_ok=True)
with open('build/ExportOptions.plist', 'wb') as output:
    plistlib.dump({'method': 'app-store-connect', 'teamID': team, 'signingStyle': 'manual',
                  'signingCertificate': 'Apple Distribution', 'provisioningProfiles': {bundle: profile['UUID']},
                  'manageAppVersionAndBuildNumber': False}, output)
