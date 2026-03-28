{-# LANGUAGE RecordWildCards #-}

module GitHubAnalyser.Config (
    AppConfig (..),
    Command (..),
    loadConfig,
    parseCommand,
) where

import Data.Maybe (fromMaybe)
import qualified Data.Text as T
import Data.Time.Clock (UTCTime, addUTCTime, getCurrentTime, nominalDay)
import System.Environment (lookupEnv)
import Text.Read (readMaybe)

data Command
    = FetchAll
    | FetchRepos
    | FetchEvents
    | FetchCommits
    deriving (Eq, Show)

data AppConfig = AppConfig
    { targetUser :: T.Text
    , githubToken :: Maybe T.Text
    , rawDataDir :: FilePath
    , topRepoCount :: Int
    , commitSince :: UTCTime
    }
    deriving (Eq, Show)

parseCommand :: [String] -> Either String Command
parseCommand ["fetch-all"] = Right FetchAll
parseCommand ["fetch-repos"] = Right FetchRepos
parseCommand ["fetch-events"] = Right FetchEvents
parseCommand ["fetch-commits"] = Right FetchCommits
parseCommand _ = Left "Unknown or missing command."

loadConfig :: IO AppConfig
loadConfig = do
    user <- fmap (T.pack . fromMaybe "Anamika1608") (lookupEnv "GITHUB_ANALYSER_USER")
    token <- fmap T.pack <$> lookupEnv "GITHUB_TOKEN"
    rawDir <- fromMaybe "data/raw" <$> lookupEnv "GITHUB_ANALYSER_RAW_DIR"
    topRepos <- readEnvInt "GITHUB_ANALYSER_TOP_REPOS" 20
    lookbackDays <- readEnvInteger "GITHUB_ANALYSER_COMMIT_LOOKBACK_DAYS" 365
    now <- getCurrentTime
    let commitSince = addUTCTime (negate (fromIntegral lookbackDays * nominalDay)) now
    pure
        AppConfig
            { targetUser = user
            , githubToken = token
            , rawDataDir = rawDir
            , topRepoCount = topRepos
            , commitSince = commitSince
            }

readEnvInt :: String -> Int -> IO Int
readEnvInt name fallback = do
    value <- lookupEnv name
    pure $ maybe fallback id (value >>= readMaybe)

readEnvInteger :: String -> Integer -> IO Integer
readEnvInteger name fallback = do
    value <- lookupEnv name
    pure $ maybe fallback id (value >>= readMaybe)

