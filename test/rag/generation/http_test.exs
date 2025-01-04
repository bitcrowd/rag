defmodule Rag.Generation.HttpTest do
  use ExUnit.Case
  use Mimic

  alias Rag.Generation
  alias Rag.Generation.Http.Params

  describe "generate_response/2" do
    test "calls an HTTP API with a prompt to generate a response" do
      expect(Req, :post!, fn _url, _params ->
        %{body: %{"choices" => [%{"index" => 0, "message" => %{"content" => "a response"}}]}}
      end)

      params = Params.openai_params("openai_model", "somekey")
      generation = %Generation{query: "query", prompt: "a prompt"}

      assert %{response: "a response"} = Generation.Http.generate_response(generation, params)
    end

    test "emits start, stop, and exception telemetry events" do
      expect(Req, :post!, fn _url, _params ->
        %{body: %{"choices" => [%{"index" => 0, "message" => %{"content" => "a response"}}]}}
      end)

      params = Params.openai_params("openai_model", "somekey")
      generation = %Generation{query: "query", prompt: "a prompt"}

      ref =
        :telemetry_test.attach_event_handlers(self(), [
          [:rag, :generate_response, :start],
          [:rag, :generate_response, :stop],
          [:rag, :generate_response, :exception]
        ])

      Generation.Http.generate_response(generation, params)

      assert_received {[:rag, :generate_response, :start], ^ref, _measurement, _meta}
      assert_received {[:rag, :generate_response, :stop], ^ref, _measurement, _meta}

      expect(Req, :post!, fn _url, _params -> raise "boom" end)

      assert_raise RuntimeError, fn ->
        Generation.Http.generate_response(generation, params)
      end

      assert_received {[:rag, :generate_response, :exception], ^ref, _measurement, _meta}
    end
  end
end
