{-# LANGUAGE OverloadedStrings #-}
{-# LANGUAGE TypeApplications #-}

module GitHubAnalyser.Analysis (
    runParquetAnalysis,
) where

import Control.Monad (forM_)
import qualified Data.Text as T
import qualified Data.Text.IO as TIO
import Data.Time.Clock (UTCTime)
import qualified DataFrame as D
import qualified DataFrame.Functions as F
import DataFrame.Internal.Schema (Schema, makeSchema, schemaType)
import qualified DataFrame.Lazy as L
import DataFrame.Lazy.Internal.LogicalPlan (SortOrder (..))
import DataFrame.Operators ((|>), as)
import GitHubAnalyser.Paths
import System.Directory (doesFileExist)

runParquetAnalysis :: IO ()
runParquetAnalysis = do
    ensureParquetFilesExist

    repos <- D.readParquet parquetReposPath
    events <- D.readParquet parquetEventsPath
    commits <- D.readParquet parquetCommitsPath

    projectedCommitSample <-
        D.readParquetWithOpts
            D.defaultParquetReadOptions
                { D.selectedColumns = Just ["repo_name", "sha", "committed_at", "is_merge_commit"]
                , D.rowRange = Just (0, 5)
                }
            parquetCommitsPath

    lazyRecentCommits <-
        L.runDataFrame $
            L.take 10 $
                L.sortBy [("committed_at", Descending)] $
                    L.select ["repo_name", "sha", "committed_at", "message_title"] $
                        L.filter
                            (F.eq (F.col @Bool "is_merge_commit") (F.lit False))
                            (L.scanParquet commitsSchema (T.pack parquetCommitsPath))

    let commitsPerRepo =
            commits
                |> D.groupBy ["repo_name"]
                |> D.aggregate [F.count (F.col @T.Text "sha") `as` "commit_count"]
                |> D.sortBy [D.Desc (F.col @Int "commit_count")]
                |> D.take 10

    let eventTypes =
            events
                |> D.groupBy ["event_type"]
                |> D.aggregate [F.count (F.col @T.Text "event_id") `as` "event_count"]
                |> D.sortBy [D.Desc (F.col @Int "event_count")]
                |> D.take 10

    let repoCommitSummary =
            repos
                |> D.innerJoin ["repo_name"] commitsPerRepo
                |> D.select ["repo_name", "language", "pushed_at", "commit_count"]
                |> D.sortBy [D.Desc (F.col @Int "commit_count")]
                |> D.take 10

    printDatasetSummary "repos" repos
    printDatasetSummary "events" events
    printDatasetSummary "commits" commits

    printSection "Projected Commit Sample (readParquetWithOpts)" projectedCommitSample
    printSection "Top Repos By Commit Count" commitsPerRepo
    printSection "Top Event Types" eventTypes
    printSection "Repos Joined With Commit Counts" repoCommitSummary
    printSection "Recent Non-Merge Commits (lazy scanParquet)" lazyRecentCommits

commitsSchema :: Schema
commitsSchema =
    makeSchema
        [ ("repo_name", schemaType @T.Text)
        , ("sha", schemaType @T.Text)
        , ("author_login", schemaType @T.Text)
        , ("author_name", schemaType @T.Text)
        , ("authored_at", schemaType @UTCTime)
        , ("committed_at", schemaType @UTCTime)
        , ("message_title", schemaType @T.Text)
        , ("is_merge_commit", schemaType @Bool)
        ]

ensureParquetFilesExist :: IO ()
ensureParquetFilesExist =
    forM_
        [ parquetReposPath
        , parquetEventsPath
        , parquetCommitsPath
        ]
        $ \path -> do
            exists <- doesFileExist path
            if exists
                then pure ()
                else fail ("Missing Parquet file: " <> path)

printDatasetSummary :: String -> D.DataFrame -> IO ()
printDatasetSummary label df = do
    let (rows, cols) = D.dimensions df
    putStrLn ("Dataset: " <> label)
    putStrLn ("Rows: " <> show rows <> ", Columns: " <> show cols)
    putStrLn ("Columns: " <> show (map T.unpack (D.columnNames df)))
    putStrLn ""

printSection :: String -> D.DataFrame -> IO ()
printSection title df = do
    putStrLn ("== " <> title <> " ==")
    TIO.putStrLn (D.toMarkdown df)
    putStrLn ""
