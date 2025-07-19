# Auto-formatting Analysis

## Research Findings

Based on my investigation of the Momentum codebase, here are my findings:

### 1. **Current Makefile Structure**
The Makefile already has a well-organized structure with:
- Separate targets for Rust and Swift operations
- A `rust-lint` target that already uses `cargo fmt -- --check` and `cargo clippy`
- No existing Swift formatting targets

### 2. **Existing Formatting Tools**
- **Rust**: `cargo fmt` is already being used in the `rust-lint` target (line 19 of Makefile)
- **Swift**: No Swift formatter is currently configured or installed
- No configuration files exist for either formatter (no `.swift-format`, `.swiftformat`, or `rustfmt.toml`)

### 3. **CI Configuration** 
The CI workflow (.github/workflows/ci.yml):
- Runs `make rust-lint` which includes both `cargo fmt -- --check` and `cargo clippy`
- Does not run any Swift formatting checks
- Uses mise to manage tools (Rust and Tuist)

### 4. **Swift Formatter Options**
For Swift, there are two main options:
- **swift-format**: Apple's official Swift formatter
- **swiftformat**: A popular third-party formatter by Nick Lockwood

Neither is currently installed or configured in the project.

### 5. **Rust Formatting**
- `cargo fmt` is already available through the Rust toolchain
- The Makefile already includes `rustup component add rustfmt clippy` in the install-tools target
- The rust-lint target checks formatting with `cargo fmt -- --check`

### 6. **Recommendations**
To add auto-formatting targets:
- For Rust: Create a `rust-format` target that runs `cargo fmt` (without --check)
- For Swift: Choose between swift-format or swiftformat, add it to mise configuration, and create corresponding format targets
- Add a combined `format` target that runs both formatters

The most common choice for Swift formatting in modern projects is `swiftformat` due to its flexibility and wide adoption, though `swift-format` is the official Apple tool.

## Swift Formatter Choice Analysis

Based on my research of the Momentum project, I'll provide you with a comprehensive analysis and recommendation for which Swift formatter to use:

### Research Findings

1. **No existing formatter configuration**: The project currently has no `.swiftformat` or `.swift-format` configuration files.

2. **No formatter mentioned in documentation**: Neither CLAUDE.md, README.md, nor any documentation files mention a Swift formatter.

3. **CI/Makefile analysis**: The CI workflow and Makefile only include Rust formatting checks (`cargo fmt`), but no Swift formatting tools.

4. **Project.swift configuration**: The Tuist configuration specifies:
   - Indent width: 4 spaces
   - Tab width: 4 spaces
   - No formatter-specific settings

5. **Code style analysis**: From examining the Swift source files, I observed:
   - 4-space indentation (consistent with Project.swift)
   - Spaces around operators and after commas
   - Opening braces on the same line as declarations
   - Organized imports at the top
   - Clear separation between sections with blank lines
   - Use of `private` for helper computed properties
   - ViewBuilder annotations where appropriate

### Recommendation: SwiftFormat

I recommend using **SwiftFormat** for the following reasons:

1. **Better ecosystem integration**: SwiftFormat is more widely adopted in the Swift community and has better integration with various tools and editors.

2. **More flexible configuration**: SwiftFormat offers more granular control over formatting rules, which would be beneficial given the project's specific style (4-space indentation, specific organization patterns).

3. **Alignment with existing style**: The current code style in the project aligns well with SwiftFormat's default rules with minor adjustments.

4. **CI-friendly**: SwiftFormat has better command-line integration for CI pipelines, which would fit well with the existing Makefile structure.

5. **Active development**: SwiftFormat is more actively maintained with frequent updates.

### Suggested SwiftFormat Configuration

Based on the observed code style, here's a recommended `.swiftformat` configuration that would match the project's existing style:

```
# .swiftformat
--indent 4
--tabwidth 4
--maxwidth 120
--wraparguments before-first
--wrapparameters before-first
--wrapcollections before-first
--trimwhitespace always
--emptybraces no-space
--nospaceoperators ...,..<
--ranges no-space
--importgrouping testable-bottom
--stripunusedargs closure-only
--self init-only
--header strip
--disable redundantRawValues,redundantSelf
```

This configuration would maintain the existing code style while providing consistent formatting across the codebase.