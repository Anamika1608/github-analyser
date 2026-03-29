COPY (
    SELECT
        CAST(id AS BIGINT) AS repo_id,
        CAST(name AS VARCHAR) AS repo_name,
        CAST(full_name AS VARCHAR) AS full_name,
        CAST(language AS VARCHAR) AS language,
        CAST(created_at AS VARCHAR) AS created_at,
        CAST(updated_at AS VARCHAR) AS updated_at,
        CAST(pushed_at AS VARCHAR) AS pushed_at,
        CAST(default_branch AS VARCHAR) AS default_branch,
        CAST(stargazers_count AS INTEGER) AS stargazers_count,
        CAST(watchers_count AS INTEGER) AS watchers_count,
        CAST(forks_count AS INTEGER) AS forks_count,
        CAST(open_issues_count AS INTEGER) AS open_issues_count,
        CAST(size AS INTEGER) AS size_kb,
        CAST(archived AS BOOLEAN) AS archived,
        CAST(disabled AS BOOLEAN) AS disabled,
        CAST(fork AS BOOLEAN) AS is_fork
    FROM read_json(
        'data/raw/repos.json',
        format = 'array',
        columns = {
            id: 'BIGINT',
            name: 'VARCHAR',
            full_name: 'VARCHAR',
            language: 'VARCHAR',
            created_at: 'VARCHAR',
            updated_at: 'VARCHAR',
            pushed_at: 'VARCHAR',
            default_branch: 'VARCHAR',
            stargazers_count: 'INTEGER',
            watchers_count: 'INTEGER',
            forks_count: 'INTEGER',
            open_issues_count: 'INTEGER',
            size: 'INTEGER',
            archived: 'BOOLEAN',
            disabled: 'BOOLEAN',
            fork: 'BOOLEAN'
        }
    )
    ORDER BY pushed_at DESC NULLS LAST, repo_name
) TO 'data/normalized/repos.csv' (FORMAT csv, HEADER);

COPY (
    SELECT
        CAST(id AS VARCHAR) AS event_id,
        CAST(type AS VARCHAR) AS event_type,
        CAST(
            CASE
                WHEN strpos(repo.name, '/') > 0 THEN split_part(repo.name, '/', 2)
                ELSE repo.name
            END AS VARCHAR
        ) AS repo_name,
        CAST(actor.login AS VARCHAR) AS actor_login,
        CAST(created_at AS VARCHAR) AS created_at,
        CAST(public AS BOOLEAN) AS is_public
    FROM read_json(
        'data/raw/events.json',
        format = 'array',
        columns = {
            id: 'VARCHAR',
            type: 'VARCHAR',
            repo: 'STRUCT(name VARCHAR)',
            actor: 'STRUCT(login VARCHAR)',
            created_at: 'VARCHAR',
            public: 'BOOLEAN'
        }
    )
    ORDER BY created_at DESC, event_id
) TO 'data/normalized/events.csv' (FORMAT csv, HEADER);

COPY (
    SELECT
        CAST(regexp_extract(html_url, 'github\.com/[^/]+/([^/]+)/commit/', 1) AS VARCHAR) AS repo_name,
        CAST(sha AS VARCHAR) AS sha,
        CAST(author.login AS VARCHAR) AS author_login,
        CAST(commit.author.name AS VARCHAR) AS author_name,
        CAST(coalesce(commit.author.date, commit.committer.date) AS VARCHAR) AS authored_at,
        CAST(commit.committer.date AS VARCHAR) AS committed_at,
        CAST(split_part(commit.message, chr(10), 1) AS VARCHAR) AS message_title,
        CAST(length(parents) AS INTEGER) AS parent_count,
        CAST(length(parents) > 1 AS BOOLEAN) AS is_merge_commit
    FROM read_json(
        'data/raw/commits/*.json',
        format = 'array',
        union_by_name = true,
        columns = {
            sha: 'VARCHAR',
            html_url: 'VARCHAR',
            author: 'STRUCT(login VARCHAR)',
            commit: 'STRUCT(author STRUCT(name VARCHAR, date VARCHAR), committer STRUCT(date VARCHAR), message VARCHAR)',
            parents: 'STRUCT(sha VARCHAR, url VARCHAR, html_url VARCHAR)[]'
        }
    )
    ORDER BY repo_name, committed_at, sha
) TO 'data/normalized/commits.csv' (FORMAT csv, HEADER);
