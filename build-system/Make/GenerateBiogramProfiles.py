import os
import plistlib
import subprocess
import tempfile
import shutil
import sys

SOURCE = "build-system/fake-codesigning/profiles"
DEST = "build-system/fake-codesigning/biogram-profiles"

TEAM_ID = "C67CF9S4VU"
BUNDLE_ID = "org.28d7790dd5d2e37c.Swiftgram"


def ensure_selfsigned_identity():
    """Ensure a SelfSigned identity exists in the macOS keychain.

    - If the certificate named "SelfSigned" exists, do nothing.
    - Otherwise generate a temporary self-signed cert with OpenSSL, create a
      PKCS#12 bundle, import it into the provided keychain (KEYCHAIN_PATH) and mark it trusted.

    This is a no-op on non-macOS platforms.
    """
    if sys.platform != "darwin":
        print("Not macOS: skipping SelfSigned identity creation")
        return

    # Allow overriding which keychain to import into via env var
    keychain = os.path.expanduser(os.environ.get("KEYCHAIN_PATH", "~/Library/Keychains/login.keychain-db"))

    try:
        subprocess.run(["security", "find-certificate", "-c", "SelfSigned"], check=True, stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL)
        print("SelfSigned identity already present in keychain")
        return
    except subprocess.CalledProcessError:
        pass

    print("SelfSigned identity not found: creating temporary self-signed certificate in keychain...")

    tmp = tempfile.mkdtemp(prefix="biogram-selfsign-")
    try:
        keyfile = os.path.join(tmp, "selfsign.key")
        crtfile = os.path.join(tmp, "selfsign.crt")
        p12file = os.path.join(tmp, "selfsign.p12")

        # generate key + cert
        subprocess.run([
            "openssl", "req", "-x509", "-nodes", "-newkey", "rsa:2048",
            "-keyout", keyfile, "-out", crtfile, "-days", "365",
            "-subj", "/CN=SelfSigned"
        ], check=True)

        # create PKCS#12 with empty password
        subprocess.run([
            "openssl", "pkcs12", "-export", "-inkey", keyfile, "-in", crtfile, "-out", p12file, "-passout", "pass:"
        ], check=True)

        # import to specified keychain (macOS)
        subprocess.run([
            "security", "import", p12file,
            "-k", keychain,
            "-P", "", "-A"
        ], check=True)

        # trust the certificate
        subprocess.run([
            "security", "add-trusted-cert", "-d", "-r", "trustRoot",
            "-k", keychain,
            crtfile
        ], check=True)

        # quick check
        subprocess.run(["security", "find-certificate", "-c", "SelfSigned"], check=True)

        print("Created and imported SelfSigned identity into:", keychain)
    finally:
        try:
            shutil.rmtree(tmp)
        except Exception:
            pass


os.makedirs(DEST, exist_ok=True)

# Ensure SelfSigned identity is present before we try to use it for signing
ensure_selfsigned_identity()

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
