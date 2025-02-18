defmodule Rag.EmbeddingTest do
  use ExUnit.Case

  alias Rag.Embedding
  alias Rag.Generation

  describe "generate_embedding/4" do
    test "takes a string at text_key and returns ingestion map with a list of numbers at embedding_key" do
      ingestion = %{text: "hello"}

      embedding_fn = fn "hello", _params -> [1, 2, 3] end

      assert Embedding.generate_embedding(ingestion, %{}, embedding_fn, []) == %{
               text: "hello",
               embedding: [1, 2, 3]
             }
    end

    test "errors if text_key is not in ingestion" do
      ingestion = %{text: "hello"}

      embedding_fn = fn "hello", _params -> [1, 2, 3] end

      assert_raise KeyError, fn ->
        Embedding.generate_embedding(ingestion, %{}, embedding_fn, text_key: :non_existing_key)
      end
    end

    test "emits start, stop, and exception telemetry events" do
      ingestion = %{text: "hello"}
      embedding_fn = fn "hello", _params -> [1, 2, 3] end

      ref =
        :telemetry_test.attach_event_handlers(self(), [
          [:rag, :generate_embedding, :start],
          [:rag, :generate_embedding, :stop],
          [:rag, :generate_embedding, :exception]
        ])

      Embedding.generate_embedding(ingestion, %{}, embedding_fn, [])

      assert_received {[:rag, :generate_embedding, :start], ^ref, _measurement, _meta}
      assert_received {[:rag, :generate_embedding, :stop], ^ref, _measurement, _meta}

      crashing_embedding_fn = fn _text, _params -> raise "boom" end

      assert_raise RuntimeError, fn ->
        Embedding.generate_embedding(ingestion, %{}, crashing_embedding_fn, [])
      end

      assert_received {[:rag, :generate_embedding, :exception], ^ref, _measurement, _meta}
    end
  end

  describe "generate_embedding/3" do
    test "takes the query from the generation, generates an embedding and puts it into query_embedding" do
      generation = %Generation{query: "query"}

      embedding_fn = fn "query", _params -> [1, 2, 3] end

      assert Embedding.generate_embedding(generation, %{}, embedding_fn) == %Generation{
               query: "query",
               query_embedding: [1, 2, 3]
             }
    end

    test "returns unchanged generation when halted? is true" do
      generation = %Generation{query: "query", halted?: true}

      assert generation ==
               Embedding.generate_embedding(generation, %{}, fn _text -> raise "unreachable" end)
    end

    test "emits start, stop, and exception telemetry events" do
      generation = Generation.new("hello")
      embedding_fn = fn "hello", _params -> [1, 2, 3] end

      ref =
        :telemetry_test.attach_event_handlers(self(), [
          [:rag, :generate_embedding, :start],
          [:rag, :generate_embedding, :stop],
          [:rag, :generate_embedding, :exception]
        ])

      Embedding.generate_embedding(generation, %{}, embedding_fn)

      assert_received {[:rag, :generate_embedding, :start], ^ref, _measurement, _meta}
      assert_received {[:rag, :generate_embedding, :stop], ^ref, _measurement, _meta}

      crashing_embedding_fn = fn _text, _params -> raise "boom" end

      assert_raise RuntimeError, fn ->
        Embedding.generate_embedding(generation, %{}, crashing_embedding_fn)
      end

      assert_received {[:rag, :generate_embedding, :exception], ^ref, _measurement, _meta}
    end
  end

  describe "generate_embeddings_batch/4" do
    test "takes a string at text_key and returns ingestion map with a list of numbers at embedding_key" do
      embedding_fn = fn ["hello", "hello again"], _params -> [[1, 2, 3], [4, 5, 6]] end
      ingestions = [%{text: "hello"}, %{text: "hello again"}]

      assert [
               %{text: "hello", embedding: [1, 2, 3]},
               %{text: "hello again", embedding: [4, 5, 6]}
             ] ==
               Embedding.generate_embeddings_batch(ingestions, %{}, embedding_fn, [])
    end

    test "errors if text_key is not in ingestion" do
      ingestions = [%{text: "hello"}]

      assert_raise KeyError, fn ->
        Embedding.generate_embeddings_batch(ingestions, %{}, fn _text -> raise "unreachable" end,
          text_key: :non_existing_key
        )
      end
    end

    test "emits start, stop, and exception telemetry events" do
      ingestions = [%{text: "hello"}, %{text: "hello again"}]
      embedding_fn = fn ["hello", "hello again"], _params -> [[1, 2, 3], [4, 5, 6]] end

      ref =
        :telemetry_test.attach_event_handlers(self(), [
          [:rag, :generate_embeddings_batch, :start],
          [:rag, :generate_embeddings_batch, :stop],
          [:rag, :generate_embeddings_batch, :exception]
        ])

      Embedding.generate_embeddings_batch(ingestions, %{}, embedding_fn, [])

      assert_received {[:rag, :generate_embeddings_batch, :start], ^ref, _measurement, _meta}
      assert_received {[:rag, :generate_embeddings_batch, :stop], ^ref, _measurement, _meta}

      crashing_embedding_fn = fn _text, _params -> raise "boom" end

      assert_raise RuntimeError, fn ->
        Embedding.generate_embeddings_batch(ingestions, %{}, crashing_embedding_fn, [])
      end

      assert_received {[:rag, :generate_embeddings_batch, :exception], ^ref, _measurement, _meta}
    end
  end
end
