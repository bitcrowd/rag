defmodule Rag.Generation.NxTest do
  use ExUnit.Case
  use Mimic

  alias Rag.Generation

  describe "generate_response/2" do
    test "calls `serving` with prompt to generate a response" do
      expect(Nx.Serving, :batched_run, fn serving, prompt ->
        assert serving == TestServing
        assert prompt == "a prompt"
        %{results: [%{text: "a response"}]}
      end)

      query = "a query"
      prompt = "a prompt"

      generation = %Generation{query: query, prompt: prompt}

      assert %{response: "a response"} = Generation.Nx.generate_response(generation, TestServing)
    end

    test "returns unchanged generation when halted? is true" do
      generation = %Generation{query: "a query", prompt: "a prompt", halted?: true}

      assert generation == Generation.Nx.generate_response(generation, TestServing)
    end

    test "errors if prompt not present" do
      assert_raise ArgumentError, fn ->
        Generation.Nx.generate_response(%Generation{query: "a query"}, TestServing)
      end
    end
  end
end
