# github-analyser

Small personal analytics project built around GitHub activity data and
`dataframe`'s existing Parquet reader support.

Current scope:

- fetch GitHub activity data from the GitHub API
- convert normalized tables to Parquet outside Haskell
- read and analyze those Parquet files in Haskell with `dataframe`

Repository layout:

- `data/raw/` for raw GitHub API responses
- `data/normalized/` for flattened intermediate tables
- `data/parquet/` for generated Parquet files
- `scripts/` for extraction and conversion tooling
