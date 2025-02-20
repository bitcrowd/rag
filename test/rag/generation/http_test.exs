defmodule Rag.Generation.HttpTest do
  use ExUnit.Case
  use Mimic

  alias Rag.Generation
  alias Rag.Ai.Http.GenerationParams

  describe "generate_response/2" do
    test "calls an HTTP API with a prompt to generate a response" do
      expect(Req, :post, fn _url, _params ->
        {:ok,
         %Req.Response{
           status: 200,
           body: %{"choices" => [%{"index" => 0, "message" => %{"content" => "a response"}}]}
         }}
      end)

      params = GenerationParams.openai_params("openai_model", "somekey")
      generation = %Generation{query: "query", prompt: "a prompt"}

      assert %{response: "a response"} = Generation.Http.generate_response(generation, params)
    end

    @tag :integration_test
    test "openai generation" do
      api_key = System.get_env("OPENAI_API_KEY")
      params = GenerationParams.openai_params("gpt-4o-mini", api_key)

      %Generation{query: "test?", response: _response} =
        Generation.Http.generate_response(%Generation{query: "test?", prompt: "prompt"}, params)
    end

    @tag :integration_test
    test "cohere generation" do
      api_key = System.get_env("COHERE_API_KEY")
      params = GenerationParams.cohere_params("command-r-plus-08-2024", api_key)

      %Generation{query: "test?", response: _response} =
        Generation.Http.generate_response(%Generation{query: "test?", prompt: "prompt"}, params)
    end
  end
end
