.PHONY: all test build clean rust-test rust-build rust-lint swift-test swift-build install-tools

# Default target
all: build test

# Install required tools
install-tools:
	@echo "Installing required tools via mise..."
	@mise install
	@eval "$$(mise activate bash)" && rustup component add rustfmt clippy

# Rust targets
rust-test:
	@echo "Running Rust tests..."
	@eval "$$(mise activate bash)" && cd momentum && cargo test

rust-lint:
	@echo "Checking Rust formatting..."
	@eval "$$(mise activate bash)" && cd momentum && cargo fmt -- --check
	@echo "Running Clippy..."
	@eval "$$(mise activate bash)" && cd momentum && cargo clippy -- -D warnings

rust-build:
	@echo "Building Rust release binary..."
	@eval "$$(mise activate bash)" && cd momentum && cargo build --release

rust-dev:
	@echo "Building Rust debug binary..."
	@eval "$$(mise activate bash)" && cd momentum && cargo build

# Swift targets
swift-generate:
	@echo "Generating Xcode project..."
	@eval "$$(mise activate bash)" && tuist generate

swift-build: rust-build
	@echo "Copying Rust binary to Resources..."
	@mkdir -p MomentumApp/Resources
	@cp momentum/target/release/momentum MomentumApp/Resources/
	@echo "Building Swift app..."
	@xcodebuild -workspace Momentum.xcworkspace \
		-scheme MomentumApp \
		-configuration Debug \
		build \
		-skipMacroValidation \
		-quiet

swift-test: rust-build
	@echo "Copying Rust binary to Resources..."
	@mkdir -p MomentumApp/Resources
	@cp momentum/target/release/momentum MomentumApp/Resources/
	@echo "Running Swift tests..."
	@xcodebuild -workspace Momentum.xcworkspace \
		-scheme MomentumApp \
		-configuration Debug \
		test \
		-skipMacroValidation \
		-quiet

# Combined targets
build: rust-build swift-generate swift-build

test: rust-test rust-lint swift-test

# Clean build artifacts
clean:
	@echo "Cleaning build artifacts..."
	@cd momentum && cargo clean
	@rm -rf MomentumApp/Resources/momentum
	@if [ -d "Momentum.xcworkspace" ]; then \
		xcodebuild -workspace Momentum.xcworkspace -scheme MomentumApp clean -quiet; \
	fi