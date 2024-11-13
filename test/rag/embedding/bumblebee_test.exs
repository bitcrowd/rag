defmodule Rag.Embedding.BumblebeeTest do
  use ExUnit.Case
  use Mimic

  alias Rag.Embedding

  describe "generate_embedding/4" do
    test "takes a string at source_key and returns input map with a list of numbers at target_key" do
      expect(Nx.Serving, :batched_run, fn _serving, _text ->
        %{embedding: Nx.tensor([1, 2, 3])}
      end)

      input = %{text: "hello"}

      assert Embedding.Bumblebee.generate_embedding(input, :text, :output) == %{
               text: "hello",
               output: [1, 2, 3]
             }
    end

    test "errors if source_key is not in input" do
      input = %{text: "hello"}

      assert_raise KeyError, fn ->
        Embedding.Bumblebee.generate_embedding(input, :non_existing_key, :output)
      end
    end

    test "errors if serving is not available" do
      input = %{text: "hello"}

      assert {:noproc, _} =
               catch_exit(
                 Embedding.Bumblebee.generate_embedding(
                   input,
                   NonExisting.Serving,
                   :text,
                   :output
                 )
               )
    end
  end

  describe "generate_embeddings_batch/4" do
    test "takes a string at source_key and returns input map with a list of numbers at target_key" do
      expect(Nx.Serving, :batched_run, fn _serving, ["hello", "hello again"] ->
        [%{embedding: Nx.tensor([1, 2, 3])}, %{embedding: Nx.tensor([4, 5, 6])}]
      end)

      inputs = [%{text: "hello"}, %{text: "hello again"}]

      assert [%{text: "hello", output: [1, 2, 3]}, %{text: "hello again", output: [4, 5, 6]}] ==
               Embedding.Bumblebee.generate_embeddings_batch(inputs, :text, :output)
    end

    test "errors if source_key is not in input" do
      inputs = [%{text: "hello"}]

      assert_raise KeyError, fn ->
        Embedding.Bumblebee.generate_embeddings_batch(inputs, :non_existing_key, :output)
      end
    end

    test "errors if serving is not available" do
      inputs = [%{text: "hello"}]

      assert {:noproc, _} =
               catch_exit(
                 Embedding.Bumblebee.generate_embeddings_batch(
                   inputs,
                   NonExisting.Serving,
                   :text,
                   :output
                 )
               )
    end
  end
end
