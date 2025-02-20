defmodule Rag.GenerationTest do
  use ExUnit.Case

  alias Rag.Generation

  describe "generate_response/3" do
    test "calls response_fn with a prompt to generate a response" do
      generation = %Generation{query: "query", prompt: "a prompt"}
      response_fn = fn "a prompt", _params -> {:ok, "a response"} end

      assert %{response: "a response"} =
               Generation.generate_response(generation, %{}, response_fn)
    end

    test "returns unchanged generation when halted? is true" do
      generation = %Generation{query: "query", prompt: "a prompt", halted?: true}
      response_fn = fn "a prompt", _params -> {:ok, "a response"} end

      assert generation == Generation.generate_response(generation, %{}, response_fn)
    end

    test "emits start, stop, and exception telemetry events" do
      generation = %Generation{query: "query", prompt: "a prompt"}
      response_fn = fn "a prompt", _params -> {:ok, "a response"} end

      ref =
        :telemetry_test.attach_event_handlers(self(), [
          [:rag, :generate_response, :start],
          [:rag, :generate_response, :stop],
          [:rag, :generate_response, :exception]
        ])

      Generation.generate_response(generation, %{}, response_fn)

      assert_received {[:rag, :generate_response, :start], ^ref, _measurement, _meta}
      assert_received {[:rag, :generate_response, :stop], ^ref, _measurement, _meta}

      crashing_response_fn = fn _prompt, _params -> raise "boom" end

      assert_raise RuntimeError, fn ->
        Generation.generate_response(generation, %{}, crashing_response_fn)
      end

      assert_received {[:rag, :generate_response, :exception], ^ref, _measurement, _meta}
    end
  end
end
