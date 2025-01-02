defmodule Mix.Tasks.Rag.Install do
  use Igniter.Mix.Task

  @example "mix rag.install --vector-store pgvector"

  @shortdoc "Installs the rag library"
  @moduledoc """
  #{@shortdoc}

  Installs required dependencies and generates code to set you up to get started with your selected vector store.

  ## Example

  ```bash
  #{@example}
  ```

  ## Options

  """

  @impl Igniter.Mix.Task
  def info(_argv, _composing_task) do
    %Igniter.Mix.Task.Info{
      # Groups allow for overlapping arguments for tasks by the same author
      # See the generators guide for more.
      group: :rag,
      # dependencies to add
      adds_deps: [],
      # dependencies to add and call their associated installers, if they exist
      installs: [],
      # An example invocation
      example: @example,
      # A list of environments that this should be installed in.
      only: nil,
      # a list of positional arguments, i.e `[:file]`
      positional: [],
      # Other tasks your task composes using `Igniter.compose_task`, passing in the CLI argv
      # This ensures your option schema includes options from nested tasks
      composes: ["rag.gen_eval", "rag.gen_servings", "rag.gen_rag_module"],
      # `OptionParser` schema
      schema: [vector_store: :string],
      # Default values for the options in the `schema`
      defaults: [vector_store: "pgvector"],
      # CLI aliases
      aliases: [],
      # A list of options in the schema that are required
      required: [:vector_store]
    }
  end

  @impl Igniter.Mix.Task
  def igniter(igniter) do
    # Do your work here and return an updated igniter
    options = igniter.args.options
    vector_store = Keyword.fetch!(options, :vector_store)

    igniter =
      igniter
      |> Igniter.Project.Deps.add_dep({:igniter, "~> 0.4.8"})
      |> Igniter.Project.Deps.add_dep({:langchain, "~> 0.3.0-rc.1"})
      |> Igniter.Project.Deps.add_dep({:text_chunker, "~> 0.3.1"})
      |> Igniter.Project.Deps.add_dep({:bumblebee, "~> 0.6.0"})
      |> Igniter.Project.Deps.add_dep({:axon, "~> 0.7.0"})
      |> Igniter.Project.Deps.add_dep({:exla, "~> 0.9.1"})
      |> Igniter.Project.Deps.add_dep({:nx, "~> 0.9.0"})
      |> Igniter.Project.Config.configure("config.exs", :nx, [:default_backend], EXLA.Backend)
      |> Igniter.compose_task("rag.gen_eval")
      |> Igniter.compose_task("rag.gen_servings")
      |> Igniter.compose_task("rag.gen_rag_module")

    case vector_store do
      "pgvector" ->
        with_pgvector(igniter)

      "chroma" ->
        with_chroma(igniter)

      _other ->
        raise "Only pgvector and chroma are supported. Run `mix rag.gen_rag_module --vector-store pgvector` or `mix rag.gen_rag_module --vector-store chroma`"
    end
  end

  defp with_chroma(igniter) do
    igniter
    |> Igniter.Project.Deps.add_dep({:chroma, "~> 0.1.3"})
    |> Igniter.apply_and_fetch_dependencies()
    |> Igniter.Project.Config.configure("config.exs", :chroma, [:host], "http://localhost:8000")
    |> Igniter.Project.Config.configure("config.exs", :chroma, [:api_base], "api")
    |> Igniter.Project.Config.configure("config.exs", :chroma, [:api_version], "v1")
  end

  defp with_pgvector(igniter) do
    app_name = Igniter.Project.Application.app_name(igniter)

    root_module =
      app_name
      |> to_string()
      |> Macro.camelize()

    repo_module = Module.concat(root_module, "Repo")
    postgrex_types_module = Module.concat(root_module, "PostgrexTypes")
    schema_module = Module.concat(root_module, "Rag.Chunk")

    igniter
    |> Igniter.Project.Deps.add_dep({:ecto, "~> 3.0"})
    |> Igniter.Project.Deps.add_dep({:ecto_sql, "~> 3.10"})
    |> Igniter.Project.Deps.add_dep({:pgvector, "~> 0.3.0"})
    |> Igniter.apply_and_fetch_dependencies()
    |> Igniter.include_or_create_file(
      "lib/postgrex_types.ex",
      """
      Postgrex.Types.define(#{inspect(postgrex_types_module)}, [Pgvector.Extensions.Vector] ++ Ecto.Adapters.Postgres.extensions(), [])
      """
    )
    |> Igniter.Project.Config.configure(
      "config.exs",
      app_name,
      [repo_module, :types],
      postgrex_types_module
    )
    |> Igniter.Project.Module.create_module(
      schema_module,
      """
      use Ecto.Schema

      schema "chunks" do
        field(:document, :string)
        field(:source, :string)
        field(:chunk, :string)
        field(:embedding, Pgvector.Ecto.Vector)

        timestamps()
      end

      def changeset(chunk \\\\ %__MODULE__{}, attrs) do
        Ecto.Changeset.cast(chunk, attrs, [:document, :source, :chunk, :embedding])
      end
      """
    )
    |> Igniter.Libs.Ecto.gen_migration(repo_module, "create_chunks_table",
      body: """
      def up() do
        execute("CREATE EXTENSION IF NOT EXISTS vector")

        flush()

        create table(:chunks) do
          add(:document, :text)
          add(:source, :text)
          add(:chunk, :text)
          add(:embedding, :vector, size: 384)

          timestamps()
        end
      end

      def down() do
        drop(table(:chunks))
        execute("DROP EXTENSION vector")
      end
      """
    )
  end
end
