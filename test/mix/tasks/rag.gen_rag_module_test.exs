defmodule Mix.Rag.GenRagModuleTest do
  use ExUnit.Case

  import Igniter.Test

  setup do
    [project: test_project()]
  end

  describe "rag.gen_rag_module --vector-store pgvector" do
    test "generates a Rag module with query_with_pgvector function", %{project: project} do
      igniter =
        project
        |> Igniter.compose_task("rag.gen_rag_module", ["--vector-store", "pgvector"])
        |> assert_creates("lib/test/rag.ex")

      assert Igniter.Test.diff(igniter, only: "lib/test/rag.ex") =~ "query_with_pgvector"
    end
  end

  describe "rag.gen_rag_module --vector-store chroma" do
    test "generates a module with query_with_chroma function", %{project: project} do
      igniter =
        project
        |> Igniter.compose_task("rag.gen_rag_module", ["--vector-store", "chroma"])
        |> assert_creates("lib/test/rag.ex")

      assert Igniter.Test.diff(igniter, only: "lib/test/rag.ex") =~ "query_with_chroma"
    end
  end
end
