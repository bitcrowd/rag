defmodule Rag.Generation.NxTest do
  use ExUnit.Case
  use Mimic

  alias Rag.Generation
  alias Rag.Ai

  setup do
    %{provider: Ai.Nx.new(%{})}
  end

  describe "generate_response/2" do
    test "calls `serving` with prompt to generate a response", %{provider: provider} do
      expect(Nx.Serving, :batched_run, fn _serving, prompt ->
        assert prompt == "a prompt"
        %{results: [%{text: "a response"}]}
      end)

      query = "a query"
      prompt = "a prompt"

      generation = %Generation{query: query, prompt: prompt}

      assert %{response: "a response"} = Generation.generate_response(generation, provider)
    end

    test "returns unchanged generation when halted? is true", %{provider: provider} do
      generation = %Generation{query: "a query", prompt: "a prompt", halted?: true}

      assert generation == Generation.generate_response(generation, provider)
    end

    test "errors if prompt not present", %{provider: provider} do
      assert_raise ArgumentError, fn ->
        Generation.generate_response(%Generation{query: "a query"}, provider)
      end
    end
  end
end
