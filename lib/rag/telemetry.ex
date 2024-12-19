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
    [:rag, :retrieve, :start],
    [:rag, :retrieve, :exception],
    [:rag, :retrieve, :stop],
    [:rag, :detect_hallucination, :start],
    [:rag, :detect_hallucination, :exception],
    [:rag, :detect_hallucination, :stop],
    [:rag, :evaluate_rag_triad, :start],
    [:rag, :evaluate_rag_triad, :exception],
    [:rag, :evaluate_rag_triad, :stop]
  ]

  @doc """
  Lists all telemetry events.
  """
  def events, do: @events
end
