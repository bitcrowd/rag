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

      prompt = "a prompt"

      rag_state = %{prompt: prompt}

      assert %{response: "a response"} = Generation.Nx.generate_response(rag_state, TestServing)
    end

    test "errors if prompt not present" do
      assert_raise MatchError, fn ->
        Generation.Nx.generate_response(%{})
      end
    end
  end
end
