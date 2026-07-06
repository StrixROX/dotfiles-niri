This is a Rust rewrite of the `smart-auto-hide-bar.sh` script.

The original bash script has an idle RAM footprint of ~7.7MB while the Rust rewrite offers a ~2.2MB footprint. An almost 30% improvement!

But since I don't know Rust at all, it becomes a ticking time bomb for when Niri decides to change its IPC schemas. So I will just use the bash version and keep the rust version for future reference.

# Building

```bash
cargo build --release
```

# Usage

```bash
# Syntax: ./target/release/smart-auto-hide-bar <bar_name>

# Example:
./target/release/smart-auto-hide-bar default
```

