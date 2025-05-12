defmodule Rag.Ai.Provider do
  @moduledoc """
  Behaviour for providers of AI capabilities.
  """

  @type embedding :: list(number())
  @type response :: String.t() | Enumerable.t()

  @doc """
  Creates a new provider struct.
  """
  @callback new(attrs :: map()) :: struct()

  @doc """
  Generates embeddings for `texts`.
  """
  @callback generate_embeddings(
              provider :: struct(),
              texts :: list(String.t()),
              opts :: keyword()
            ) ::
              {:ok, list(embedding())} | {:error, any()}

  @doc """
  Generates a text for `prompt`.
  """
  @callback generate_text(
              provider :: struct(),
              prompt :: String.t(),
              opts :: keyword()
            ) ::
              {:ok, response()} | {:error, any()}
end
