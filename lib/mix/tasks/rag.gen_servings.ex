defmodule Mix.Tasks.Rag.GenServings do
  use Igniter.Mix.Task

  @example "mix rag.gen_servings"

  @shortdoc "Generates `Nx.Serving`s to run an embedding model and an LLM"
  @moduledoc """
  #{@shortdoc}

  Generates `Nx.Serving`s to run an embedding model and an LLM

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

    servings_module = Module.concat(root_module, "Rag.Serving")

    igniter
    |> Igniter.Project.Module.create_module(
      servings_module,
      """
      @moduledoc \"""
      Functions to build servings that can be used with `Rag.Ai.Nx`.
      \"""

      alias Bumblebee.Text

      def build_embedding_serving do
        repo = {:hf, "thenlper/gte-small"}

        {:ok, model_info} = Bumblebee.load_model(repo)

        {:ok, tokenizer} = Bumblebee.load_tokenizer(repo)

        Text.TextEmbedding.text_embedding(model_info, tokenizer,
          compile: [batch_size: 64, sequence_length: 512],
          defn_options: [compiler: EXLA],
          output_attribute: :hidden_state,
          output_pool: :mean_pooling
        )
      end

      def build_llm_serving do
        repo = {:hf, "HuggingFaceTB/SmolLM2-135M-Instruct"}

        {:ok, model_info} = Bumblebee.load_model(repo)
        {:ok, tokenizer} = Bumblebee.load_tokenizer(repo)
        {:ok, generation_config} = Bumblebee.load_generation_config(repo)

        generation_config = Bumblebee.configure(generation_config, max_new_tokens: 100)

        Text.generation(model_info, tokenizer, generation_config,
          compile: [batch_size: 1, sequence_length: 6000],
          defn_options: [compiler: EXLA],
          stream: false
        )
      end
      """
    )
    |> Igniter.Project.Application.add_new_child(
      {Nx.Serving,
       {:code,
        Sourceror.parse_string!("""
        [ 
          serving: #{inspect(servings_module)}.build_embedding_serving(),
          name: Rag.EmbeddingServing,
          batch_timeout: 100
        ]
        """)}}
    )
    |> Igniter.Project.Application.add_new_child(
      {Nx.Serving,
       {:code,
        Sourceror.parse_string!("""
        [
          serving: #{inspect(servings_module)}.build_llm_serving(),
          name: Rag.LLMServing,
          batch_timeout: 100
        ]
        """)}},
      force?: true
    )
  end
end
