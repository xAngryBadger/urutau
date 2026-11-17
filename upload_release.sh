#!/bin/bash
set -e

REPO="xAngryBadger/urutau"
TAG="v2.0.2"
APK_PATH="urutau-app/build/app/outputs/flutter-apk/app-release.apk"
SHA256="e0c801208462a8cc2ff503b710cb2ea2fd3735bb1650abcd20457cfc8d71dbd4"

if [ -z "$GITHUB_TOKEN" ]; then
    echo "ERROR: GITHUB_TOKEN not set"
    exit 1
fi

# Create release if it doesn't exist, or get existing release
echo "Checking/creating release for tag $TAG..."
RELEASE_RESPONSE=$(curl -s -H "Authorization: token $GITHUB_TOKEN" \
    -H "Accept: application/vnd.github.v3+json" \
    "https://api.github.com/repos/$REPO/releases/tags/$TAG")

RELEASE_ID=$(echo "$RELEASE_RESPONSE" | jq -r '.id // empty')
UPLOAD_URL=$(echo "$RELEASE_RESPONSE" | jq -r '.upload_url // empty' | sed 's/{?name,label}//')

if [ -z "$RELEASE_ID" ] || [ "$RELEASE_ID" = "null" ]; then
    echo "Creating new release..."
    RELEASE_RESPONSE=$(curl -s -X POST -H "Authorization: token $GITHUB_TOKEN" \
        -H "Accept: application/vnd.github.v3+json" \
        "https://api.github.com/repos/$REPO/releases" \
        -d "{\"tag_name\":\"$TAG\",\"name\":\"Release $TAG\",\"draft\":false,\"prerelease\":false}")
    
    RELEASE_ID=$(echo "$RELEASE_RESPONSE" | jq -r '.id // empty')
    UPLOAD_URL=$(echo "$RELEASE_RESPONSE" | jq -r '.upload_url // empty' | sed 's/{?name,label}//')
fi

if [ -z "$RELEASE_ID" ] || [ "$RELEASE_ID" = "null" ]; then
    echo "ERROR: Failed to create/get release"
    echo "$RELEASE_RESPONSE"
    exit 1
fi

echo "Release ID: $RELEASE_ID"
echo "Upload URL: $UPLOAD_URL"

# Upload APK
echo "Uploading APK..."
UPLOAD_RESPONSE=$(curl -s -X POST -H "Authorization: token $GITHUB_TOKEN" \
    -H "Accept: application/vnd.github.v3+json" \
    -H "Content-Type: application/vnd.android.package-archive" \
    --data-binary @"$APK_PATH" \
    "$UPLOAD_URL?name=urutau-v2.0.2.apk")

ASSET_ID=$(echo "$UPLOAD_RESPONSE" | jq -r '.id // empty')
if [ -z "$ASSET_ID" ] || [ "$ASSET_ID" = "null" ]; then
    echo "ERROR: Failed to upload APK"
    echo "$UPLOAD_RESPONSE"
    exit 1
fi

echo "APK uploaded successfully! Asset ID: $ASSET_ID"

# Update release body with SHA256
RELEASE_BODY=$(cat docs/release-notes-v2.0.2-prontas.md)
curl -s -X PATCH -H "Authorization: token $GITHUB_TOKEN" \
    -H "Accept: application/vnd.github.v3+json" \
    "https://api.github.com/repos/$REPO/releases/$RELEASE_ID" \
    -d "{\"body\":$(echo "$RELEASE_BODY" | jq -Rs .)}" > /dev/null

echo "Release updated with release notes including SHA256: $SHA256"
echo "Done!"
