defmodule Mix.Rag.GenServingsTest do
  use ExUnit.Case

  import Igniter.Test

  setup do
    [project: test_project()]
  end

  test "generates `Nx.Serving`s", %{project: project} do
    project
    |> Igniter.compose_task("rag.gen_servings")
    |> assert_creates("lib/test/rag/serving.ex")
    |> assert_has_patch("lib/test/application.ex", """
    9  |      {Nx.Serving,
    10 |       [
    11 |         serving: Test.Rag.Serving.build_llm_serving(),
    12 |         name: Rag.LLMServing,
    13 |         batch_timeout: 100
    14 |       ]},
    15 |      {Nx.Serving,
    16 |       [
    17 |         serving: Test.Rag.Serving.build_embedding_serving(),
    18 |         name: Rag.EmbeddingServing,
    19 |         batch_timeout: 100
    20 |       ]}
    """)
  end
end
