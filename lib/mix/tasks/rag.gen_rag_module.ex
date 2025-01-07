defmodule Mix.Tasks.Rag.GenRagModule do
  use Igniter.Mix.Task

  @example "mix rag.gen_rag_module pgvector"

  @shortdoc "Generates a module containing RAG related code"
  @moduledoc """
  #{@shortdoc}

  Generates a module with an ingestion pipeline and a retrieval and generation pipeline.

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
      example: @example,
      schema: [vector_store: :string],
      defaults: [vector_store: "pgvector"],
      required: [:vector_store]
    }
  end

  @impl Igniter.Mix.Task
  def igniter(igniter) do
    options = igniter.args.options
    vector_store = Keyword.fetch!(options, :vector_store)

    case vector_store do
      "pgvector" ->
        add_rag_module(igniter, :pgvector)

      "chroma" ->
        add_rag_module(igniter, :chroma)

      _other ->
        raise "Only pgvector and chroma are supported. Run `mix rag.gen_rag_module --vector-store pgvector` or `mix rag.gen_rag_module --vector-store chroma`"
    end
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
      alias Rag.{Embedding, Generation, Retrieval}

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
          |> Enum.flat_map(&chunk_text(&1, :document))
          |> Embedding.Nx.generate_embeddings_batch(Rag.EmbeddingServing, text_key: :chunk, embedding_key: :embedding)
          |> Enum.map(&to_chunk(&1))

        Repo.insert_all(#{inspect(schema_module)}, chunks)
      end

      defp chunk_text(ingestion, text_key, opts \\\\ []) do
        text = Map.fetch!(ingestion, text_key)
        chunks = TextChunker.split(text, opts)

        Enum.map(chunks, &Map.put(ingestion, :chunk, &1.text))
      end

      def query(query) do
        generation =
          Generation.new(query)
          |> Embedding.Nx.generate_embedding(Rag.EmbeddingServing)
          |> Retrieval.retrieve(:fulltext_results, fn generation -> query_fulltext(generation) end)
          |> Retrieval.retrieve(:semantic_results, fn generation ->
            query_with_pgvector(generation)
          end)
          |> Retrieval.reciprocal_rank_fusion(
            %{fulltext_results: 1, semantic_results: 1},
            :rrf_result
          )
          |> Retrieval.deduplicate(:rrf_result, [:source])

        context =
          Generation.get_retrieval_result(generation, :rrf_result)
          |> Enum.map_join("\\n\\n", & &1.document)

        context_sources =
          Generation.get_retrieval_result(generation, :rrf_result)
          |> Enum.map(& &1.source)

        prompt = smollm_prompt(query, context)

        generation
        |> Generation.put_context(context)
        |> Generation.put_context_sources(context_sources)
        |> Generation.put_prompt(prompt)
        |> Generation.Nx.generate_response(Rag.LLMServing)
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
        query = query |> String.trim() |> String.replace(" ", " & ")

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
      alias Rag.{Embedding, Generation, Retrieval}

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
          |> Enum.flat_map(&chunk_text(&1, :document))
          |> Embedding.Nx.generate_embeddings_batch(Rag.EmbeddingServing, text_key: :chunk, embedding_key: :embedding)

        insert_all_with_chroma(collection, chunks)
      end

      defp chunk_text(ingestion, text_key, opts \\\\ []) do
        text = Map.fetch!(ingestion, text_key)
        chunks = TextChunker.split(text, opts)

        Enum.map(chunks, &Map.put(ingestion, :chunk, &1.text))
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
          Generation.new(query)
          |> Embedding.Nx.generate_embedding(Rag.EmbeddingServing)
          |> Retrieval.retrieve(:chroma, fn generation -> query_with_chroma(collection, generation) end)

        context =
          Generation.get_retrieval_result(generation, :chroma)
          |> Enum.map_join("\\n\\n", & &1.document)

        context_sources =
          Generation.get_retrieval_result(generation, :chroma)
          |> Enum.map(& &1.source)

        prompt = smollm_prompt(query, context)

        generation
        |> Generation.put_context(context)
        |> Generation.put_context_sources(context_sources)
        |> Generation.put_prompt(prompt)
        |> Generation.Nx.generate_response(Rag.LLMServing)
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
