defmodule Rag.Embedding.HttpTest do
  use ExUnit.Case
  use Mimic

  alias Rag.Embedding
  alias Rag.Generation
  alias Rag.Ai.Http.EmbeddingParams

  describe "generate_embedding/3" do
    test "takes a string at text_key and returns map with a list of numbers at embedding_key" do
      expect(Req, :post!, fn _url, _params ->
        %{body: %{"data" => [%{"embedding" => [1, 2, 3]}]}}
      end)

      ingestion = %{text: "hello"}

      openai_params = EmbeddingParams.openai_params("text-embedding-3-small", "somekey")

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

      openai_params = EmbeddingParams.openai_params("text-embedding-3-small", "somekey")

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

    @tag :integration_test
    test "openai embeddings" do
      api_key = System.get_env("OPENAI_API_KEY")
      params = EmbeddingParams.openai_params("text-embedding-ada-002", api_key)

      %{text: "hello", embedding: _embedding} =
        Embedding.Http.generate_embedding(%{text: "hello"}, params, [])
    end

    @tag :integration_test
    test "cohere embeddings" do
      api_key = System.get_env("COHERE_API_KEY")
      params = EmbeddingParams.cohere_params("embed-english-v3.0", api_key)

      %{text: "hello", embedding: _embedding} =
        Embedding.Http.generate_embedding(%{text: "hello"}, params, [])
    end
  end

  describe "generate_embedding/2" do
    test "takes the query from the generation, generates an embedding and puts it into query_embedding" do
      expect(Req, :post!, fn _url, _params ->
        %{body: %{"data" => [%{"embedding" => [1, 2, 3]}]}}
      end)

      generation = Generation.new("query")

      openai_params = EmbeddingParams.openai_params("text-embedding-3-small", "somekey")

      assert Embedding.Http.generate_embedding(generation, openai_params) == %Generation{
               query: "query",
               query_embedding: [1, 2, 3]
             }
    end

    test "returns unchanged generation when halted? is true" do
      generation = %Generation{query: "query", halted?: true}

      openai_params = EmbeddingParams.openai_params("text-embedding-3-small", "somekey")

      assert generation == Embedding.Http.generate_embedding(generation, openai_params)
    end

    test "emits start, stop, and exception telemetry events" do
      expect(Req, :post!, fn _url, _params ->
        %{body: %{"data" => [%{"embedding" => [1, 2, 3]}]}}
      end)

      generation = Generation.new("query")

      openai_params = EmbeddingParams.openai_params("text-embedding-3-small", "somekey")

      ref =
        :telemetry_test.attach_event_handlers(self(), [
          [:rag, :generate_embedding, :start],
          [:rag, :generate_embedding, :stop],
          [:rag, :generate_embedding, :exception]
        ])

      Embedding.Http.generate_embedding(generation, openai_params)

      assert_received {[:rag, :generate_embedding, :start], ^ref, _measurement, _meta}
      assert_received {[:rag, :generate_embedding, :stop], ^ref, _measurement, _meta}

      expect(Req, :post!, fn _url, _params -> raise "boom" end)

      assert_raise RuntimeError, fn ->
        Embedding.Http.generate_embedding(generation, openai_params)
      end

      assert_received {[:rag, :generate_embedding, :exception], ^ref, _measurement, _meta}
    end
  end

  describe "generate_embeddings_batch/3" do
    test "takes a string at text_key and returns ingestion map with a list of numbers at embedding_key" do
      expect(Req, :post!, fn _url, _params ->
        %{body: %{"data" => [%{"embedding" => [1, 2, 3]}, %{"embedding" => [4, 5, 6]}]}}
      end)

      openai_params = EmbeddingParams.openai_params("text-embedding-3-small", "somekey")

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

      openai_params = EmbeddingParams.openai_params("text-embedding-3-small", "somekey")

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

    @tag :integration_test
    test "openai embeddings" do
      api_key = System.get_env("OPENAI_API_KEY")
      params = EmbeddingParams.openai_params("text-embedding-ada-002", api_key)

      [%{text: "hello", embedding: _embedding}] =
        Embedding.Http.generate_embeddings_batch([%{text: "hello"}], params, [])
    end

    @tag :integration_test
    test "cohere embeddings" do
      api_key = System.get_env("COHERE_API_KEY")
      params = EmbeddingParams.cohere_params("embed-english-v3.0", api_key)

      [%{text: "hello", embedding: _embedding}] =
        Embedding.Http.generate_embeddings_batch([%{text: "hello"}], params, [])
    end
  end
end
