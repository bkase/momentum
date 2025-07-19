.PHONY: all test build clean rust-test rust-build rust-lint rust-format swift-test swift-build swift-format swift-lint format lint install-tools tail-logs

# Default target
all: build test

# Install required tools
install-tools:
	@echo "Installing required tools via mise..."
	@mise install
	@eval "$$(mise activate bash)" && rustup component add rustfmt clippy
	@echo "Building swift-format..."
	@cd BuildTools && swift build

# Rust targets
rust-test:
	@echo "Running Rust tests..."
	@eval "$$(mise activate bash)" && cd momentum && cargo test

rust-format:
	@echo "Formatting Rust code..."
	@eval "$$(mise activate bash)" && cd momentum && cargo fmt

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

# Binary management
copy-rust-binary:
	@echo "Copying Rust binary to Resources..."
	@mkdir -p MomentumApp/Resources
	@cp momentum/target/release/momentum MomentumApp/Resources/
	@chmod +x MomentumApp/Resources/momentum

# Swift targets
swift-format:
	@echo "Formatting Swift code..."
	@./scripts/run-swift-format.sh format --recursive --in-place --configuration $(PWD)/.swift-format $(PWD)

swift-generate:
	@echo "Generating Xcode project..."
	@eval "$$(mise activate bash)" && tuist generate

swift-build-only:
	@echo "Building Swift app..."
	@xcodebuild -workspace Momentum.xcworkspace \
		-scheme MomentumApp \
		-configuration Debug \
		build \
		-skipMacroValidation \
		-quiet

swift-lint:
	@echo "Checking Swift formatting..."
	@./scripts/run-swift-format.sh lint --recursive --configuration $(PWD)/.swift-format $(PWD)

swift-test-only:
	@echo "Running Swift tests..."
	@xcodebuild -workspace Momentum.xcworkspace \
		-scheme MomentumApp \
		-configuration Debug \
		test \
		-skipMacroValidation \
		-quiet

# Convenience targets that build everything
swift-build: rust-build copy-rust-binary swift-build-only

swift-test: rust-build copy-rust-binary swift-test-only

# Combined targets
format: rust-format swift-format

lint: rust-lint swift-lint

build: rust-build swift-generate swift-build

test: rust-test lint swift-test

# Clean build artifacts
clean:
	@echo "Cleaning build artifacts..."
	@cd momentum && cargo clean
	@rm -rf MomentumApp/Resources/momentum
	@if [ -d "Momentum.xcworkspace" ]; then \
		xcodebuild -workspace Momentum.xcworkspace -scheme MomentumApp clean -quiet; \
	fi

# Tail logs from the Momentum app
tail-logs:
	@echo "Tailing Momentum app logs..."
	@log stream --predicate 'subsystem == "com.bkase.MomentumApp"' --level debug