#!/bin/bash
set -e

echo "=== Testing CI Workflow Locally ==="
echo

# Set CI environment variable
export ANTHROPIC_API_KEY="dummy-key-for-ci"

echo "1. Testing mise installation and tool setup..."
if ! command -v mise &> /dev/null; then
    echo "   mise not found. Would install with: curl https://mise.run | sh"
else
    echo "   ✓ mise is already installed"
fi

echo
echo "2. Checking tool versions with mise..."
if command -v mise &> /dev/null; then
    mise install || echo "   (Would install tools)"
    eval "$(mise activate bash)" || true
    echo "   Rust version: $(rustc --version 2>/dev/null || echo 'not installed via mise')"
    echo "   Tuist version: $(tuist version 2>/dev/null || echo 'not installed via mise')"
fi

echo
echo "3. Testing Rust build and tests..."
cd momentum
echo "   Running cargo test..."
cargo test
echo "   ✓ Rust tests passed"

echo "   Checking formatting..."
cargo fmt -- --check
echo "   ✓ Rust formatting OK"

echo "   Running clippy..."
cargo clippy -- -D warnings
echo "   ✓ Clippy passed"

echo "   Building release binary..."
cargo build --release
echo "   ✓ Release build successful"

echo "   Verifying binary..."
test -f target/release/momentum && echo "   ✓ Binary exists" || echo "   ✗ Binary not found"
cd ..

echo
echo "4. Testing Swift build..."
echo "   Generating Xcode project..."
tuist generate
echo "   ✓ Project generated"

echo "   Copying Rust binary to Resources..."
mkdir -p MomentumApp/Resources
cp momentum/target/release/momentum MomentumApp/Resources/
echo "   ✓ Binary copied"

echo "   Building Swift app..."
xcodebuild -workspace Momentum.xcworkspace \
  -scheme MomentumApp \
  -configuration Debug \
  build \
  -skipMacroValidation \
  -quiet
echo "   ✓ Swift app built"

echo
echo "5. Running Swift tests..."
xcodebuild -workspace Momentum.xcworkspace \
  -scheme MomentumApp \
  -configuration Debug \
  test \
  -skipMacroValidation \
  -quiet
echo "   ✓ Swift tests passed"

echo
echo "=== All CI checks passed locally! ==="
echo
echo "Note: This simulates the CI workflow but doesn't replicate the exact"
echo "GitHub Actions environment. The actual CI will run on a clean macOS runner."