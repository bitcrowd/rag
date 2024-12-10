defmodule Rag.Telemetry do
  @moduledoc """
  Provides information about telemetry events.
  """

  @events [
    [:rag, :generate_embedding, :start],
    [:rag, :generate_embedding, :exception],
    [:rag, :generate_embedding, :stop],
    [:rag, :generate_embeddings_batch, :start],
    [:rag, :generate_embeddings_batch, :exception],
    [:rag, :generate_embeddings_batch, :stop],
    [:rag, :generate_response, :start],
    [:rag, :generate_response, :exception],
    [:rag, :generate_response, :stop],
    [:rag, :detect_hallucination, :start],
    [:rag, :detect_hallucination, :exception],
    [:rag, :detect_hallucination, :stop]
  ]

  @doc """
  Lists all telemetry events.
  """
  def events, do: @events
end
