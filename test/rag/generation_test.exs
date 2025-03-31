defmodule Rag.GenerationTest do
  use ExUnit.Case

  alias Rag.Generation

  describe "new/1" do
    test "builds a new generation" do
      assert %Generation{query: "query", ref: nil} = Generation.new("query")
    end
  end

  describe "new/2" do
    test "allows to pass a reference value" do
      assert %Generation{query: "query", ref: "foo"} = Generation.new("query", ref: "foo")
    end
  end

  describe "generate_response/2" do
    test "calls response_fn with a prompt to generate a response" do
      generation = %Generation{query: "query", prompt: "a prompt"}
      response_fn = fn "a prompt", _opts -> {:ok, "a response"} end

      assert %{response: "a response"} =
               Generation.generate_response(generation, response_fn)
    end

    test "returns unchanged generation when halted? is true" do
      generation = %Generation{query: "query", prompt: "a prompt", halted?: true}
      response_fn = fn "a prompt", _opts -> {:ok, "a response"} end

      assert generation == Generation.generate_response(generation, response_fn)
    end

    test "emits start, stop, and exception telemetry events" do
      generation = %Generation{query: "query", prompt: "a prompt", ref: "test-reference"}
      response_fn = fn "a prompt", _opts -> {:ok, "a response"} end

      ref =
        :telemetry_test.attach_event_handlers(self(), [
          [:rag, :generate_response, :start],
          [:rag, :generate_response, :stop],
          [:rag, :generate_response, :exception]
        ])

      Generation.generate_response(generation, response_fn)

      assert_received {[:rag, :generate_response, :start], ^ref, _measurement,
                       %{generation: %Generation{ref: "test-reference"}}}

      assert_received {[:rag, :generate_response, :stop], ^ref, _measurement,
                       %{generation: %Generation{ref: "test-reference"}}}

      crashing_response_fn = fn _prompt, _opts -> raise "boom" end

      assert_raise RuntimeError, fn ->
        Generation.generate_response(generation, crashing_response_fn)
      end

      assert_received {[:rag, :generate_response, :exception], ^ref, _measurement,
                       %{generation: %Generation{ref: "test-reference"}}}
    end

    test "halts and sets error when response_fn returns error tuple" do
      generation = %Generation{query: "query", prompt: "a prompt"}
      error_fn = fn _prompt, _opts -> {:error, "some weird error"} end

      assert %{halted?: true, errors: ["some weird error"]} =
               Generation.generate_response(generation, error_fn)
    end
  end
end
