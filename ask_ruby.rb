require 'openai'
require 'httplog'
require_relative 'open_ai_service'

# Initialize the OpenAI service
open_ai_service = OpenAiService.new

# Get the question from the user
puts "What is your question?"
question = gets.chomp

# Define the prompt
prompt = "Answer following question about Ruby language: #{question}\n"

# Run the prompt
response = open_ai_service.run(prompt)

# Print the answer
puts response