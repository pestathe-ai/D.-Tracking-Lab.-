"""Applica le personalizzazioni Android dopo `flutter create`."""
import pathlib, re, shutil, sys

root = pathlib.Path(sys.argv[1] if len(sys.argv) > 1 else ".")
manifest = root / "android/app/src/main/AndroidManifest.xml"
m = manifest.read_text()

m = re.sub(r'android:label="[^"]*"', 'android:label="D. Tracking lab"', m, count=1)

perms = [
    "android.permission.INTERNET",
    "android.permission.CAMERA",
]
for p in perms:
    if p not in m:
        m = m.replace("<application", f'<uses-permission android:name="{p}"/>\n    <application', 1)

if "<queries>" not in m:
    # Permette di aprire i siti dei corrieri nel browser del telefono (Android 11+).
    queries = """    <queries>
        <intent>
            <action android:name="android.intent.action.VIEW"/>
            <data android:scheme="https"/>
        </intent>
        <intent>
            <action android:name="android.support.customtabs.action.CustomTabsService"/>
        </intent>
    </queries>
</manifest>"""
    m = m.replace("</manifest>", queries, 1)

if "ShareTrampolineActivity" not in m:
    activity = '''
        <activity
            android:name=".ShareTrampolineActivity"
            android:exported="true"
            android:label="Aggiungi a D. Tracking lab"
            android:excludeFromRecents="true"
            android:noHistory="true"
            android:theme="@android:style/Theme.Translucent.NoTitleBar">
            <intent-filter>
                <action android:name="android.intent.action.SEND"/>
                <category android:name="android.intent.category.DEFAULT"/>
                <data android:mimeType="text/plain"/>
            </intent-filter>
            <intent-filter>
                <action android:name="android.intent.action.PROCESS_TEXT"/>
                <category android:name="android.intent.category.DEFAULT"/>
                <data android:mimeType="text/plain"/>
            </intent-filter>
        </activity>
    </application>'''
    m = m.replace("</application>", activity, 1)

manifest.write_text(m)

kotlin = root / "android/app/src/main/kotlin/dev/dtrackinglab/d_tracking_lab"
kotlin.mkdir(parents=True, exist_ok=True)
for f in ("MainActivity.kt", "ShareTrampolineActivity.kt"):
    shutil.copy(root / "tool/android" / f, kotlin / f)

print("patch android ok")
print(manifest.read_text())
