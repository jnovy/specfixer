# SpecFixer - AI-Enhanced Fedora RPM Spec File Fixer

SpecFixer is a Bash script that uses rpmlint diagnostics and an OpenRouter-hosted AI model to automatically fix and modernize Fedora RPM .spec files. It helps maintain packaging guideline compliance while improving readability and consistency.

## Features

- Automatically applies fixes based on rpmlint output.
- Uses a hosted LLM (microsoft/mai-ds-r1:free via OpenRouter) to modernize and clean up .spec files.
- Ensures compatibility with Fedora and RHEL.
- Enforces consistent formatting and macro usage.
- Produces a clean, corrected .spec file with issues resolved.

## Requirements

Ensure the following dependencies are installed and available in your system's PATH:

- bash
- rpmlint
- jq
- curl
- awk

You must also set your OpenRouter API key in the environment:

```bash
export OPENROUTER_API_KEY="your_api_key_here"
```

## Installation

Clone or download this script and make it executable:

```bash
chmod +x specfixer.sh
```

## Usage

```bash
./specfixer.sh path/to/your.spec
```

The script performs the following:

1. Runs rpmlint on the original spec file.
2. Constructs an expert-level prompt including the original spec and lint warnings.
3. Queries the OpenRouter AI for corrections.
4. Writes the fixed spec file to your.spec-fixed.spec.
5. Displays the rpmlint results for the fixed file.

## Example

```bash
./specfixer.sh mc.spec
```

Output:

```
OpenRouter query with microsoft/mai-ds-r1:free took 4 seconds. <rpmlint output>
Fixed spec saved to mc.spec-fixed.spec
```

## Notes

- The script requires a valid OpenRouter API key with access to the specified model.
- Only .spec files are supported.
- If no warnings or errors are detected by rpmlint, the script still proceeds, but AI corrections may be minimal.

## License

GPLv3 License. Feel free to modify and use this script in your packaging workflow.

## Acknowledgements

- OpenRouter.ai – for LLM access
- Fedora Packaging Guidelines
- rpmlint – for spec quality diagnostics
