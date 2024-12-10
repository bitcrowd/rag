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

    test "emits start, stop, and exception telemetry events" do
      expect(Nx.Serving, :batched_run, fn serving, prompt ->
        assert serving == TestServing
        assert prompt == "a prompt"
        %{results: [%{text: "a response"}]}
      end)

      prompt = "a prompt"

      rag_state = %{prompt: prompt}

      ref =
        :telemetry_test.attach_event_handlers(self(), [
          [:rag, :generate_response, :start],
          [:rag, :generate_response, :stop],
          [:rag, :generate_response, :exception]
        ])

      Generation.Nx.generate_response(rag_state, TestServing)

      assert_received {[:rag, :generate_response, :start], ^ref, _measurement, _meta}
      assert_received {[:rag, :generate_response, :stop], ^ref, _measurement, _meta}

      expect(Nx.Serving, :batched_run, fn _serving, _prompt -> raise "boom" end)

      assert_raise RuntimeError, fn -> Generation.Nx.generate_response(rag_state, TestServing) end

      assert_received {[:rag, :generate_response, :exception], ^ref, _measurement, _meta}
    end
  end
end
