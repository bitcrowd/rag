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

    test "emits start, stop, and exception telemetry events" do
      expect(Nx.Serving, :batched_run, fn serving, prompt ->
        assert serving == TestServing
        assert prompt == "a prompt"
        %{results: [%{text: "a response"}]}
      end)

      query = "a query"
      prompt = "a prompt"

      generation = %Generation{query: query, prompt: prompt}

      ref =
        :telemetry_test.attach_event_handlers(self(), [
          [:rag, :generate_response, :start],
          [:rag, :generate_response, :stop],
          [:rag, :generate_response, :exception]
        ])

      Generation.Nx.generate_response(generation, TestServing)

      assert_received {[:rag, :generate_response, :start], ^ref, _measurement, _meta}
      assert_received {[:rag, :generate_response, :stop], ^ref, _measurement, _meta}

      expect(Nx.Serving, :batched_run, fn _serving, _prompt -> raise "boom" end)

      assert_raise RuntimeError, fn ->
        Generation.Nx.generate_response(generation, TestServing)
      end

      assert_received {[:rag, :generate_response, :exception], ^ref, _measurement, _meta}
    end
  end
end
