from openai import OpenAI

client = OpenAI()

def run_prompt(prompt):
    response = client.responses.create(
        model="gpt-4.1",
        input=prompt
    )
    return response.output_text

signal = run_prompt("List trending crypto opportunities")
filtered = run_prompt(f"Rank these: {signal}")

print(filtered)
