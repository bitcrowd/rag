defmodule Rag.Embedding.HttpTest do
  use ExUnit.Case
  use Mimic

  alias Rag.Embedding
  alias Rag.Embedding.Http.Params

  describe "generate_embedding/3" do
    test "takes a string at text_key and returns map with a list of numbers at embedding_key" do
      expect(Req, :post!, fn _url, _params ->
        %{body: %{"data" => [%{"embedding" => [1, 2, 3]}]}}
      end)

      ingestion = %{text: "hello"}

      openai_params = Params.openai_params("text-embedding-3-small", "somekey")

      assert Embedding.Http.generate_embedding(ingestion, openai_params, []) ==
               %{
                 text: "hello",
                 embedding: [1, 2, 3]
               }
    end

    test "emits start, stop, and exception telemetry events" do
      expect(Req, :post!, fn _url, _params ->
        %{body: %{"data" => [%{"embedding" => [1, 2, 3]}]}}
      end)

      ingestion = %{text: "hello"}

      openai_params = Params.openai_params("text-embedding-3-small", "somekey")

      ref =
        :telemetry_test.attach_event_handlers(self(), [
          [:rag, :generate_embedding, :start],
          [:rag, :generate_embedding, :stop],
          [:rag, :generate_embedding, :exception]
        ])

      Embedding.Http.generate_embedding(ingestion, openai_params, [])

      assert_received {[:rag, :generate_embedding, :start], ^ref, _measurement, _meta}
      assert_received {[:rag, :generate_embedding, :stop], ^ref, _measurement, _meta}

      expect(Req, :post!, fn _url, _params -> raise "boom" end)

      assert_raise RuntimeError, fn ->
        Embedding.Http.generate_embedding(ingestion, openai_params, [])
      end

      assert_received {[:rag, :generate_embedding, :exception], ^ref, _measurement, _meta}
    end
  end

  describe "generate_embeddings_batch/3" do
    test "takes a string at text_key and returns ingestion map with a list of numbers at embedding_key" do
      expect(Req, :post!, fn _url, _params ->
        %{body: %{"data" => [%{"embedding" => [1, 2, 3]}, %{"embedding" => [4, 5, 6]}]}}
      end)

      openai_params = Params.openai_params("text-embedding-3-small", "somekey")

      ingestion_list = [%{text: "hello"}, %{text: "hello again"}]

      assert [
               %{text: "hello", embedding: [1, 2, 3]},
               %{text: "hello again", embedding: [4, 5, 6]}
             ] ==
               Embedding.Http.generate_embeddings_batch(
                 ingestion_list,
                 openai_params,
                 text_key: :text,
                 embedding_key: :embedding
               )
    end

    test "emits start, stop, and exception telemetry events" do
      expect(Req, :post!, fn _url, _params ->
        %{body: %{"data" => [%{"embedding" => [1, 2, 3]}, %{"embedding" => [4, 5, 6]}]}}
      end)

      openai_params = Params.openai_params("text-embedding-3-small", "somekey")

      ingestion_list = [%{text: "hello"}, %{text: "hello again"}]

      ref =
        :telemetry_test.attach_event_handlers(self(), [
          [:rag, :generate_embeddings_batch, :start],
          [:rag, :generate_embeddings_batch, :stop],
          [:rag, :generate_embeddings_batch, :exception]
        ])

      Embedding.Http.generate_embeddings_batch(
        ingestion_list,
        openai_params,
        text_key: :text,
        embedding_key: :embedding
      )

      assert_received {[:rag, :generate_embeddings_batch, :start], ^ref, _measurement, _meta}
      assert_received {[:rag, :generate_embeddings_batch, :stop], ^ref, _measurement, _meta}

      expect(Req, :post!, fn _url, _params -> raise "boom" end)

      assert_raise RuntimeError, fn ->
        Embedding.Http.generate_embeddings_batch(
          ingestion_list,
          openai_params,
          text_key: :text,
          embedding_key: :embedding
        )
      end

      assert_received {[:rag, :generate_embeddings_batch, :exception], ^ref, _measurement, _meta}
    end
  end
end
