#!/usr/bin/env bash
set -euo pipefail

PROJECT="Chowser.xcodeproj"
DESTINATION="platform=macOS"

echo "Running unit tests..."
xcodebuild test \
  -project "$PROJECT" \
  -scheme Chowser \
  -destination "$DESTINATION" \
  -only-testing:ChowserTests

echo "Running UI end-to-end tests..."
xcodebuild test \
  -project "$PROJECT" \
  -scheme ChowserUITests \
  -destination "$DESTINATION"

echo "All tests completed."
