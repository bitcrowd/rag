defmodule Mix.Rag.GenEvalTest do
  use ExUnit.Case

  import Igniter.Test

  setup do
    [project: test_project()]
  end

  test "generates an evaluation script", %{project: project} do
    project
    |> Igniter.compose_task("rag.gen_eval")
    |> assert_creates("eval/rag_triad_eval.exs")
  end
end
