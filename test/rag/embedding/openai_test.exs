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
  end
end
