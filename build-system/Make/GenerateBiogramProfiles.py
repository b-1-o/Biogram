import os
import plistlib
import subprocess
import tempfile
import shutil


SOURCE = "build-system/fake-codesigning/profiles"
DEST = "build-system/fake-codesigning/profiles"

TEAM_ID = "FAKE123456"
BUNDLE_ID = "org.28d7790dd5d2e37c.Swiftgram"


PROFILE_MAPPING = {
    "Telegram.mobileprovision": "",
    "NotificationService.mobileprovision": ".NotificationService",
    "NotificationContent.mobileprovision": ".NotificationContent",
    "Share.mobileprovision": ".Share",
    "Intents.mobileprovision": ".SiriIntents",
    "Widget.mobileprovision": ".Widget",
    "BroadcastUpload.mobileprovision": ".BroadcastUpload",
    "WatchApp.mobileprovision": ".watchkitapp",
    "WatchExtension.mobileprovision": ".watchkitapp.watchkitextension",
}


def decode_profile(path):
    data = subprocess.check_output(
        [
            "security",
            "cms",
            "-D",
            "-i",
            path,
        ]
    )

    return plistlib.loads(data)


def encode_profile(profile, output):
    temp = tempfile.NamedTemporaryFile(
        suffix=".plist",
        delete=False
    )

    temp_path = temp.name

    try:
        with temp:
            plistlib.dump(profile, temp)

        subprocess.run(
            [
                "security",
                "cms",
                "-S",
                "-N",
                "SelfSigned",
                "-i",
                temp_path,
                "-o",
                output,
            ],
            check=True,
        )
    finally:
        if os.path.exists(temp_path):
            os.unlink(temp_path)


def process_profile(filename, suffix):
    source = os.path.join(SOURCE, filename)
    output = os.path.join(DEST, filename)

    if not os.path.exists(source):
        raise RuntimeError(
            "Missing provisioning profile: {}".format(source)
        )

    print()
    print("Processing:", filename)

    profile = decode_profile(source)

    entitlements = profile.setdefault("Entitlements", {})

    profile_bundle_id = BUNDLE_ID + suffix

    entitlements["application-identifier"] = (
        TEAM_ID + "." + profile_bundle_id
    )

    entitlements["com.apple.developer.team-identifier"] = TEAM_ID

    if filename == "Telegram.mobileprovision":
        entitlements["aps-environment"] = "production"

    if "ApplicationIdentifierPrefix" in profile:
        profile["ApplicationIdentifierPrefix"] = [
            TEAM_ID + "."
        ]

    profile["Entitlements"] = entitlements

    profile.pop("DER-Encoded-Profile", None)

    encode_profile(profile, output)

    print("Created:", output)

    print(
        "application-identifier:",
        entitlements["application-identifier"]
    )

    if "aps-environment" in entitlements:
        print(
            "aps-environment:",
            entitlements["aps-environment"]
        )


def main():
    if not os.path.isdir(SOURCE):
        raise RuntimeError(
            "Provisioning directory does not exist: {}".format(SOURCE)
        )

    print("========================================")
    print("Generating Biogram fake provisioning")
    print("profiles")
    print("========================================")
    print("TEAM_ID:", TEAM_ID)
    print("BUNDLE_ID:", BUNDLE_ID)
    print("SOURCE:", SOURCE)
    print("DEST:", DEST)
    print("========================================")

    for filename, suffix in PROFILE_MAPPING.items():
        process_profile(filename, suffix)

    print()
    print("========================================")
    print("Biogram fake provisioning profiles ready")
    print("========================================")
    print("TEAM_ID:", TEAM_ID)
    print("BUNDLE_ID:", BUNDLE_ID)
    print("APS:", "production")
    print("========================================")


if __name__ == "__main__":
    main()
