defmodule Rag.Ai do
  @moduledoc """
  Behaviour for AI capabilities.
  """

  @type embedding :: list(number())

  @doc """
  Passes `text` to the adapter using `adapter_params` to generate an embedding.
  """
  @callback generate_embedding(text :: String.t(), adapter_params :: any()) ::
              {:ok, embedding()} | {:error, any()}

  @doc """
  Passes all `texts` to the adapter using `adapter_params` to generate all embeddings in a single batch.
  """
  @callback generate_embeddings_batch(texts :: list(String.t()), adapter_params :: any()) ::
              {:ok, list(embedding())} | {:error, any()}

  @doc """
  Passes `prompt` to the adapter using `adapter_params` to generate a response.
  """
  @callback generate_response(prompt :: String.t(), adapter_params :: any()) ::
              {:ok, String.t()} | {:error, any()}
end
