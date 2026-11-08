"""Test Anthropic API connection and available models."""

import os
import anthropic

# Check if API key is set
api_key = os.environ.get('ANTHROPIC_API_KEY')
if not api_key:
    print("ERROR: ANTHROPIC_API_KEY not set")
    exit(1)

print(f"API Key found: {api_key[:20]}...")
print(f"API Key length: {len(api_key)}")

# Try to initialize client
try:
    client = anthropic.Anthropic(api_key=api_key)
    print("✓ Client initialized successfully")
except Exception as e:
    print(f"✗ Error initializing client: {e}")
    exit(1)

# Try a very simple API call with different models
test_models = [
    "claude-3-5-sonnet-20241022",
    "claude-3-5-sonnet-20240620",
    "claude-3-opus-20240229",
    "claude-3-sonnet-20240229",
    "claude-3-haiku-20240307"
]

print("\nTesting models...")
for model in test_models:
    print(f"\nTrying {model}...")
    try:
        response = client.messages.create(
            model=model,
            max_tokens=10,
            messages=[{"role": "user", "content": "Hi"}]
        )
        print(f"  ✓ SUCCESS! Model works: {model}")
        print(f"  Response: {response.content[0].text}")
        break  # Stop after first success
    except anthropic.NotFoundError as e:
        print(f"  ✗ 404 Not Found: {e}")
    except anthropic.AuthenticationError as e:
        print(f"  ✗ Authentication Error: {e}")
        print("  Your API key might be invalid")
        break
    except Exception as e:
        print(f"  ✗ Other error: {type(e).__name__}: {e}")
