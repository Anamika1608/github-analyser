COPY (
    SELECT
        repo_id,
        repo_name,
        full_name,
        language,
        TRY_CAST(replace(created_at, 'Z', '') AS TIMESTAMP) AS created_at,
        TRY_CAST(replace(updated_at, 'Z', '') AS TIMESTAMP) AS updated_at,
        TRY_CAST(replace(pushed_at, 'Z', '') AS TIMESTAMP) AS pushed_at,
        default_branch,
        stargazers_count,
        watchers_count,
        forks_count,
        open_issues_count,
        size_kb,
        archived,
        disabled,
        is_fork
    FROM read_csv(
        'data/normalized/repos.csv',
        header = true,
        columns = {
            repo_id: 'BIGINT',
            repo_name: 'VARCHAR',
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
            size_kb: 'INTEGER',
            archived: 'BOOLEAN',
            disabled: 'BOOLEAN',
            is_fork: 'BOOLEAN'
        }
    )
    ORDER BY repo_name
) TO 'data/parquet/repos.parquet' (FORMAT parquet);

COPY (
    SELECT
        event_id,
        event_type,
        repo_name,
        actor_login,
        TRY_CAST(replace(created_at, 'Z', '') AS TIMESTAMP) AS created_at,
        is_public
    FROM read_csv(
        'data/normalized/events.csv',
        header = true,
        columns = {
            event_id: 'VARCHAR',
            event_type: 'VARCHAR',
            repo_name: 'VARCHAR',
            actor_login: 'VARCHAR',
            created_at: 'VARCHAR',
            is_public: 'BOOLEAN'
        }
    )
    ORDER BY created_at DESC, event_id
) TO 'data/parquet/events.parquet' (FORMAT parquet);

COPY (
    SELECT
        repo_name,
        sha,
        author_login,
        author_name,
        TRY_CAST(replace(authored_at, 'Z', '') AS TIMESTAMP) AS authored_at,
        TRY_CAST(replace(committed_at, 'Z', '') AS TIMESTAMP) AS committed_at,
        message_title,
        parent_count,
        is_merge_commit
    FROM read_csv(
        'data/normalized/commits.csv',
        header = true,
        columns = {
            repo_name: 'VARCHAR',
            sha: 'VARCHAR',
            author_login: 'VARCHAR',
            author_name: 'VARCHAR',
            authored_at: 'VARCHAR',
            committed_at: 'VARCHAR',
            message_title: 'VARCHAR',
            parent_count: 'INTEGER',
            is_merge_commit: 'BOOLEAN'
        }
    )
    ORDER BY repo_name, committed_at, sha
) TO 'data/parquet/commits.parquet' (FORMAT parquet);
