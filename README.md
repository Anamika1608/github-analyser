# github-analyser

GitHub activity analytics project in Haskell that ingests real GitHub data, normalizes it into tabular datasets, materializes Parquet files, and reads
them back using `dataframe`'s existing Parquet reader for analysis.

Current scope:

- fetch GitHub activity data from the GitHub API
- convert normalized tables to Parquet outside Haskell
- read and analyze those Parquet files in Haskell with `dataframe`

Repository layout:

- `data/raw/` for raw GitHub API responses
- `data/normalized/` for flattened intermediate tables
- `data/parquet/` for generated Parquet files
- `scripts/` for extraction and conversion tooling


<img width="933" height="339" alt="2026-03-29_22-02-12" src="https://github.com/user-attachments/assets/f6772d8e-707f-4798-9b92-78e3e93c6e59" />
<br><br>
<img width="1104" height="250" alt="image" src="https://github.com/user-attachments/assets/2631f22c-9798-41e9-a9c4-b131899d1b9a" />
<br><br>
<img width="1600" height="1057" alt="image" src="https://github.com/user-attachments/assets/748bf930-973e-4936-8055-9f87e3d6b032" />
<br><br>
<img width="1600" height="1057" alt="image" src="https://github.com/user-attachments/assets/3911b857-c129-433a-a37d-989d73b3d253" />


## Configuration

- `GITHUB_TOKEN`
- `GITHUB_ANALYSER_USER`
- `GITHUB_ANALYSER_RAW_DIR`
- `GITHUB_ANALYSER_TOP_REPOS`
- `GITHUB_ANALYSER_COMMIT_LOOKBACK_DAYS`

Requirements:

- start from `.env.example` and set your token plus GitHub username
- install the `duckdb` CLI and ensure it is on your `PATH`
- keep the sibling [`dataframe`](/Users/anamika/open-source/haskell/dataframe) repository next to this project because [`cabal.project`](/Users/anamika/open-source/haskell/github-analyser/cabal.project#L1) references `../dataframe`

## Usage

Build and fetch the raw GitHub snapshot:

```bash
cabal build
cabal run github-analyser -- fetch-all
```

Generate normalized tables:

```bash
duckdb < scripts/normalize.duckdb.sql
```

Generate Parquet files:

```bash
duckdb < scripts/parquet.duckdb.sql
```

Read the generated Parquet files in Haskell with `dataframe`:

```bash
cabal run github-analyser -- analyze-parquet
```

## Outputs

Raw snapshot files are written to `data/raw/`.

Normalized tables are written to `data/normalized/`.

Parquet datasets are written to `data/parquet/`.
