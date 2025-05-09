defmodule Rag.Generation.HttpTest do
  use ExUnit.Case
  use Mimic

  alias Rag.Generation
  alias Rag.Ai

  setup do
    %{provider: Ai.OpenAI.new(%{})}
  end

  describe "generate_response/2" do
    test "calls an HTTP API with a prompt to generate a response", %{provider: provider} do
      expect(Req, :post, fn _url, _params ->
        {:ok,
         %Req.Response{
           status: 200,
           body: %{"choices" => [%{"index" => 0, "message" => %{"content" => "a response"}}]}
         }}
      end)

      generation = %Generation{query: "query", prompt: "a prompt"}

      assert %{response: "a response"} = Generation.generate_response(generation, provider)
    end

    @tag :integration_test
    test "openai generation" do
      api_key = System.get_env("OPENAI_API_KEY")
      provider = Ai.OpenAI.new(%{text_model: "gpt-4o-mini", api_key: api_key})

      %Generation{query: "test?", response: _response} =
        Generation.generate_response(%Generation{query: "test?", prompt: "prompt"}, provider)
    end

    @tag :integration_test
    test "openai generation with streaming" do
      api_key = System.get_env("OPENAI_API_KEY")
      provider = Ai.OpenAI.new(%{text_model: "gpt-4o-mini", api_key: api_key})

      %Generation{query: "test?", response: response} =
        Generation.generate_response(%Generation{query: "test?", prompt: "prompt"}, provider,
          stream: true
        )

      assert Enum.join(response) |> String.length() > 0
    end

    @tag :integration_test
    test "cohere generation" do
      api_key = System.get_env("COHERE_API_KEY")
      provider = Ai.Cohere.new(%{text_model: "command-r-plus-08-2024", api_key: api_key})

      %Generation{query: "test?", response: _response} =
        Generation.generate_response(%Generation{query: "test?", prompt: "prompt"}, provider)
    end

    @tag :integration_test
    test "cohere generation with streaming" do
      api_key = System.get_env("COHERE_API_KEY")
      provider = Ai.Cohere.new(%{text_model: "command-r-plus-08-2024", api_key: api_key})

      %Generation{query: "test?", response: response} =
        Generation.generate_response(%Generation{query: "test?", prompt: "prompt"}, provider,
          stream: true
        )

      assert Enum.join(response) |> String.length() > 0
    end
  end
end
