defmodule Mix.Tasks.Rag.GenEval do
  use Igniter.Mix.Task

  @example "mix rag.gen_eval"

  @shortdoc "Generates an evaluation script"
  @moduledoc """
  #{@shortdoc}

  Generates a script to perform evaluation of the RAG system.
  The script should be adapted to the specific use case.

  ## Example

  ```bash
  #{@example}
  ```

  ## Options

  """

  @impl Igniter.Mix.Task
  def info(_argv, _composing_task) do
    %Igniter.Mix.Task.Info{
      group: :rag,
      example: @example
    }
  end

  @impl Igniter.Mix.Task
  def igniter(igniter) do
    app_name = Igniter.Project.Application.app_name(igniter)

    root_module =
      app_name
      |> to_string()
      |> Macro.camelize()

    rag_module = Module.concat(root_module, "Rag")

    igniter
    |> Igniter.Project.Config.configure(
      "config.exs",
      app_name,
      [:openai_key],
      "your openai API key"
    )
    |> Igniter.include_or_create_file(
      "eval/rag_triad_eval.exs",
      """
      openai_key = Application.compile_env(#{inspect(app_name)}, :openai_key)
      dataset = "https://huggingface.co/datasets/explodinggradients/amnesty_qa/resolve/main/english.json"

      IO.puts("downloading dataset")

      data =
        Req.get!(dataset).body
        |> Jason.decode!()

      IO.puts("indexing")

      data["contexts"]
        |> Enum.map(&Enum.join(&1, " "))
        |> Enum.with_index(fn context, index -> %{document: context, source: \"\#{index}\"} end)
        |> #{inspect(rag_module)}.index()

      IO.puts("generating responses")

      generations = for question <- data["question"] do
        #{inspect(rag_module)}.query(question)
      end

      openai_params = Rag.Evaluation.Http.Params.openai_params(
        model: "gpt-4o-mini",
        api_key: openai_key
      )

      IO.puts("evaluating")

      generations =
        for generation <- generations do
          Rag.Evaluation.Http.evaluate_rag_triad(generation, openai_params)
        end

      json = generations |> Enum.map(& &1.evaluations) |> Jason.encode!()

      File.write!(Path.join(__DIR__, "triad_eval.json"), json)

      average_rag_triad_scores = Enum.map(generations, 
        fn gen -> 
          %{evaluations: %{"context_relevance_score" => context_relevance_score, "groundedness_score" => groundedness_score, "answer_relevance_score" => answer_relevance_score}} = gen

          (context_relevance_score + groundedness_score + answer_relevance_score) / 3
        end)

      total_average_score = Enum.sum(average_rag_triad_scores) / Enum.count(average_rag_triad_scores)

      IO.puts("Score: \#{total_average_score}")
      """
    )
  end
end
