#!/bin/bash

# Optionally set debugging output
#set -x

# Choose the model (you can change this to another OpenRouter-supported model)
MODEL="microsoft/mai-ds-r1:free"

# SpecFixer - rpmlint-enhanced Fedora RPM spec fixer

# Check dependencies
for cmd in rpmlint jq curl awk; do
    if ! command -v "$cmd" &>/dev/null; then
        echo "Error: Required command '$cmd' not found."
        exit 1
    fi
done

if [[ $# -ne 1 ]]; then
    echo "Usage: $0 path/to/file.spec"
    exit 1
fi

if [[ -z "${OPENROUTER_API_KEY:-}" ]]; then
    echo "Error: OPENROUTER_API_KEY environment variable is not set."
    exit 1
fi

SPEC="$1"
if [[ ! -f "$SPEC" ]]; then
    echo "Error: Spec file '$SPEC' not found."
    exit 1
fi

# Load the spec file
SPEC_CONTENT=$(<"$SPEC")

# Generate rpmlint output
RPMLINT_LOG=$(rpmlint "$SPEC" | grep -e W: -e E:)

# Conditionally build the prompt section for rpmlint output
RPMLINT_PROMPT_SECTION=""
if [[ -n "$RPMLINT_LOG" ]]; then
    # The log is not empty, so create the section to be added to the prompt
    read -r -d '' RPMLINT_PROMPT_SECTION <<EOF

rpmlint output:
----
$RPMLINT_LOG
----
EOF
fi

# Build initial prompt
read -r -d '' USER_QUERY <<EOF
You are an expert Fedora RPM packager. Your task is to correct the provided RPM spec file.

Follow these rules strictly:
- Analyze the spec file and fix any violations of Fedora Packaging Guidelines, still keeping compatibility with RHEL.
- Make the spec file more readable and simplify complicated constructs to multiple lines.
- Modernize macros where appropriate (e.g., use %{buildroot} instead of \$RPM_BUILD_ROOT).
- Make indentation consistent across the spec file - use only spaces, no tabs.
- Return ONLY the complete, corrected spec file - before it starts - output "[SPEC SPEC SPEC]" token.
- Always escape macros in comments, e.g. #%a needs to be #%%a in comment.
- Do not make any changes which can trigger rpmlint warnings or build failure.

$RPMLINT_PROMPT_SECTION

Original .spec file:
----
$SPEC_CONTENT
----
EOF

# Prepare the JSON payload
JSON_PAYLOAD=$(jq -n \
  --arg model "$MODEL" \
  --arg prompt "$USER_QUERY" \
  '{
    model: $model,
    messages: [{role: "user", content: $prompt}],
    temperature: 0.0,
    top_p : 1.0,
    top_k : 0,
    seed : 1234,
    frequency_penalty : 0,
    presence_penalty : 0
  }'
)

SECONDS=0
# Make the API request
RESPONSE=$(curl -sS --fail https://openrouter.ai/api/v1/chat/completions \
  -H "Authorization: Bearer $OPENROUTER_API_KEY" \
  -H "Content-Type: application/json" \
  -d "$JSON_PAYLOAD") || {
    echo "Error: API request failed."
    exit 1
}

DURATION=$SECONDS
echo "OpenRouter query with $MODEL took $DURATION seconds."

# Validate JSON response
if ! echo "$RESPONSE" | jq . >/dev/null 2>&1; then
    echo "Error: Response is not valid JSON."
    exit 1
fi

# Extract assistant's reply
FIXED_SPEC=$(echo "$RESPONSE" | jq -r '.choices[0].message.content' || true)

if [[ -z "$FIXED_SPEC" ]]; then
    echo "Error: Failed to extract fixed spec from response."
    exit 1
fi

# Write to fixed spec file, skipping token header line
echo "$FIXED_SPEC" | awk '/^\[SPEC SPEC SPEC\]/ {found=1; next} found' > "$SPEC-fixed.spec"

if [[ ! -s "$SPEC-fixed.spec" ]]; then
    echo "Error: Fixed spec file is empty."
    exit 1
fi

rpmlint $SPEC-fixed.spec

echo "Fixed spec saved to $SPEC-fixed.spec"
