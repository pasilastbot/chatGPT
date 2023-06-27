# frozen_string_literal: true
require 'openai'
require 'httplog'
require 'tiktoken_ruby'

class OpenAiService
    attr_reader :client, :open_ai_params, :model_kwargs, :version

    # The default parameters to use when asking the engine.
    DEFAULT_PARAMS = {
      model: "gpt-3.5-turbo",
      temperature: 0.4,
      max_tokens: 500
    }.freeze

    # Initialize the OpenAiService class with an OpenAI access token and default parameters.
    # @param version [String] The version of the engine to use.
    def initialize(version: '-0613', **kwargs)
        OpenAI.configure do |config|
            config.access_token = ENV.fetch("OPENAI_ACCESS_TOKEN")
        end
        
        @client = OpenAI::Client.new
        @open_ai_params = DEFAULT_PARAMS.merge(kwargs)
        @version = version
    end

    # Get an answer from the engine for a question.
    # @param prompt_text [String] The question to ask the engine.
    # @return [String] The answer from the engine.
    def run(prompt_text)
    
       messages = []
       
       messages << { role: "user", content: prompt_text }  
      
      response = client.chat(parameters:open_ai_params.merge({messages: messages, model: choose_smallest_model(prompt_text)}))
      raise Error, "OpenAI: No response from API" unless response
      raise Error, "OpenAI: #{response['error']}" if response["error"]

      answer = response["choices"].map { |c| c.dig("message", "content") || c["text"] }.join("\n").strip
      #puts "price: #{model_price(response['usage'])}"      

      answer
    end

    # Get the default parameters for the engine.
    def default_params
      open_ai_params
    end

    # Make sure we got a valid response.
    # @param response [Hash] The response to check.
    # @param must_haves [Array<String>] The keys that must be in the response.
    # @raise [KeyError] if there is an issue with the access token.
    # @raise [ValueError] if the response is not valid.
    def check_response(response, must_haves: %w[choices])
      if response['error']
        code = response.dig('error', 'code')
        msg = response.dig('error', 'message') || 'unknown error'
        raise KeyError, "OPENAI_ACCESS_TOKEN not valid" if code == 'invalid_api_key'

        raise ValueError, "OpenAI error: #{msg}"
      end

      must_haves.each do |key|
        raise ValueError, "Expecting key #{key} in response" unless response.key?(key)
      end
    end

    # Choose the smallest model that can handle the given prompt.
    # @param prompt_text [String] The prompt to check.
    # @return [String] The name of the smallest model that can handle the prompt.
    def choose_smallest_model(prompt_text)
        # get max context size for model by name
        max_size = modelname_to_contextsize(self.model)

        num_tokens = get_num_tokens(prompt_text)

        #if there is 500 token size for response
        if num_tokens + self.open_ai_params[:max_tokens] < max_size
            return self.model
        else
            if self.model == 'gpt-3.5-turbo'
                return 'gpt-3.5-turbo-16k'+version
            else
                return 'gpt-4-32k'+version
            end
        end
    end

    # Get the name of the current model.
    # @return [String] The name of the current model.
    def model
        self.open_ai_params[:model] + self.version
    end
        
    # Get the number of tokens in a prompt.
    # @param prompt_text [String] The prompt to check.
    # @return [Integer] The number of tokens in the prompt.
    def get_num_tokens(prompt_text)
        puts open_ai_params[:model]
        enc = Tiktoken.encoding_for_model(open_ai_params[:model])
        enc.encode(prompt_text).length
    end

    # Lookup the context size for a model by name.
    # @param modelname [String] The name of the model to lookup.
    # @return [Integer] The context size of the model.
    def modelname_to_contextsize(modelname)
        model_lookup = {
        'gpt-3.5-turbo': 4096,
        'gpt-3.5-turbo-16k': 16384,
        'gpt-4': 8192,
        'gpt-4-32k': 32768
        }.freeze
        
        model_lookup[modelname] || 4097
    end

    # Calculate the price of generating a response.
    # @param response [Hash] The response to calculate the price for.
    # @return [Float] The price of generating the response.
    def model_price(response)

        model_lookup = {
        'gpt-3.5-turbo': {input: 0.0015, output: 0.002},
        'gpt-3.5-turbo-16k': {input: 0.003, output: 0.004},
        'gpt-4': {input: 0.03, output: 0.06},
        'gpt-4-32k': {input: 0.06, output: 0.12},
        }.freeze

        puts self.open_ai_params[:model]
        puts model_lookup.inspect
        ((model_lookup[self.open_ai_params[:model].to_sym][:input] * response['prompt_tokens']) + 
        (model_lookup[self.open_ai_params[:model].to_sym][:output] * response['completion_tokens'])) / 1000

    end

    # Calculate the maximum number of tokens possible to generate for a prompt.
    # @param prompt_text [String] The prompt text to use.
    # @return [Integer] the number of tokens possible to generate.
    def max_tokens_for_prompt(prompt_text)
        num_tokens = get_num_tokens(prompt_text)

        # get max context size for model by name
        max_size = modelname_to_contextsize(model_name)
        max_size - num_tokens
    end
end