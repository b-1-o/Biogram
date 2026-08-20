import os
import plistlib
import subprocess
import tempfile
import shutil

SOURCE = "build-system/fake-codesigning/profiles"
DEST = "build-system/fake-codesigning/biogram-profiles"

TEAM_ID = "C67CF9S4VU"
BUNDLE_ID = "org.28d7790dd5d2e37c.Swiftgram"

os.makedirs(DEST, exist_ok=True)

mapping = {
    "Telegram.mobileprovision": "Telegram.mobileprovision",
    "NotificationService.mobileprovision": "NotificationService.mobileprovision",
    "NotificationContent.mobileprovision": "NotificationContent.mobileprovision",
    "Share.mobileprovision": "Share.mobileprovision",
    "Intents.mobileprovision": "Intents.mobileprovision",
    "Widget.mobileprovision": "Widget.mobileprovision",
    "BroadcastUpload.mobileprovision": "BroadcastUpload.mobileprovision",
    "WatchApp.mobileprovision": "WatchApp.mobileprovision",
    "WatchExtension.mobileprovision": "WatchExtension.mobileprovision",
}

for filename, output_name in mapping.items():
    source = os.path.join(SOURCE, filename)
    output = os.path.join(DEST, output_name)

    if not os.path.exists(source):
        print("Skipping missing:", source)
        continue

    print("Processing:", filename)

    raw = subprocess.check_output([
        "security", "cms", "-D", "-i", source
    ])

    profile = plistlib.loads(raw)

    ent = profile["Entitlements"]

    if filename == "Telegram.mobileprovision":
        profile_bundle = BUNDLE_ID
    elif filename == "NotificationService.mobileprovision":
        profile_bundle = BUNDLE_ID + ".NotificationService"
    elif filename == "NotificationContent.mobileprovision":
        profile_bundle = BUNDLE_ID + ".NotificationContent"
    elif filename == "Share.mobileprovision":
        profile_bundle = BUNDLE_ID + ".Share"
    elif filename == "Intents.mobileprovision":
        profile_bundle = BUNDLE_ID + ".SiriIntents"
    elif filename == "Widget.mobileprovision":
        profile_bundle = BUNDLE_ID + ".Widget"
    elif filename == "BroadcastUpload.mobileprovision":
        profile_bundle = BUNDLE_ID + ".BroadcastUpload"
    elif filename == "WatchApp.mobileprovision":
        profile_bundle = BUNDLE_ID + ".watchkitapp"
    elif filename == "WatchExtension.mobileprovision":
        profile_bundle = BUNDLE_ID + ".watchkitapp.watchkitextension"
    else:
        profile_bundle = BUNDLE_ID

    ent["application-identifier"] = TEAM_ID + "." + profile_bundle
    ent["com.apple.developer.team-identifier"] = TEAM_ID

    if filename == "Telegram.mobileprovision":
        ent["aps-environment"] = "production"

    profile["Entitlements"] = ent

    # Make profile match fake signing identity
    if "ApplicationIdentifierPrefix" in profile:
        profile["ApplicationIdentifierPrefix"] = [TEAM_ID + "."]

    # Remove original signature before re-signing
    profile.pop("DER-Encoded-Profile", None)

    temp = tempfile.mktemp(suffix=".plist")

    with open(temp, "wb") as f:
        plistlib.dump(profile, f)

    subprocess.run([
        "security",
        "cms",
        "-S",
        "-N",
        "SelfSigned",
        "-i",
        temp,
        "-o",
        output
    ], check=True)

    os.unlink(temp)

    print("Created:", output)

print("")
print("========================================")
print("Biogram fake provisioning profiles ready")
print("TEAM_ID:", TEAM_ID)
print("BUNDLE_ID:", BUNDLE_ID)
print("========================================")
