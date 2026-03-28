{-# LANGUAGE OverloadedStrings #-}
{-# LANGUAGE RecordWildCards #-}

module Main where

import qualified Data.Text as T
import Data.Time.Format.ISO8601 (iso8601Show)
import GitHubAnalyser.Config
import GitHubAnalyser.GitHub
import GitHubAnalyser.Paths
import GitHubAnalyser.Types
import System.Environment (getArgs)

usage :: String
usage =
    unlines
        [ "Usage: github-analyser <command>"
        , ""
        , "Commands:"
        , "  fetch-all      Fetch repos, events, and commits"
        , "  fetch-repos    Fetch repository metadata only"
        , "  fetch-events   Fetch public events only"
        , "  fetch-commits  Fetch commits for top active repositories"
        ]

printConfigSummary :: AppConfig -> IO ()
printConfigSummary AppConfig{..} = do
    putStrLn ("GitHub user: " ++ T.unpack targetUser)
    putStrLn ("Raw output dir: " ++ rawDataDir)
    putStrLn ("Top repo count: " ++ show topRepoCount)
    putStrLn ("Commit since: " ++ iso8601Show commitSince)

runFetchRepos :: AppConfig -> IO [Repo]
runFetchRepos cfg = do
    repos <- fetchReposSnapshot cfg
    putStrLn ("Fetched repos: " ++ show (length repos))
    pure repos

runFetchEvents :: AppConfig -> IO [Event]
runFetchEvents cfg = do
    events <- fetchEventsSnapshot cfg
    putStrLn ("Fetched events: " ++ show (length events))
    pure events

runFetchCommits :: AppConfig -> IO [CommitSnapshot]
runFetchCommits cfg = do
    repos <- fetchRepos cfg
    snapshots <- fetchCommitSnapshots cfg (topReposForCommitFetch cfg repos)
    putStrLn ("Fetched commit snapshots: " ++ show (length snapshots))
    pure snapshots

runFetchAll :: AppConfig -> IO ()
runFetchAll cfg = do
    repos <- runFetchRepos cfg
    events <- runFetchEvents cfg
    commitSnapshots <- fetchCommitSnapshots cfg (topReposForCommitFetch cfg repos)
    let manifest = buildManifest cfg repos events commitSnapshots
    writeManifest cfg manifest
    putStrLn ("Fetched commit snapshots: " ++ show (length commitSnapshots))
    putStrLn ("Wrote manifest: " ++ rawManifestPath cfg)

main :: IO ()
main = do
    args <- getArgs
    command <-
        case parseCommand args of
            Left err -> do
                putStrLn err
                putStrLn usage
                fail "invalid command"
            Right cmd -> pure cmd
    cfg <- loadConfig
    ensureRawDirectories cfg
    printConfigSummary cfg
    case command of
        FetchAll -> runFetchAll cfg
        FetchRepos -> do
            _ <- runFetchRepos cfg
            pure ()
        FetchEvents -> do
            _ <- runFetchEvents cfg
            pure ()
        FetchCommits -> do
            _ <- runFetchCommits cfg
            pure ()
