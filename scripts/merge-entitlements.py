#!/usr/bin/env python3
"""Build the entitlements to sign a bundle with.

    merge-entitlements.py <profile-entitlements.plist> <bundle-entitlements.plist> <out.plist>

A development profile grants entitlements as a template full of wildcards
(`icloud-services = *`, `icloud-container-environment = [Production,
Development]`, `keychain-access-groups = TEAM.*`). Xcode never signs with
that template as-is: it takes the app's own entitlements and checks them
against it. CloudKit in particular aborts at launch unless
`icloud-services` is an array containing "CloudKit".

So: start from the profile's grants, replace every key the bundle declared
itself (its ad-hoc signature carries Config/App.entitlements) with the
bundle's concrete value, and pin the CloudKit environment to Development,
which is what a development profile is for. Keys the bundle declares but
the profile does not grant are dropped with a warning: signing with them
would make the install fail.
"""
import plistlib
import sys

profile_path, bundle_path, out_path = sys.argv[1:4]
with open(profile_path, "rb") as f:
    profile = plistlib.load(f)
with open(bundle_path, "rb") as f:
    raw = f.read()
# A bundle signed without an entitlements file declares nothing.
bundle = plistlib.loads(raw) if raw.strip() else {}

merged = dict(profile)
for key, value in bundle.items():
    if key in profile:
        merged[key] = value
    else:
        print(f"warning: profile does not grant {key}; dropping it", file=sys.stderr)

ENV = "com.apple.developer.icloud-container-environment"
if ENV in merged:
    merged[ENV] = "Development"

with open(out_path, "wb") as f:
    plistlib.dump(merged, f)
