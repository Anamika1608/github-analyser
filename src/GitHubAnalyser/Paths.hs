module GitHubAnalyser.Paths (
    ensureRawDirectories,
    parquetCommitsPath,
    parquetEventsPath,
    parquetReposPath,
    rawCommitsDir,
    rawCommitSnapshotPath,
    rawEventsPath,
    rawManifestPath,
    rawReposPath,
) where

import qualified Data.Text as T
import GitHubAnalyser.Config (AppConfig (..))
import System.Directory (createDirectoryIfMissing)
import System.FilePath ((</>))

rawReposPath :: AppConfig -> FilePath
rawReposPath cfg = rawDataDir cfg </> "repos.json"

rawEventsPath :: AppConfig -> FilePath
rawEventsPath cfg = rawDataDir cfg </> "events.json"

rawManifestPath :: AppConfig -> FilePath
rawManifestPath cfg = rawDataDir cfg </> "manifest.json"

rawCommitsDir :: AppConfig -> FilePath
rawCommitsDir cfg = rawDataDir cfg </> "commits"

rawCommitSnapshotPath :: AppConfig -> T.Text -> FilePath
rawCommitSnapshotPath cfg repoName =
    rawCommitsDir cfg </> sanitizeFileName repoName <> ".json"

parquetReposPath :: FilePath
parquetReposPath = "data/parquet/repos.parquet"

parquetEventsPath :: FilePath
parquetEventsPath = "data/parquet/events.parquet"

parquetCommitsPath :: FilePath
parquetCommitsPath = "data/parquet/commits.parquet"

ensureRawDirectories :: AppConfig -> IO ()
ensureRawDirectories cfg = do
    createDirectoryIfMissing True (rawDataDir cfg)
    createDirectoryIfMissing True (rawCommitsDir cfg)

sanitizeFileName :: T.Text -> FilePath
sanitizeFileName =
    map replaceUnsafe . T.unpack
  where
    replaceUnsafe c
        | c `elem` ("-_.abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789" :: String) = c
        | otherwise = '_'
