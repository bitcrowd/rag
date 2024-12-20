defmodule Mix.Tasks.Rag.Install do
  use Igniter.Mix.Task

  @example "mix rag.install pgvector"

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
      positional: [:vector_store],
      # Other tasks your task composes using `Igniter.compose_task`, passing in the CLI argv
      # This ensures your option schema includes options from nested tasks
      composes: [],
      # `OptionParser` schema
      schema: [],
      # Default values for the options in the `schema`
      defaults: [],
      # CLI aliases
      aliases: [],
      # A list of options in the schema that are required
      required: []
    }
  end

  @impl Igniter.Mix.Task
  def igniter(igniter) do
    # Do your work here and return an updated igniter
    %{vector_store: vector_store} = igniter.args.positional

    igniter =
      igniter
      |> Igniter.Project.Deps.add_dep({:langchain, "~> 0.3.0-rc.0"})
      |> Igniter.Project.Deps.add_dep({:text_chunker, "~> 0.3.1"})
      |> Igniter.Project.Deps.add_dep({:bumblebee, "~> 0.6.0"})
      |> Igniter.Project.Deps.add_dep({:axon, "~> 0.7.0"})
      |> Igniter.Project.Deps.add_dep({:exla, "~> 0.9.1"})
      |> Igniter.Project.Deps.add_dep({:nx, "~> 0.9.0"})
      |> Igniter.Project.Config.configure("config.exs", :nx, [:default_backend], EXLA.Backend)

    case vector_store do
      "pgvector" ->
        with_pgvector(igniter)

      "chroma" ->
        with_chroma(igniter)

      _other ->
        raise "Only pgvector and chroma are supported. Run `mix rag.install pgvector` or `mix rag.install chroma`"
    end
  end

  defp with_chroma(igniter) do
    igniter
    |> Igniter.Project.Deps.add_dep({:chroma, "~> 0.1.3"})
    |> Igniter.apply_and_fetch_dependencies()
    |> add_config(:chroma)
    |> add_servings()
    |> add_rag_module(:chroma)
  end

  defp add_config(igniter, :chroma) do
    igniter
    |> Igniter.Project.Config.configure("config.exs", :chroma, [:host], "http://localhost:8000")
    |> Igniter.Project.Config.configure("config.exs", :chroma, [:api_base], "api")
    |> Igniter.Project.Config.configure("config.exs", :chroma, [:api_version], "v1")
  end

  defp with_pgvector(igniter) do
    igniter
    |> Igniter.Project.Deps.add_dep({:ecto, "~> 3.0"})
    |> Igniter.Project.Deps.add_dep({:ecto_sql, "~> 3.10"})
    |> Igniter.Project.Deps.add_dep({:pgvector, "~> 0.3.0"})
    |> Igniter.apply_and_fetch_dependencies()
    |> add_postgrex_types()
    |> add_schema(:pgvector)
    |> add_migration(:pgvector)
    |> add_servings()
    |> add_rag_module(:pgvector)
  end

  defp add_postgrex_types(igniter) do
    app_name = Igniter.Project.Application.app_name(igniter)

    root_module =
      app_name
      |> to_string()
      |> Macro.camelize()

    repo_module = Module.concat(root_module, "Repo")
    postgrex_types_module = Module.concat(root_module, "PostgrexTypes")

    igniter
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
  end

  defp add_schema(igniter, :pgvector) do
    app_name = Igniter.Project.Application.app_name(igniter)

    root_module =
      app_name
      |> to_string()
      |> Macro.camelize()

    schema_module = Module.concat(root_module, "Rag.Chunk")

    Igniter.Project.Module.create_module(
      igniter,
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
  end

  defp add_migration(igniter, :pgvector) do
    app_name = Igniter.Project.Application.app_name(igniter)

    root_module =
      app_name
      |> to_string()
      |> Macro.camelize()

    repo_module = Module.concat(root_module, "Repo")

    Igniter.Libs.Ecto.gen_migration(igniter, repo_module, "add_chunks_table",
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

  defp add_servings(igniter) do
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
      def build_embedding_serving() do
        repo = {:hf, "thenlper/gte-small"}

        {:ok, model_info} = Bumblebee.load_model(repo)

        {:ok, tokenizer} = Bumblebee.load_tokenizer(repo)

        Bumblebee.Text.TextEmbedding.text_embedding(model_info, tokenizer,
          compile: [batch_size: 64, sequence_length: 512],
          defn_options: [compiler: EXLA],
          output_attribute: :hidden_state,
          output_pool: :mean_pooling
        )
      end

      def build_llm_serving() do
        repo = {:hf, "HuggingFaceTB/SmolLM2-135M-Instruct"}

        {:ok, model_info} = Bumblebee.load_model(repo)
        {:ok, tokenizer} = Bumblebee.load_tokenizer(repo)
        {:ok, generation_config} = Bumblebee.load_generation_config(repo)

        generation_config = Bumblebee.configure(generation_config, max_new_tokens: 100)

        Bumblebee.Text.generation(model_info, tokenizer, generation_config,
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

  defp add_rag_module(igniter, :pgvector) do
    app_name = Igniter.Project.Application.app_name(igniter)

    root_module =
      app_name
      |> to_string()
      |> Macro.camelize()

    rag_module = Module.concat(root_module, "Rag")
    repo_module = Module.concat(root_module, "Repo")
    schema_module = Module.concat(root_module, "Rag.Chunk")

    Igniter.Project.Module.create_module(
      igniter,
      rag_module,
      """
      alias #{inspect(repo_module)}
      import Ecto.Query
      import Pgvector.Ecto.Query

      def ingest(path) do
        path
        |> load()
        |> index()
      end

      def load(path) do
        path
        |> list_text_files()
        |> Enum.map(&%{source: &1})
        |> Enum.map(&Rag.Loading.load_file(&1))
      end

      defp list_text_files(path) do
        path
        |> Path.join("/**/*.txt")
        |> Path.wildcard()
      end

      def index(ingestions) do
        chunks =
          ingestions
          |> Enum.flat_map(&Rag.Loading.chunk_text(&1, :document))
          |> Rag.Embedding.Nx.generate_embeddings_batch(:chunk, :embedding)
          |> Enum.map(&to_chunk(&1))

        Repo.insert_all(#{inspect(schema_module)}, chunks)
      end

      def query(query) do
        generation =
          Rag.Generation.new(query)
          |> Rag.Embedding.Nx.generate_embedding()
          |> Rag.Retrieval.retrieve(:fulltext_results, fn generation -> query_fulltext(generation) end)
          |> Rag.Retrieval.retrieve(:semantic_results, fn generation ->
            query_with_pgvector(generation)
          end)
          |> Rag.Retrieval.reciprocal_rank_fusion(
            %{fulltext_results: 1, semantic_results: 1},
            :rrf_result
          )

        context =
          Rag.Generation.get_retrieval_result(generation, :rrf_result)
          |> Enum.map_join("\n\n", & &1.document)

        context_sources =
          Rag.Generation.get_retrieval_result(generation, :rrf_result)
          |> Enum.map(& &1.source)

        prompt = smollm_prompt(query, context)

        generation = %{
          generation
          | context: context,
            context_sources: context_sources,
            prompt: prompt
        }

        Rag.Generation.Nx.generate_response(generation)
      end

      defp to_chunk(ingestion) do
        now = NaiveDateTime.utc_now() |> NaiveDateTime.truncate(:second)

        ingestion
        |> Map.put_new(:inserted_at, now)
        |> Map.put_new(:updated_at, now)
      end

      defp query_with_pgvector(%{query_embedding: query_embedding}, limit \\\\ 3) do
        Repo.all(
          from(c in #{inspect(schema_module)},
            order_by: l2_distance(c.embedding, ^Pgvector.new(query_embedding)),
            limit: ^limit
          )
        )
      end

      defp query_fulltext(%{query: query}, limit \\\\ 3) do
        query = String.replace(query, " ", " & ")

        Repo.all(
          from(c in #{inspect(schema_module)},
            where: fragment("to_tsvector(?) @@ to_tsquery(?)", c.document, ^query),
            limit: ^limit
          )
        )
      end

      defp smollm_prompt(query, context) do
        \"""
        <|im_start|>system
        You are a helpful assistant.<|im_end|>
        <|im_start|>user
        Context information is below.
        ---------------------
        \#{context}
        ---------------------
        Given the context information and no prior knowledge, answer the query.
        Query: \#{query}
        Answer: <|im_end|>
        <|im_start|>assist
        \"""
      end
      """
    )
  end

  defp add_rag_module(igniter, :chroma) do
    app_name = Igniter.Project.Application.app_name(igniter)

    root_module =
      app_name
      |> to_string()
      |> Macro.camelize()

    rag_module = Module.concat(root_module, "Rag")

    Igniter.Project.Module.create_module(
      igniter,
      rag_module,
      """
      def ingest(path) do
        path
        |> load()
        |> index()
      end

      def load(path) do
        path
        |> list_text_files()
        |> Enum.map(&%{source: &1})
        |> Enum.map(&Rag.Loading.load_file(&1))
      end

      defp list_text_files(path) do
        path
        |> Path.join("/**/*.txt")
        |> Path.wildcard()
      end

      def index(ingestions) do
        {:ok, collection} = Chroma.Collection.get_or_create("rag", %{"hnsw:space" => "l2"})

        chunks =
          ingestions
          |> Enum.flat_map(&Rag.Loading.chunk_text(&1, :document))
          |> Rag.Embedding.Nx.generate_embeddings_batch(:chunk, :embedding)

        insert_all_with_chroma(collection, chunks)
      end

      defp insert_all_with_chroma(collection, ingestions) do
        batch = for %{document: document, source: source, chunk: chunk, embedding: embedding} <- ingestions,
            reduce: %{documents: [], ids: [], sources: [], chunks: [], embeddings: []} do
          %{documents: documents, sources: sources, chunks: chunks, embeddings: embeddings} ->
            %{
              documents: [document | documents],
              sources: [source | sources],
              ids: [source | sources],
              chunks: [chunk | chunks],
              embeddings: [embedding | embeddings]
            }
        end
        |> Map.drop([:sources, :chunks])

        Chroma.Collection.add(collection, batch)
      end

      def query(query) do
        {:ok, collection} = Chroma.Collection.get_or_create("rag", %{"hnsw:space" => "l2"})

        generation =
          Rag.Generation.new(query)
          |> Rag.Embedding.Nx.generate_embedding(:query, :query_embedding)
          |> Rag.Retrieval.retrieve(:chroma, fn generation -> query_with_chroma(collection, generation) end)

        context =
          Rag.Generation.get_retrieval_result(generation, :chroma)
          |> Enum.map_join("\\n\\n", & &1.document)

        context_sources =
          Rag.Generation.get_retrieval_result(generation, :chroma)
          |> Enum.map(& &1.source)

        prompt = smollm_prompt(query, context)

        generation = %{
          generation
          | context: context,
            context_sources: context_sources,
            prompt: prompt
        }

        Rag.Generation.Nx.generate_response(generation)
      end

      defp query_with_chroma(collection, generation, limit \\\\ 3) do
        %{query_embedding: query_embedding} = generation

        {:ok, results} =
          Chroma.Collection.query(collection,
            results: limit,
            query_embeddings: [query_embedding]
          )

        {documents, sources} = {hd(results["documents"]), hd(results["ids"])}

        Enum.zip_with(documents, sources, fn document, source -> %{document: document, source: source} end)
      end


      defp smollm_prompt(query, context) do
        \"""
        <|im_start|>system
        You are a helpful assistant.<|im_end|>
        <|im_start|>user
        Context information is below.
        ---------------------
        \#{context}
        ---------------------
        Given the context information and no prior knowledge, answer the query.
        Query: \#{query}
        Answer: <|im_end|>
        <|im_start|>assist
        \"""
      end

      """
    )
  end
end
