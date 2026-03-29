{-# LANGUAGE RecordWildCards #-}

module GitHubAnalyser.Config (
    AppConfig (..),
    Command (..),
    loadConfig,
    parseCommand,
) where

import Control.Monad (forM_, when)
import Data.Maybe (fromMaybe)
import Data.Char (isSpace)
import qualified Data.Text as T
import Data.Time.Clock (UTCTime, addUTCTime, getCurrentTime, nominalDay)
import System.Directory (doesFileExist)
import System.Environment (lookupEnv, setEnv)
import Text.Read (readMaybe)

data Command
    = FetchAll
    | FetchRepos
    | FetchEvents
    | FetchCommits
    | AnalyzeParquet
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
parseCommand ["analyze-parquet"] = Right AnalyzeParquet
parseCommand _ = Left "Unknown or missing command."

loadConfig :: IO AppConfig
loadConfig = do
    loadDotEnvIfPresent
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

loadDotEnvIfPresent :: IO ()
loadDotEnvIfPresent = do
    exists <- doesFileExist ".env"
    when exists $ do
        contents <- readFile ".env"
        forM_ (lines contents) applyDotEnvLine

applyDotEnvLine :: String -> IO ()
applyDotEnvLine rawLine =
    case parseDotEnvAssignment rawLine of
        Nothing -> pure ()
        Just (name, value) -> do
            existing <- lookupEnv name
            case existing of
                Just _ -> pure ()
                Nothing -> setEnv name value

parseDotEnvAssignment :: String -> Maybe (String, String)
parseDotEnvAssignment rawLine =
    case break (== '=') (dropExportPrefix (trim rawLine)) of
        ("", _) -> Nothing
        (_, "") -> Nothing
        (name, _ : value) -> Just (trim name, stripQuotes (trim value))
  where
    dropExportPrefix line =
        case words line of
            "export" : rest -> unwords rest
            _ -> line

trim :: String -> String
trim =
    dropWhileEnd isSpace . dropWhile isSpace
  where
    dropWhileEnd predicate = reverse . dropWhile predicate . reverse

stripQuotes :: String -> String
stripQuotes value =
    case value of
        '"' : rest | not (null rest) && last rest == '"' -> init rest
        '\'' : rest | not (null rest) && last rest == '\'' -> init rest
        _ -> value
