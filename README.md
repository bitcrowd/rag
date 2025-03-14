# Rag

<!-- README START -->

A library to build RAG (Retrieval Augmented Generation) systems in Elixir.

## Introduction to RAG

RAG enhances the capabilities of language models by combining retrieval-based and generative approaches.
Traditional language models often struggle with the following problems:

- **Knowledge Cutoff**: Their knowledge is limited to a fixed point in time, making it difficult to provide up-to-date information.
- **Hallucinations**: They may generate information that sounds confident but is entirely made up, leading to inaccurate responses.
- **Contextual Relevance**: They struggle to provide responses that are contextually relevant to the user's query.

RAG addresses these issues by retrieving relevant information from an external knowledge source before generating a response.
This retrieval-augmented approach ensures that the generated content is informed by the most current data, reducing the likelihood of hallucinations and improving the overall quality of the responses.
By integrating retrieval with generation, RAG enables more reliable and contextually relevant interactions, making it a valuable tool for applications that require accurate and informative language generation.

Check out [Getting Started](/notebooks/getting_started.livemd).

## Installation

If [available in Hex](https://hex.pm/docs/publish), the package can be installed
by adding `rag` to your list of dependencies in `mix.exs`:

```elixir
def deps do
  [
    {:rag, "~> 0.2.1"}
  ]
end
```

Then, run `mix rag.install --vector-store <vector_store>` to install required dependencies and generate a RAG system that you can further customize to your needs.

Currently supported options for `<vector_store>`:
- `pgvector`
- `chroma`

Brought to you by [bitcrowd](https://bitcrowd.net/en).

![bitcrowd logo](https://github.com/bitcrowd/rag/blob/main/.github/images/bitcrowd_logo.png?raw=true "bitcrowd logo")


<!-- README END -->
