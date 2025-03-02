defmodule Rag.Embedding.HttpTest do
  use ExUnit.Case
  use Mimic

  alias Rag.Embedding
  alias Rag.Generation
  alias Rag.Ai

  setup do
    %{provider: Ai.OpenAI.new(%{})}
  end

  describe "generate_embedding/3" do
    test "takes a string at text_key and returns map with a list of numbers at embedding_key", %{
      provider: provider
    } do
      expect(Req, :post, fn _url, _params ->
        {:ok, %Req.Response{status: 200, body: %{"data" => [%{"embedding" => [1, 2, 3]}]}}}
      end)

      ingestion = %{text: "hello"}

      assert Embedding.generate_embedding(ingestion, provider, []) ==
               %{
                 text: "hello",
                 embedding: [1, 2, 3]
               }
    end

    test "emits start, stop, and exception telemetry events", %{provider: provider} do
      expect(Req, :post, fn _url, _params ->
        {:ok, %Req.Response{status: 200, body: %{"data" => [%{"embedding" => [1, 2, 3]}]}}}
      end)

      ingestion = %{text: "hello"}

      ref =
        :telemetry_test.attach_event_handlers(self(), [
          [:rag, :generate_embedding, :start],
          [:rag, :generate_embedding, :stop],
          [:rag, :generate_embedding, :exception]
        ])

      Embedding.generate_embedding(ingestion, provider, [])

      assert_received {[:rag, :generate_embedding, :start], ^ref, _measurement, _meta}
      assert_received {[:rag, :generate_embedding, :stop], ^ref, _measurement, _meta}

      expect(Req, :post, fn _url, _params -> raise "boom" end)

      assert_raise RuntimeError, fn ->
        Embedding.generate_embedding(ingestion, provider, [])
      end

      assert_received {[:rag, :generate_embedding, :exception], ^ref, _measurement, _meta}
    end

    @tag :integration_test
    test "openai embeddings" do
      api_key = System.get_env("OPENAI_API_KEY")
      provider = Ai.OpenAI.new(%{embeddings_model: "text-embedding-ada-002", api_key: api_key})

      %{text: "hello", embedding: _embedding} =
        Embedding.generate_embedding(%{text: "hello"}, provider, [])
    end

    @tag :integration_test
    test "cohere embeddings" do
      api_key = System.get_env("COHERE_API_KEY")
      provider = Ai.Cohere.new(%{embeddings_model: "embed-english-v3.0", api_key: api_key})

      %{text: "hello", embedding: _embedding} =
        Embedding.generate_embedding(%{text: "hello"}, provider, [])
    end
  end

  describe "generate_embedding/2" do
    test "takes the query from the generation, generates an embedding and puts it into query_embedding",
         %{provider: provider} do
      expect(Req, :post, fn _url, _params ->
        {:ok, %Req.Response{status: 200, body: %{"data" => [%{"embedding" => [1, 2, 3]}]}}}
      end)

      generation = Generation.new("query")

      result = Embedding.generate_embedding(generation, provider)

      assert result == %Generation{
               query: "query",
               query_embedding: [1, 2, 3]
             }
    end

    test "returns unchanged generation when halted? is true", %{provider: provider} do
      generation = %Generation{query: "query", halted?: true}

      assert generation == Embedding.generate_embedding(generation, provider)
    end

    test "emits start, stop, and exception telemetry events", %{provider: provider} do
      expect(Req, :post, fn _url, _params ->
        {:ok, %Req.Response{status: 200, body: %{"data" => [%{"embedding" => [1, 2, 3]}]}}}
      end)

      generation = Generation.new("query")

      ref =
        :telemetry_test.attach_event_handlers(self(), [
          [:rag, :generate_embedding, :start],
          [:rag, :generate_embedding, :stop],
          [:rag, :generate_embedding, :exception]
        ])

      Embedding.generate_embedding(generation, provider)

      assert_received {[:rag, :generate_embedding, :start], ^ref, _measurement, _meta}
      assert_received {[:rag, :generate_embedding, :stop], ^ref, _measurement, _meta}

      expect(Req, :post, fn _url, _params -> raise "boom" end)

      assert_raise RuntimeError, fn ->
        Embedding.generate_embedding(generation, provider)
      end

      assert_received {[:rag, :generate_embedding, :exception], ^ref, _measurement, _meta}
    end
  end

  describe "generate_embeddings_batch/3" do
    test "takes a string at text_key and returns ingestion map with a list of numbers at embedding_key",
         %{provider: provider} do
      expect(Req, :post, fn _url, _params ->
        {:ok,
         %Req.Response{
           body: %{"data" => [%{"embedding" => [1, 2, 3]}, %{"embedding" => [4, 5, 6]}]}
         }}
      end)

      ingestion_list = [%{text: "hello"}, %{text: "hello again"}]

      result =
        Embedding.generate_embeddings_batch(
          ingestion_list,
          provider,
          text_key: :text,
          embedding_key: :embedding
        )

      assert result == [
               %{text: "hello", embedding: [1, 2, 3]},
               %{text: "hello again", embedding: [4, 5, 6]}
             ]
    end

    test "emits start, stop, and exception telemetry events", %{provider: provider} do
      expect(Req, :post, fn _url, _params ->
        {:ok,
         %Req.Response{
           body: %{"data" => [%{"embedding" => [1, 2, 3]}, %{"embedding" => [4, 5, 6]}]}
         }}
      end)

      ingestion_list = [%{text: "hello"}, %{text: "hello again"}]

      ref =
        :telemetry_test.attach_event_handlers(self(), [
          [:rag, :generate_embeddings_batch, :start],
          [:rag, :generate_embeddings_batch, :stop],
          [:rag, :generate_embeddings_batch, :exception]
        ])

      Embedding.generate_embeddings_batch(
        ingestion_list,
        provider,
        text_key: :text,
        embedding_key: :embedding
      )

      assert_received {[:rag, :generate_embeddings_batch, :start], ^ref, _measurement, _meta}
      assert_received {[:rag, :generate_embeddings_batch, :stop], ^ref, _measurement, _meta}

      expect(Req, :post, fn _url, _params -> raise "boom" end)

      assert_raise RuntimeError, fn ->
        Embedding.generate_embeddings_batch(
          ingestion_list,
          provider,
          text_key: :text,
          embedding_key: :embedding
        )
      end

      assert_received {[:rag, :generate_embeddings_batch, :exception], ^ref, _measurement, _meta}
    end

    @tag :integration_test
    test "openai embeddings" do
      api_key = System.get_env("OPENAI_API_KEY")
      provider = Ai.OpenAI.new(%{embeddings_model: "text-embedding-ada-002", api_key: api_key})

      [%{text: "hello", embedding: _embedding}] =
        Embedding.generate_embeddings_batch([%{text: "hello"}], provider, [])
    end

    @tag :integration_test
    test "cohere embeddings" do
      api_key = System.get_env("COHERE_API_KEY")
      provider = Ai.Cohere.new(%{embeddings_model: "embed-english-v3.0", api_key: api_key})

      [%{text: "hello", embedding: _embedding}] =
        Embedding.generate_embeddings_batch([%{text: "hello"}], provider, [])
    end
  end
end
