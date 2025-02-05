defmodule Rag.Embedding.NxTest do
  use ExUnit.Case
  use Mimic

  alias Rag.Embedding
  alias Rag.Generation

  describe "generate_embedding/3" do
    test "takes a string at text_key and returns ingestion map with a list of numbers at embedding_key" do
      expect(Nx.Serving, :batched_run, fn _serving, _text ->
        %{embedding: Nx.tensor([1, 2, 3])}
      end)

      ingestion = %{text: "hello"}

      assert Embedding.Nx.generate_embedding(ingestion, TestServing, []) == %{
               text: "hello",
               embedding: [1, 2, 3]
             }
    end

    test "errors if text_key is not in ingestion" do
      ingestion = %{text: "hello"}

      assert_raise KeyError, fn ->
        Embedding.Nx.generate_embedding(ingestion, TestServing, text_key: :non_existing_key)
      end
    end

    test "errors if serving is not available" do
      ingestion = %{text: "hello"}

      assert {:noproc, _} =
               catch_exit(Embedding.Nx.generate_embedding(ingestion, NonExisting.Serving, []))
    end

    test "emits start, stop, and exception telemetry events" do
      expect(Nx.Serving, :batched_run, fn serving, text ->
        assert serving == TestServing
        assert text == "hello"

        %{embedding: Nx.tensor([1, 2, 3])}
      end)

      ingestion = %{text: "hello"}

      ref =
        :telemetry_test.attach_event_handlers(self(), [
          [:rag, :generate_embedding, :start],
          [:rag, :generate_embedding, :stop],
          [:rag, :generate_embedding, :exception]
        ])

      Embedding.Nx.generate_embedding(ingestion, TestServing, [])

      assert_received {[:rag, :generate_embedding, :start], ^ref, _measurement, _meta}
      assert_received {[:rag, :generate_embedding, :stop], ^ref, _measurement, _meta}

      expect(Nx.Serving, :batched_run, fn _serving, _text -> raise "boom" end)

      assert_raise RuntimeError, fn ->
        Embedding.Nx.generate_embedding(ingestion, TestServing, [])
      end

      assert_received {[:rag, :generate_embedding, :exception], ^ref, _measurement, _meta}
    end
  end

  describe "generate_embedding/2" do
    test "takes the query from the generation, generates an embedding and puts it into query_embedding" do
      expect(Nx.Serving, :batched_run, fn _serving, "query" ->
        %{embedding: Nx.tensor([1, 2, 3])}
      end)

      generation = %Generation{query: "query"}

      assert Embedding.Nx.generate_embedding(generation, TestServing) == %Generation{
               query: "query",
               query_embedding: [1, 2, 3]
             }
    end

    test "errors if serving is not available" do
      generation = Generation.new("hello")

      assert {:noproc, _} =
               catch_exit(Embedding.Nx.generate_embedding(generation, NonExisting.Serving))
    end

    test "emits start, stop, and exception telemetry events" do
      expect(Nx.Serving, :batched_run, fn serving, text ->
        assert serving == TestServing
        assert text == "hello"

        %{embedding: Nx.tensor([1, 2, 3])}
      end)

      generation = Generation.new("hello")

      ref =
        :telemetry_test.attach_event_handlers(self(), [
          [:rag, :generate_embedding, :start],
          [:rag, :generate_embedding, :stop],
          [:rag, :generate_embedding, :exception]
        ])

      Embedding.Nx.generate_embedding(generation, TestServing)

      assert_received {[:rag, :generate_embedding, :start], ^ref, _measurement, _meta}
      assert_received {[:rag, :generate_embedding, :stop], ^ref, _measurement, _meta}

      expect(Nx.Serving, :batched_run, fn _serving, _text -> raise "boom" end)

      assert_raise RuntimeError, fn ->
        Embedding.Nx.generate_embedding(generation, TestServing)
      end

      assert_received {[:rag, :generate_embedding, :exception], ^ref, _measurement, _meta}
    end
  end

  describe "generate_embeddings_batch/3" do
    test "takes a string at text_key and returns ingestion map with a list of numbers at embedding_key" do
      expect(Nx.Serving, :batched_run, fn _serving, ["hello", "hello again"] ->
        [%{embedding: Nx.tensor([1, 2, 3])}, %{embedding: Nx.tensor([4, 5, 6])}]
      end)

      ingestions = [%{text: "hello"}, %{text: "hello again"}]

      assert [
               %{text: "hello", embedding: [1, 2, 3]},
               %{text: "hello again", embedding: [4, 5, 6]}
             ] ==
               Embedding.Nx.generate_embeddings_batch(ingestions, TestServing, [])
    end

    test "errors if text_key is not in ingestion" do
      ingestions = [%{text: "hello"}]

      assert_raise KeyError, fn ->
        Embedding.Nx.generate_embeddings_batch(ingestions, TestServing,
          text_key: :non_existing_key
        )
      end
    end

    test "errors if serving is not available" do
      ingestions = [%{text: "hello"}]

      assert {:noproc, _} =
               catch_exit(
                 Embedding.Nx.generate_embeddings_batch(ingestions, NonExisting.Serving, [])
               )
    end

    test "emits start, stop, and exception telemetry events" do
      expect(Nx.Serving, :batched_run, fn _serving, ["hello", "hello again"] ->
        [%{embedding: Nx.tensor([1, 2, 3])}, %{embedding: Nx.tensor([4, 5, 6])}]
      end)

      ingestions = [%{text: "hello"}, %{text: "hello again"}]

      ref =
        :telemetry_test.attach_event_handlers(self(), [
          [:rag, :generate_embeddings_batch, :start],
          [:rag, :generate_embeddings_batch, :stop],
          [:rag, :generate_embeddings_batch, :exception]
        ])

      Embedding.Nx.generate_embeddings_batch(ingestions, TestServing, [])

      assert_received {[:rag, :generate_embeddings_batch, :start], ^ref, _measurement, _meta}
      assert_received {[:rag, :generate_embeddings_batch, :stop], ^ref, _measurement, _meta}

      expect(Nx.Serving, :batched_run, fn _serving, _text -> raise "boom" end)

      assert_raise RuntimeError, fn ->
        Embedding.Nx.generate_embeddings_batch(ingestions, TestServing, [])
      end

      assert_received {[:rag, :generate_embeddings_batch, :exception], ^ref, _measurement, _meta}
    end
  end
end
