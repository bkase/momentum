.PHONY: all test build clean swift-test swift-build swift-format swift-lint format lint install-tools tail-logs

# Default target
all: build test

# Install required tools
install-tools:
	@echo "Installing required tools via mise..."
	@mise install
	@echo "Building swift-format..."
	@cd BuildTools && swift build

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
swift-build: swift-build-only

swift-test: swift-test-only

# Combined targets

lint: swift-lint

build: swift-generate swift-build

test: lint swift-test

# Clean build artifacts

clean:
	@echo "Cleaning build artifacts..."
	@rm -rf MomentumApp/Resources/momentum
	@if [ -d "Momentum.xcworkspace" ]; then \
		xcodebuild -workspace Momentum.xcworkspace -scheme MomentumApp clean -quiet; \
	fi

# Tail logs from the Momentum app
tail-logs:
	@echo "Tailing Momentum app logs..."
	@log stream --predicate 'subsystem == "com.bkase.MomentumApp"' --level debug
