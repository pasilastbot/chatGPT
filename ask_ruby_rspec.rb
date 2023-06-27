require_relative 'open_ai_service'

RSpec.describe OpenAiService do
  let(:open_ai_service) { OpenAiService.new }

  describe "#run" do
    it "returns a response from the OpenAI API" do
      prompt = "Answer this question about Ruby: list ruby unit testing frameworks?\n"
      response = open_ai_service.run(prompt)
      expect(response).to be_a(String)
    end
  end
end

# What are the test frameworks you could use with ruby?