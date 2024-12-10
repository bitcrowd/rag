defmodule Rag.Embedding.OpenAITest do
  use ExUnit.Case
  use Mimic

  alias Rag.Embedding

  describe "generate_embedding/4" do
    test "takes a string at source_key and returns rag_state map with a list of numbers at target_key" do
      expect(Req, :post!, fn _url, _params ->
        %{body: %{"data" => [%{"embedding" => [1, 2, 3]}]}}
      end)

      rag_state = %{text: "hello"}

      openai_params = %{
        model: "text-embedding-3-small",
        api_key: "somekey"
      }

      assert Embedding.OpenAI.generate_embedding(rag_state, openai_params, :text, :output) == %{
               text: "hello",
               output: [1, 2, 3]
             }
    end

    test "errors if source_key is not in rag_state" do
      rag_state = %{text: "hello"}

      assert_raise KeyError, fn ->
        Embedding.OpenAI.generate_embedding(rag_state, %{}, :non_existing_key, :output)
      end
    end

    test "errors if model or api_key are not passed" do
      rag_state = %{text: "hello"}

      assert_raise KeyError, fn ->
        Embedding.OpenAI.generate_embedding(
          rag_state,
          %{api_key: "hello"},
          :non_existing_key,
          :output
        )
      end

      assert_raise KeyError, fn ->
        Embedding.OpenAI.generate_embedding(
          rag_state,
          %{model: "embeddingsmodel"},
          :non_existing_key,
          :output
        )
      end
    end

    test "emits start, stop, and exception telemetry events" do
      expect(Req, :post!, fn _url, _params ->
        %{body: %{"data" => [%{"embedding" => [1, 2, 3]}]}}
      end)

      rag_state = %{text: "hello"}

      openai_params = %{
        model: "text-embedding-3-small",
        api_key: "somekey"
      }

      ref =
        :telemetry_test.attach_event_handlers(self(), [
          [:rag, :generate_embedding, :start],
          [:rag, :generate_embedding, :stop],
          [:rag, :generate_embedding, :exception]
        ])

      Embedding.OpenAI.generate_embedding(rag_state, openai_params, :text, :output)

      assert_received {[:rag, :generate_embedding, :start], ^ref, _measurement, _meta}
      assert_received {[:rag, :generate_embedding, :stop], ^ref, _measurement, _meta}

      expect(Req, :post!, fn _url, _params -> raise "boom" end)

      assert_raise RuntimeError, fn ->
        Embedding.OpenAI.generate_embedding(rag_state, openai_params, :text, :output)
      end

      assert_received {[:rag, :generate_embedding, :exception], ^ref, _measurement, _meta}
    end
  end

  describe "generate_embeddings_batch/4" do
    test "takes a string at source_key and returns rag_state map with a list of numbers at target_key" do
      expect(Req, :post!, fn _url, _params ->
        %{body: %{"data" => [%{"embedding" => [1, 2, 3]}, %{"embedding" => [4, 5, 6]}]}}
      end)

      openai_params = %{
        model: "text-embedding-3-small",
        api_key: "apikey"
      }

      rag_state_list = [%{text: "hello"}, %{text: "hello again"}]

      assert [%{text: "hello", output: [1, 2, 3]}, %{text: "hello again", output: [4, 5, 6]}] ==
               Embedding.OpenAI.generate_embeddings_batch(
                 rag_state_list,
                 openai_params,
                 :text,
                 :output
               )
    end

    test "errors if source_key is not in rag_state" do
      rag_state_list = [%{text: "hello"}]

      assert_raise KeyError, fn ->
        Embedding.OpenAI.generate_embeddings_batch(
          rag_state_list,
          %{},
          :non_existing_key,
          :output
        )
      end
    end

    test "errors if model or api_key are not passed" do
      rag_state = %{text: "hello"}

      assert_raise KeyError, fn ->
        Embedding.OpenAI.generate_embedding(
          rag_state,
          %{api_key: "hello"},
          :non_existing_key,
          :output
        )
      end

      assert_raise KeyError, fn ->
        Embedding.OpenAI.generate_embedding(
          rag_state,
          %{model: "embeddingsmodel"},
          :non_existing_key,
          :output
        )
      end
    end

    test "emits start, stop, and exception telemetry events" do
      expect(Req, :post!, fn _url, _params ->
        %{body: %{"data" => [%{"embedding" => [1, 2, 3]}, %{"embedding" => [4, 5, 6]}]}}
      end)

      openai_params = %{
        model: "text-embedding-3-small",
        api_key: "apikey"
      }

      rag_state_list = [%{text: "hello"}, %{text: "hello again"}]

      ref =
        :telemetry_test.attach_event_handlers(self(), [
          [:rag, :generate_embeddings_batch, :start],
          [:rag, :generate_embeddings_batch, :stop],
          [:rag, :generate_embeddings_batch, :exception]
        ])

      Embedding.OpenAI.generate_embeddings_batch(
        rag_state_list,
        openai_params,
        :text,
        :output
      )

      assert_received {[:rag, :generate_embeddings_batch, :start], ^ref, _measurement, _meta}
      assert_received {[:rag, :generate_embeddings_batch, :stop], ^ref, _measurement, _meta}

      expect(Req, :post!, fn _url, _params -> raise "boom" end)

      assert_raise RuntimeError, fn ->
        Embedding.OpenAI.generate_embeddings_batch(
          rag_state_list,
          openai_params,
          :text,
          :output
        )
      end

      assert_received {[:rag, :generate_embeddings_batch, :exception], ^ref, _measurement, _meta}
    end
  end
end
